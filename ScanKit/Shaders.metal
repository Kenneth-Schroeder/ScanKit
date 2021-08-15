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

constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);

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
                                            texture2d<float, access::sample> capturedImageTextureY [[ texture(kTextureIndexY) ]],
                                            texture2d<float, access::sample> capturedImageTextureCbCr [[ texture(kTextureIndexCbCr) ]]) {
    
    const float4x4 ycbcrToRGBTransform = float4x4(
        float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
        float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
        float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
        float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
    );
    
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
