//
//  ShaderTypes.h
//  ScanKit
//
//  Created by Kenneth Schröder on 10.08.21.
//

//
//  Header containing types and enum constants shared between Metal shaders and C/ObjC source
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API buffer set calls
typedef enum BufferIndices {
    kUnderlayVertexDescriptors = 0, // for some reason, this has to be 0 (9 didnt work)
    kPointCloudUniforms = 1,
    kParticleUniforms = 2,
    kGridPoints = 3,
    kViewshedParticleUniforms = 4,
    kSobelThresholds = 5,
    kDepthThresholds = 6,
    kSceneUniforms = 7,
    kColorScheme = 8,
    kUnprojectUniforms = 9,
    kLocalPoints = 10,
    kDevicePath = 11,
    kFrustumCorner = 12,
    kLightUniforms = 13,
    kFreeBufferIndex = 14
} BufferIndices;

// Attribute index values shared between shader and C code to ensure Metal shader vertex
//   attribute indices match the Metal API vertex descriptor attribute indices
typedef enum VertexAttributes {
    kVertexAttributePosition  = 0,
    kVertexAttributeTexcoord  = 1,
    kVertexAttributeNormal    = 2
} VertexAttributes;

// Texture index values shared between shader and C code to ensure Metal shader texture indices
//   match indices of Metal API texture set calls
typedef enum TextureIndices {
    kTextureY = 0,
    kTextureCbCr = 1,
    kTextureDepth = 2,
    kTextureConfidence = 3,
    kTextureDepthSobel = 4,
    kTextureYSobel = 5
} TextureIndices;

typedef enum SelectionType : uint8_t {
    ySobelSelected = 0,
    surfaceSelected = 1,
    depthDeleted = 2,
    surfaceDeleted = 3,
    distanceDeleted = 4
} SelectionType;

typedef enum ColoringMethod : uint8_t {
    rgb = 0,
    depth = 1,
    confidence = 2,
    red = 3
} ColoringMethod;

// Structure shared between shader and C code to ensure the layout of shared uniform data accessed in
//    Metal shaders matches the layout of uniform data set in C code
typedef struct {
    simd_float3 ambientLightColor;
    simd_float3 directionalLightDirection;
    simd_float3 directionalLightColor;
    float materialShininess;
} LightUniforms;

typedef struct {
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
    float particleSize;
    ColoringMethod coloringMethod;
    int confidenceThreshold;
} PointCloudUniforms;

typedef struct {
    matrix_float4x4 localToWorld;
    matrix_float3x3 cameraIntrinsicsInversed;
    simd_float2 cameraResolution;
    uint32_t timestamp; // in ms since application start
} UnprojectUniforms;

typedef struct {
    simd_float3 position;
    simd_float3 color;
    float confidence; // mapped to LAS reserved classes 13-15
    uint32_t timestamp; // not saved within .LAS files, in ms since application start
    enum SelectionType type; // this attribute and below probably lead to larger memory blocks being reserved per item because struct size becomes >32B, inverted value mapped to LAS classification bit 7 (withheld)
    float captureDistance;
} ParticleUniforms;

#endif /* ShaderTypes_h */
