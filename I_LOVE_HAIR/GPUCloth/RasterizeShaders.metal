//
//  RasterizeShaders.metal
//  GPUCloth
//
//  Created by Michael Kelly on 12/21/19.
//  Copyright © 2019 Michael Kelly. All rights reserved.
//

#include <metal_stdlib>
#import "ShaderStructures.h"
using namespace metal;

struct VertexOut {
    simd_float4 transformedPosition [[position]];
    simd_float4 color;
};


vertex VertexOut vertexShader
(
    const device HairParticle*     particles [[buffer(RASTERIZE_HAIR_PARTICLE_BUFFER)]],
    const device RasterizeUniforms& uniforms  [[buffer(RASTERIZE_VERTEX_UNIFORM_BUFFER)]],
    uint               vid       [[vertex_id]]
)
{
    matrix_float4x4 mvp = uniforms.projectionMatrix * uniforms.modelViewMatrix;
    VertexOut v;
    v.transformedPosition = mvp * float4(particles[vid].position, 1.0);
    v.color = float4(particles[vid].color, 1.0);
    return v;
}

fragment float4 fragmentShader
(
    VertexOut in [[stage_in]]
)
{
    return in.color;
}




