//
//  HairSimulation.metal
//  GPUCloth
//
//  Created by Michael Kelly on 12/21/19.
//  Copyright © 2019 Michael Kelly. All rights reserved.
//

#include <metal_stdlib>
#include "ShaderStructures.h"
using namespace metal;

float angleBetween(float3 a, float3 b)
{
    //return 180;
    float3 crossP = (cross(normalize(a), normalize(b)));
    if (length(crossP) < 0.001)
    {
        return 180;
    }
    float dotP = dot(normalize(a), normalize(b));
    //float angle = 180.0 * (acos(dotP) / 3.14);
    float angle = 180.0 * (0.5 * (dotP + 1.0));
    float3 up = normalize(float3(0.01, 0.01, 0.99));
    if (dot(up, crossP) < 0.0)
    {
        angle = 360 - angle;
    }
        
    return angle;
}

kernel void moveParticles
(
    device   HairParticle*       particles     [[buffer(SIMULATION_HAIR_PARTICLE_BUFFER)]],
    constant SimulationUniforms& uniforms      [[buffer(SIMULATION_UNIFORM_BUFFER)]],
             uint2               tid           [[thread_position_in_grid]]
)
{
    uint particleId = tid.x;
    
    device HairParticle& particle = particles[particleId];
    
    if (!particle.fixed)
    {
        float3 totalForce = float3(0.0);
        
        if (particle.leftParticleId >= 0)
        {
            float3 directionToParticle = particles[particle.leftParticleId].position - particle.position;
            float distanceToParticle = length(directionToParticle);
            float amountStretched = (distanceToParticle / particle.hairDist) - 1.0;
            totalForce += amountStretched * particle.kDist * normalize(directionToParticle);
        }
        
        if (particle.rightParticleId >= 0)
        {
            float3 directionToParticle = particles[particle.rightParticleId].position - particle.position;
            float distanceToParticle = length(directionToParticle);
            float amountStretched = (distanceToParticle / particle.hairDist) - 1.0;
            totalForce += amountStretched * particle.kDist * normalize(directionToParticle);
        }
        
        if (particle.leftParticleId >= 0 && particles[particle.leftParticleId].leftParticleId >= 0)
        {
            float3 center = particles[particle.leftParticleId].position;
            float3 left = particles[particles[particle.leftParticleId].leftParticleId].position;
            float3 right = particle.position;
            
            float3 dirToRight = right - center;
            float3 dirToLeft = left - center;

            float angle = angleBetween(dirToRight, dirToLeft);
            
            //float angle = 180.0 * (0.5 * (dot(normalize(dirToLeft), normalize(dirToRight)) + 1.0));
            
            float angleDiff = (angle / particle.hairAngle - 1.0);
            
            float3 dirBetween = left - right;
            
            if (length(dirBetween) > 0.001)
            {
                totalForce += angleDiff * particle.kHair * normalize(dirBetween);
            }
            
        }
        
        
        totalForce += particle.mass * uniforms.gravity;
        totalForce += -uniforms.kDamping * particle.velocity;
        
        float3 newAcceleration = totalForce / particle.mass;
        particle.acceleration = newAcceleration;
        
        particle.velocity += uniforms.timestep * particle.acceleration;
        particle.position += uniforms.timestep * particle.velocity;
        
        particle.force = totalForce;
    }
}

kernel void correctParticles
(
    device   HairParticle*       particles     [[buffer(SIMULATION_HAIR_PARTICLE_BUFFER)]],
    constant SimulationUniforms& uniforms      [[buffer(SIMULATION_UNIFORM_BUFFER)]],
             uint2               tid           [[thread_position_in_grid]]
)
{
    
}

kernel void generateVerticesFromParticles
(
    device   HairParticle*       particles       [[buffer(SIMULATION_HAIR_PARTICLE_BUFFER)]],
    device   Vertex*             vertices        [[buffer(SIMULATION_VERTEX_BUFFER)]],
    constant float3&             cameraDirection [[buffer(SIMULATION_CAMERA_POSITION_BUFFER)]],
             uint2               tid             [[thread_position_in_grid]]
)
{
    uint particleId = tid.x;
    device HairParticle& particle = particles[particleId];
    
    float3 up = normalize(float3(0.01, 0.99, 0.01));
    float3 left = cross(up, normalize(cameraDirection));
    float thickness = 0.02;
    vertices[2 * particleId].position = float4(thickness * left + particle.position, 1.0);
    vertices[2 * particleId + 1].position = float4(-thickness * left + particle.position, 1.0);
    vertices[2 * particleId].color = vertices[2 * particleId + 1].color = float4(particle.color, 1.0);
}









