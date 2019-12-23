//
//  RenderView.swift
//  BrotonMapping
//
//  Created by Michael Kelly on 7/9/19.
//  Copyright © 2019 Michael Kelly. All rights reserved.
//

import Foundation
import MetalKit
import Metal


class RenderView: MTKView
{
    var renderer: Renderer!
    
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        self.device = device!
        
        self.framebufferOnly = false
        renderer = Renderer(renderView: self)
        self.delegate = renderer
        renderer.mtkView(self, drawableSizeWillChange: self.drawableSize)
        
        
        
//        let a = SIMD3<Float>(cos(radians_from_degrees(60)), sin(radians_from_degrees(60)), 0.0)
//        let b = SIMD3<Float>(cos(radians_from_degrees(120)), sin(radians_from_degrees(120)), 0.0)
//
//        print(angleBetween(a: a, b: b))
//        print(angleBetween(a: b, b: a))

    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with theEvent: NSEvent) {
        renderer.keyDown(with: theEvent)
    }
    
    override func keyUp(with theEvent: NSEvent) {
        renderer.keyUp(with: theEvent)
    }
    
    override func mouseUp(with event: NSEvent) {
        renderer.mouseUp(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        renderer.mouseDown(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        renderer.mouseDragged(with: event)
    }
}
