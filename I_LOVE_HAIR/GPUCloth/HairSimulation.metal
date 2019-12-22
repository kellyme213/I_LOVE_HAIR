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

kernel void moveParticles
(
    device   HairParticle*       particles     [[buffer(SIMULATION_HAIR_PARTICLE_BUFFER)]],
    constant SimulationUniforms& uniforms      [[buffer(SIMULATION_UNIFORM_BUFFER)]],
             uint2               tid           [[thread_position_in_grid]]
)
{
    uint particleId = tid.x;
    
    HairParticle particle = particles[particleId];
    
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
        
        if (particle.rightParticleId >= 0 && particle.leftParticleId >= 0)
        {
            
        }
        
        
        totalForce += particle.mass * uniforms.gravity;
        totalForce += -uniforms.kDamping * particle.velocity;
        
        float3 newAcceleration = totalForce / particle.mass;
        particles[particleId].acceleration = newAcceleration;
        
        particles[particleId].velocity += uniforms.timestep * particles[particleId].acceleration;
        particles[particleId].position += uniforms.timestep * particles[particleId].velocity;
    }
}




