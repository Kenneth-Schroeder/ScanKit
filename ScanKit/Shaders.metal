//
//  Shaders.metal
//  ScanKit
//
//  Created by Kenneth Schröder on 10.08.21.
//

#include <metal_stdlib>
#include <simd/simd.h>

// Include header shared between this Metal shader code and C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

typedef struct {
    float2 position [[attribute(kVertexAttributePosition)]];
    float2 texCoord [[attribute(kVertexAttributeTexcoord)]];
} ImageVertex;

typedef struct {
    float4 position [[position]];
    float2 texCoord;
} ImageInOut;

typedef struct {
    float4 position [[position]];
    float4 color;
} DevicePathVertex;


typedef struct {
    float4 position [[position]];
    float pointSize [[point_size]];
    float4 color;
    float4 eyeSpacePosition;
} ParticleInOut;

constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);
constant float4x4 ycbcrToRGBTransform = float4x4(
    float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
    float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
    float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
    float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
);
constant float2 viewTexCoords[] = { float2(0, 0), float2(0, 1), float2(1, 0), float2(1, 1) };

// Retrieves the world position of a specified camera point with depth
static simd_float4 worldPoint(simd_float2 cameraPoint, float depth, matrix_float3x3 cameraIntrinsicsInversed, matrix_float4x4 localToWorld) {
    const auto localPoint = cameraIntrinsicsInversed * simd_float3(cameraPoint, 1) * depth;
    const auto worldPoint = localToWorld * simd_float4(localPoint, 1);
    
    return worldPoint / worldPoint.w;
}

// Generate a random float in the range [0.0f, 1.0f] using x, y, and z (based on the xor128 algorithm)
/// https://stackoverflow.com/questions/47499480/how-to-get-a-random-number-in-metal-shader
float rand(int x, int y, int z)
{
    int seed = x + y * 57 + z * 241;
    seed= (seed<< 13) ^ seed;
    return (( 1.0 - ( (seed * (seed * seed * 15731 + 789221) + 1376312589) & 2147483647) / 1073741824.0f) + 1.0f) / 2.0f;
}

// MARK: - Underlays

// Captured image vertex function
vertex ImageInOut underlayImageVertex(ImageVertex in [[stage_in]]) {
    ImageInOut out;
    
    // Pass through the image vertex's position
    out.position = float4(in.position, 0.0, 1.0);
    
    // Pass through the texture coordinate
    out.texCoord = in.texCoord;
    
    return out;
}

// Captured image fragment function
fragment float4 capturedImageFragment(ImageInOut in [[stage_in]],
                                            texture2d<float, access::sample> capturedImageTextureY [[ texture(kTextureY) ]],
                                            texture2d<float, access::sample> capturedImageTextureCbCr [[ texture(kTextureCbCr) ]]) {
    // Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate
    float4 ycbcr = float4(capturedImageTextureY.sample(colorSampler, in.texCoord).r,
                          capturedImageTextureCbCr.sample(colorSampler, in.texCoord).rg, 1.0);
    
    // Return converted RGB color
    return ycbcrToRGBTransform * ycbcr;
}

fragment float4 floatTexFragment(ImageInOut in [[stage_in]],
                            constant float &factor [[buffer(0)]],
                            texture2d<float, access::sample> texture [[texture(0)]]) {
    const float value = texture.sample(colorSampler, in.texCoord.xy).r * factor;
    return float4(value, value, value, 1.0);
}

fragment float4 confidenceFragment(ImageInOut in [[stage_in]],
                            texture2d<uint, access::sample> confidenceTexture [[texture(0)]]) {
    // Sample the confidence map to get the confidence value
    const uint value = confidenceTexture.sample(colorSampler, in.texCoord.xy).r;
    float4 color;
    switch(value){
        case 0:
            color = float4(1, 0, 0, 1);
            break;
        case 1:
            color = float4(1, 1, 0, 1);
            break;
        case 2:
            color = float4(0, 1, 0, 1);
            break;
        default:
            color = float4(1, 1, 1, 1);
            break;
    }
    return color;
}

// MARK: - Filter Unproject

//  Vertex shader that takes in a 2D grid-point and infers its 3D position in world-space, along with RGB and confidence and also assigns SelectionTypes according to sobel textures
vertex void filterUnprojectVertex(uint vertexID [[vertex_id]],
                            constant UnprojectUniforms &uniforms [[buffer(kUnprojectUniforms)]],
                            device ParticleUniforms *particleUniforms [[buffer(kViewshedParticleUniforms)]],
                            constant float2 *gridPoints [[buffer(kGridPoints)]],
                            constant float4 &sobelConfig [[buffer(kSobelThresholds)]],
                            constant float2 &depthThresholds [[buffer(kDepthThresholds)]],
                            texture2d<float, access::sample> capturedImageTextureY [[texture(kTextureY)]],
                            texture2d<float, access::sample> capturedImageTextureCbCr [[texture(kTextureCbCr)]],
                            texture2d<float, access::sample> depthTexture [[texture(kTextureDepth)]],
                            texture2d<unsigned int, access::sample> confidenceTexture [[texture(kTextureConfidence)]],
                            texture2d<float, access::sample> depthSobelTexture [[texture(kTextureDepthSobel)]],
                            texture2d<float, access::sample> ySobelTexture [[texture(kTextureYSobel)]]
    ) {
    const auto gridPoint = gridPoints[vertexID];
    const auto currentPointIndex = vertexID; // always starting to write at beginning of the sparse buffer
    const auto texCoord = gridPoint / uniforms.cameraResolution;
    // Sample the depth map to get the depth value
    const auto depth = depthTexture.sample(colorSampler, texCoord).r;
    // With a 2D point plus depth, we can now get its 3D position
    const auto position = worldPoint(gridPoint, depth, uniforms.cameraIntrinsicsInversed, uniforms.localToWorld);
    
    // Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate
    const auto ycbcr = float4(capturedImageTextureY.sample(colorSampler, texCoord).r, capturedImageTextureCbCr.sample(colorSampler, texCoord.xy).rg, 1);
    const auto sampledColor = (ycbcrToRGBTransform * ycbcr).rgb;
    // Sample the confidence map to get the confidence value
    const auto confidence = confidenceTexture.sample(colorSampler, texCoord).r;
    
    const auto depthSobel = depthSobelTexture.sample(colorSampler, texCoord).r / 5.0;
    const auto ySobel = ySobelTexture.sample(colorSampler, texCoord).r; // edges are black
    
    if(depthSobel > sobelConfig[0]){
        // mark point as unselected (ignore points on edges of depthMap)
        particleUniforms[currentPointIndex].type = depthDeleted;
    }
    else if(ySobel > sobelConfig[1] && rand(vertexID, uniforms.timestamp, vertexID * uniforms.timestamp) < sobelConfig[2]){
        // sample 100% (pay special attention to points on edges of capturedImage -> detail necessary)
        particleUniforms[currentPointIndex].type = ySobelSelected;
    }
    else if(rand(vertexID, uniforms.timestamp, vertexID * uniforms.timestamp) < sobelConfig[3]){ //
        // select points on 'surfaces' (on no edge) with x percent
        // pseudo random numbers generated by vertexID and timestamp as seeds
        
        particleUniforms[currentPointIndex].type = surfaceSelected;
    }
    else {
        // unselect point, nothing of the above applies
        particleUniforms[currentPointIndex].type = surfaceDeleted;
    }
    
    if(depth > depthThresholds[0] || depth < depthThresholds[1]) { // dont remember points too far away or too close
        particleUniforms[currentPointIndex].type = depthDeleted;
    }
    
    // Write the data to the buffer
    particleUniforms[currentPointIndex].position = position.xyz;
    particleUniforms[currentPointIndex].color = sampledColor;
    particleUniforms[currentPointIndex].confidence = confidence;
    particleUniforms[currentPointIndex].timestamp = uniforms.timestamp;
    particleUniforms[currentPointIndex].captureDistance = depth;
}

// MARK: - Particle Shaders

vertex ParticleInOut particleVertex(uint vertexID [[vertex_id]],
                                        constant PointCloudUniforms &uniforms [[buffer(kPointCloudUniforms)]],
                                        constant ParticleUniforms *particleUniforms [[buffer(kParticleUniforms)]],
                                        constant bool &showByConfidence [[buffer(kFreeBufferIndex+0)]],
                                        constant float &alphaFactor [[buffer(kFreeBufferIndex+1)]],
                                        constant uint &timestamp [[buffer(kFreeBufferIndex+2)]]) {
    // get point data
    const auto particleData = particleUniforms[vertexID];
    const auto position = particleData.position;
    const auto confidence = particleData.confidence;
    const auto sampledColor = particleData.color;
    const int dist = int(particleData.captureDistance);
    const auto visibility = showByConfidence ? confidence >= uniforms.confidenceThreshold : 1;
    
    // animate and project the point
    float4 projectedPosition = uniforms.projectionMatrix * uniforms.viewMatrix * float4(position, 1.0);
    const float pointSize = max(uniforms.particleSize / max(1.0, projectedPosition.z), 0.0);
    projectedPosition /= projectedPosition.w;
    
    float3 confidenceColor = mix(mix(float3(1.0, 0.0, 0.0), float3(1.0, 1.0, 0.0), confidence == 1.0), float3(0.0, 1.0, 0.0), confidence == 2.0);
    
    // prepare for output
    ParticleInOut out;
    out.position = projectedPosition;
    out.pointSize = pointSize;
    
    float factor = 3;
    float timespan = 1000;
    if(timestamp - particleData.timestamp < timespan) { // point was recorded within the last 1000ms
        out.pointSize *= 1+ factor * (1 - float(timestamp - particleData.timestamp) / timespan); // make it bigger
    }
    
    switch(uniforms.coloringMethod){
        case ColoringMethod::rgb:
            out.color = float4(sampledColor, visibility * alphaFactor);
            break;
        case ColoringMethod::confidence:
            out.color = float4(confidenceColor, visibility * alphaFactor);
            break;
        case ColoringMethod::depth:
            if(dist == 1 || dist == 2) // 1-3 meters away
                out.color = float4(0,1,0, visibility * alphaFactor); // green
            else if(dist == 0 || dist == 3) // 0-1 meters or 3-4 meters away
                out.color = float4(1,1,0, visibility * alphaFactor); // yellow
            else
                out.color = float4(1,0,0, visibility * alphaFactor); // red
            break;
        case ColoringMethod::red:
            out.color = float4(1,0,0, visibility * alphaFactor);
            break;
    }
    
    out.eyeSpacePosition = uniforms.viewMatrix * float4(position, 1.0);
    
    return out;
}

fragment float4 particleFragment(ParticleInOut in [[stage_in]],
                                 const float2 coords [[point_coord]],
                                 constant LightUniforms &uniforms [[ buffer(kLightUniforms) ]]) {
    // we draw within a circle
    const float distSquared = length_squared(coords - float2(0.5)); // Table 6.10. Geometric functions in the Metal standard library https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf
    if (in.color.a == 0 || distSquared > 0.25) {
        discard_fragment();
    }
    
    // calculate fragment surface normal wrt. camera - https://paroj.github.io/gltut/Illumination/Tutorial%2013.html
    const float2 centered_coords = coords * 2 - float2(1);
    const float z = sqrt(1 - dot(centered_coords, centered_coords)); // sqrt(1- pow(coords[0], 2) -pow(coords[1], 2));
    const float3 normal = float3(centered_coords, z); // relative to camera eye
    
    // Calculate the contribution of the directional light as a sum of diffuse and specular terms
    float3 directionalContribution = float3(0);
    {
        // Light falls off based on how closely aligned the surface normal is to the light direction
        float nDotL = saturate(dot(normal, -uniforms.directionalLightDirection));
        
        // The diffuse term is then the product of the light color, the surface material
        // reflectance, and the falloff
        float3 diffuseTerm = uniforms.directionalLightColor * nDotL;
        
        // Apply specular lighting...
        
        // 1) Calculate the halfway vector between the light direction and the direction they eye is looking
        float3 halfwayVector = normalize(-uniforms.directionalLightDirection - float3(in.eyeSpacePosition));
        
        // 2) Calculate the reflection angle between our reflection vector and the eye's direction
        float reflectionAngle = saturate(dot(normal, halfwayVector));
        
        // 3) Calculate the specular intensity by multiplying our reflection angle with our object's
        //    shininess
        float specularIntensity = saturate(powr(reflectionAngle, uniforms.materialShininess));
        
        // 4) Obtain the specular term by multiplying the intensity by our light's color
        float3 specularTerm = uniforms.directionalLightColor * specularIntensity;
        
        // Calculate total contribution from this light is the sum of the diffuse and specular values
        directionalContribution = diffuseTerm + specularTerm;
    }
    
    // The ambient contribution, which is an approximation for global, indirect lighting, is
    // the product of the ambient light intensity multiplied by the material's reflectance
    float3 ambientContribution = uniforms.ambientLightColor;
    
    // Now that we have the contributions our light sources in the scene, we sum them together
    // to get the fragment's lighting value
    float3 lightContributions = ambientContribution + directionalContribution;
    
    // We compute the final color by multiplying the sample from our color maps by the fragment's
    // lighting value
    float3 color = in.color.rgb * lightContributions;
    return float4(color, in.color.w);
    
    //in.color.a = (1- distSquared * 4) * in.color.a; // brighter in center
    //return in.color;
    
}

// MARK: - Plane Shaders

vertex ImageInOut floatingTextureVertex(uint vertexID [[vertex_id]],
                                        constant SceneUniforms &uniforms [[buffer(kSceneUniforms)]],
                                        constant float4 *vertices [[buffer(kTextureCornersBuffer)]],
                                        constant bool &verticesWithARCamCoordinates [[buffer(kFreeBufferIndex+0)]]) {
    const float3 texCoord = float3(viewTexCoords[vertexID], 1); // texture coordinate
    
    float4x4 transformation = uniforms.viewProjectionMatrix;
    if(verticesWithARCamCoordinates){ // if true, convert to global coordinates first
        transformation = transformation * uniforms.arCamViewMatrixInversed;
    }
    
    ImageInOut out;
    out.position = transformation * vertices[vertexID];
    out.texCoord = texCoord.xy;
    
    return out;
}

fragment float4 floatingTextureFragment(ImageInOut in [[stage_in]],
                                        constant float &alpha [[buffer(kFreeBufferIndex)]],
                                        texture2d<float, access::sample> texture [[texture(0)]] ) {
    float3 color = texture.sample(colorSampler, in.texCoord.xy).rgb;
    return float4(color, alpha);
}

// MARK: - Path Shaders

vertex DevicePathVertex pathVertex(uint vertexID [[vertex_id]],
                                   constant float3 *positions [[buffer(kDevicePath)]],
                                   constant PointCloudUniforms &uniforms [[buffer(kPointCloudUniforms)]]) {
    // get point data
    const auto position = positions[vertexID];
    float4 projectedPosition = uniforms.projectionMatrix * uniforms.viewMatrix * float4(position, 1.0);
    projectedPosition /= projectedPosition.w;
    
    DevicePathVertex out;
    out.position = projectedPosition;
    out.color = float4(1,0,0,0.5);
    
    return out;
}

fragment float4 pathFragment(DevicePathVertex in [[stage_in]]) {
    return in.color;
}
