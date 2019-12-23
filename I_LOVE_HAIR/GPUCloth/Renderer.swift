//
//  Renderer.swift
//  GPUCloth
//
//  Created by Michael Kelly on 12/21/19.
//  Copyright © 2019 Michael Kelly. All rights reserved.
//

import Foundation
import MetalKit

class Renderer: NSObject, MTKViewDelegate {
    
    var renderView: RenderView!
    var device: MTLDevice!
    
    var movementController: Movement!
    
    var rasterizeUniformBuffer: MTLBuffer!
    var hairParticleBuffer: MTLBuffer!
    var hairParticleIndexBuffer: MTLBuffer!
    var hairUniformBuffer: MTLBuffer!
    var hairVertexBuffer: MTLBuffer!
    
    var rasterizePipelineDescriptor: MTLRenderPipelineDescriptor!
    var rasterizePipelineState: MTLRenderPipelineState!
    
    var depthStencilDescriptor: MTLDepthStencilDescriptor!
    var depthStencilState: MTLDepthStencilState!
    
    var simulationPipelineState: MTLComputePipelineState!
    var particleToVertexPipelineState: MTLComputePipelineState!

    var commandQueue: MTLCommandQueue!
    
    var runSimulation: Bool = false
    var runSingleFrame: Bool = false
    
    var framesElapsed = 0
    
    init?(renderView: RenderView) {
        super.init()
        
        self.renderView = renderView
        initializeRenderer()
    }
    
    func initializeRenderer()
    {
        device = self.renderView.device!
        commandQueue = device.makeCommandQueue()!
        movementController = Movement(initialScreenSize: renderView.frame.size)
        
        initializeRasterizeShaders()
        createDepthStencilDescriptor()
        
        createHairParticles()
        
        
        var simulationUniform = SimulationUniforms()
        simulationUniform.gravity = SIMD3<Float>(0.0, -9.8, 0.0)
        simulationUniform.kDamping = 10.0
        simulationUniform.timestep = 0.0001
        
        fillBuffer(device: device, buffer: &hairUniformBuffer, data: [simulationUniform])
    }
    
    func initializeRasterizeShaders()
    {
        let defaultLibrary = device.makeDefaultLibrary()!
        let vertexShader = defaultLibrary.makeFunction(name: "vertexShader")!
        let fragmentShader = defaultLibrary.makeFunction(name: "fragmentShader")!
        
        rasterizePipelineDescriptor = MTLRenderPipelineDescriptor()
        rasterizePipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        rasterizePipelineDescriptor.vertexFunction = vertexShader
        rasterizePipelineDescriptor.fragmentFunction = fragmentShader
        rasterizePipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        rasterizePipelineState =
            try! device.makeRenderPipelineState(descriptor: rasterizePipelineDescriptor)
        
        
        let simulationFunction =
            defaultLibrary.makeFunction(name: "moveParticles")!
        simulationPipelineState =
            try! device.makeComputePipelineState(function: simulationFunction)
        
        let particleToVertexFunction =
            defaultLibrary.makeFunction(name: "generateVerticesFromParticles")!
        particleToVertexPipelineState =
            try! device.makeComputePipelineState(function: particleToVertexFunction)
        
        
    }
    
    func createDepthStencilDescriptor()
    {
        depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
    }
    
    func fillRasterizeUniformBuffer()
    {
        let uniform = RasterizeUniforms(
            modelViewMatrix: movementController.modelViewMatrix,
            projectionMatrix: movementController.projectionMatrix)
        
        fillBuffer(device: self.device!, buffer: &rasterizeUniformBuffer, data: [uniform])
    }
    
    let numParticles = 20
    func createHairParticles()
    {
        framesElapsed = 0
        var array: [HairParticle] = []
        var array2: [Int32] = []
        
        for x in 0 ..< numParticles
        {
            var p = HairParticle()
            p.position = SIMD3<Float>(1.0 * Float(x) / Float(numParticles), 0.5, 0.0)
            p.color = SIMD3<Float>(0.0, 0.0, 0.0)
            p.particleId = Int32(x)
            p.leftParticleId = p.particleId - 1
            p.rightParticleId = p.particleId + 1
            p.kDist = 8.0
            p.hairDist = 0.5 / Float(numParticles)
            p.mass = 0.1
            p.hairAngle = 120.0
            p.kHair = 8.0
            
            array.append(p)
        }
        
        for x in 0 ..< numParticles - 1
        {
            array2.append(2 * Int32(x) + 0)
            array2.append(2 * Int32(x) + 1)
            array2.append(2 * Int32(x) + 2)

            //array2.append(2 * Int32(x) + 1)
            //array2.append(2 * Int32(x) + 3)
            //array2.append(2 * Int32(x) + 2)

            //array2.append(Int32(x + 1))
        }
                
        array[0].fixed = 1
        array[0].leftParticleId = -1
        array[numParticles - 1].rightParticleId = -1
        
        fillBuffer(device: device, buffer: &hairParticleBuffer, data: array)
        fillBuffer(device: device, buffer: &hairParticleIndexBuffer, data: array2)
        fillBuffer(device: device,
                   buffer: &hairVertexBuffer,
                   data: [],
                   size: MemoryLayout<Vertex>.stride * numParticles * 2)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        movementController.updateScreenSize(newSize: size)
        fillRasterizeUniformBuffer()
    }
    
    
    func createRenderPassDescriptor(texture: MTLTexture) -> MTLRenderPassDescriptor!
    {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.usage = .renderTarget
        textureDescriptor.height = texture.height
        textureDescriptor.width = texture.width
        textureDescriptor.pixelFormat = .depth32Float
        textureDescriptor.storageMode = .private
        renderPassDescriptor.depthAttachment.texture = device.makeTexture(descriptor: textureDescriptor)
        
        return renderPassDescriptor
    }
    
    func simulationStep(commandBuffer: MTLCommandBuffer)
    {
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        commandEncoder.setComputePipelineState(simulationPipelineState)
        commandEncoder.setBuffer(hairParticleBuffer,
                                 offset: 0,
                                 index: Int(SIMULATION_HAIR_PARTICLE_BUFFER))
        
        commandEncoder.setBuffer(hairUniformBuffer,
                                 offset: 0,
                                 index: Int(SIMULATION_UNIFORM_BUFFER))
        
        let threadGroupSize = MTLSizeMake(1, 1, 1)
        var threadCountGroup = MTLSize()
        threadCountGroup.width = (numParticles + threadGroupSize.width - 1) / threadGroupSize.width
        threadCountGroup.height = 1
        threadCountGroup.depth = 1
        commandEncoder.dispatchThreadgroups(threadCountGroup, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
    }
    
    func particleToTriangle(commandBuffer: MTLCommandBuffer)
    {
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        commandEncoder.setComputePipelineState(particleToVertexPipelineState)
        commandEncoder.setBuffer(hairParticleBuffer,
                                 offset: 0,
                                 index: Int(SIMULATION_HAIR_PARTICLE_BUFFER))
        
        commandEncoder.setBuffer(hairVertexBuffer,
                                 offset: 0,
                                 index: Int(SIMULATION_VERTEX_BUFFER))
        
        commandEncoder.setBytes(&movementController.cameraDirection,
                                length: MemoryLayout<SIMD3<Float>>.stride,
                                index: Int(SIMULATION_CAMERA_POSITION_BUFFER))

        let threadGroupSize = MTLSizeMake(1, 1, 1)
        var threadCountGroup = MTLSize()
        threadCountGroup.width = (numParticles + threadGroupSize.width - 1) / threadGroupSize.width
        threadCountGroup.height = 1
        threadCountGroup.depth = 1
        commandEncoder.dispatchThreadgroups(threadCountGroup, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
    }
    
    func numSteps() -> Int
    {
        if (!runSimulation && !runSingleFrame)
        {
            return 0
        }
        if (!runSimulation && runSingleFrame)
        {
            return 1
        }
        
        if (framesElapsed > 61000)
        {
            //return 100
        }
        
        return 1000
    }
    
    func draw(in view: MTKView) {
        fillRasterizeUniformBuffer()
        let commandBuffer = commandQueue.makeCommandBuffer()!
        if (framesElapsed == 62800)
        {
            //runSimulation = false
        }
        
        let n = numSteps()
        for _ in 0 ..< n
        {
            simulationStep(commandBuffer: commandBuffer)
        }
        
        framesElapsed += n
        
        runSingleFrame = false
        
        particleToTriangle(commandBuffer: commandBuffer)
        
        let renderPassDescriptor = createRenderPassDescriptor(texture: renderView.currentDrawable!.texture)
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)!
        commandEncoder.setRenderPipelineState(rasterizePipelineState)
        commandEncoder.setDepthStencilState(depthStencilState)
        //commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(hairVertexBuffer,
                                       offset: 0,
                                       index: Int(RASTERIZE_VERTEX_BUFFER))
        
        commandEncoder.setVertexBuffer(rasterizeUniformBuffer,
                                       offset: 0,
                                       index: Int(RASTERIZE_VERTEX_UNIFORM_BUFFER))
        
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: (numParticles - 1) * 1 * 3, indexType: .uint32, indexBuffer: hairParticleIndexBuffer, indexBufferOffset: 0)
        commandEncoder.endEncoding()
        
        commandBuffer.present(renderView.currentDrawable!)
        commandBuffer.commit()
    }
    
    func keyDown(with theEvent: NSEvent) {
        movementController.keyDown(keyCode: Int(theEvent.keyCode))
        fillRasterizeUniformBuffer()
        
        if (theEvent.keyCode == KEY_R)
        {
            createHairParticles()
        }
        
        if (theEvent.keyCode == KEY_M)
        {
            runSimulation = !runSimulation
        }
        
        if (theEvent.keyCode == KEY_N)
        {
            runSingleFrame = true
        }
        if (theEvent.keyCode == KEY_B)
        {
            print(framesElapsed)
        }
        
    }
    
    func keyUp(with theEvent: NSEvent) {
    }
    
    func mouseUp(with event: NSEvent) {
    }
    
    func mouseDown(with event: NSEvent) {
        movementController.mouseDown(locationInWindow: event.locationInWindow,
                                     frame: event.window!.frame)
        fillRasterizeUniformBuffer()
    }
    
    func mouseDragged(with event: NSEvent) {
        movementController.mouseDragged(locationInWindow: event.locationInWindow,
                                        frame: event.window!.frame)
        fillRasterizeUniformBuffer()
    }
}
