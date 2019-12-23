//
//  ShaderStructures.h
//  GPUCloth
//
//  Created by Michael Kelly on 8/29/19.
//  Copyright © 2019 Michael Kelly. All rights reserved.
//

#ifndef ShaderStructures_h
#define ShaderStructures_h

#include <simd/simd.h>

#define RASTERIZE_VERTEX_BUFFER           0
#define RASTERIZE_VERTEX_UNIFORM_BUFFER   1

#define SIMULATION_HAIR_PARTICLE_BUFFER   0
#define SIMULATION_UNIFORM_BUFFER         1

#define SIMULATION_VERTEX_BUFFER          1
#define SIMULATION_CAMERA_POSITION_BUFFER 2

struct ClothParticle {
    simd_float3 position;
    simd_float3 velocity;
    simd_float3 acceleration;
    
    int numStructuralSprings;
    int structuralSprings[8];
    
    int numShearSprings;
    int shearSprings[8];
    
    int numFlexionSprings;
    int flexionSprings[8];
    
    
};

struct HairParticle {
    simd_float3 position;
    simd_float3 velocity;
    simd_float3 acceleration;
    
    int particleId;
    int fixed;
    
    int leftParticleId;
    int rightParticleId;
    
    float hairAngle;
    float kHair;
    
    float hairDist;
    float kDist;
    
    float mass;
    
    simd_float3 color;
    
    simd_float3 force;
};

struct RasterizeUniforms {
    simd_float4x4 modelViewMatrix;
    simd_float4x4 projectionMatrix;
};

struct SimulationUniforms {
    float timestep;
    simd_float3 gravity;
    float kDamping;
};

struct Vertex {
    simd_float4 position;
    simd_float4 color;
};





#endif /* ShaderStructures_h */
