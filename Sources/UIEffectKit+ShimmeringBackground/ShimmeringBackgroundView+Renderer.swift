//
//  ShimmeringBackgroundView+Renderer.swift
//  UIEffectKit
//
//  Created by GitHub Copilot on 10/22/25.
//

import MetalKit
import QuartzCore

extension ShimmeringBackgroundView {
    final class Renderer: NSObject, MTKViewDelegate {
        struct Particle {
            var position: simd_float2
            var velocity: simd_float2
            var fade: simd_float2 // (phase, speed)
            var size: simd_float2 // (radius, blur)
            var flicker: simd_float2 // (phase, amplitude)
            var properties: simd_float2 // (type, baseIntensity)
        }

        struct Vertex {
            var position: simd_float2
            var uv: simd_float2
        }

        private var device: MTLDevice?
        private var commandQueue: MTLCommandQueue?
        private var renderPipeline: MTLRenderPipelineState?
        private var computePipeline: MTLComputePipelineState?
        private var vertexBuffer: MTLBuffer?
        private var particleBuffer: MTLBuffer?
        private var particleCount: Int = 0
        private var drawableSize: simd_float2 = .zero
    private var elapsedTime: Float = 0
    private var lastFrameTimestamp: CFTimeInterval?

        func setup(with device: MTLDevice) {
            self.device = device
            commandQueue = device.makeCommandQueue()
            setupPipelines(device: device)
            setupVertexBuffer(device: device)
            regenerateParticles()
        }

        func updateDrawableSize(_ size: CGSize) {
            drawableSize = .init(Float(size.width), Float(size.height))
            regenerateParticles()
        }

        private func setupPipelines(device: MTLDevice) {
            guard let library = try? device.makeDefaultLibrary(bundle: .module) else {
                assertionFailure("Failed to load metal library")
                return
            }
            guard
                let vertexFn = library.makeFunction(name: "SHM_ParticleVertex"),
                let fragmentFn = library.makeFunction(name: "SHM_ParticleFragment"),
                let computeFn = library.makeFunction(name: "SHM_ParticleUpdate")
            else {
                assertionFailure("Missing shader functions")
                return
            }

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].rgbBlendOperation = .add
            descriptor.colorAttachments[0].alphaBlendOperation = .add
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            descriptor.vertexFunction = vertexFn
            descriptor.fragmentFunction = fragmentFn

            do {
                renderPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
                computePipeline = try device.makeComputePipelineState(function: computeFn)
            } catch {
                assertionFailure("Failed to create pipelines: \(error)")
            }
        }

        private func setupVertexBuffer(device: MTLDevice) {
            let vertices: [Vertex] = [
                .init(position: .init(-0.5, -0.5), uv: .init(0, 0)),
                .init(position: .init(0.5, -0.5), uv: .init(1, 0)),
                .init(position: .init(-0.5, 0.5), uv: .init(0, 1)),
                .init(position: .init(0.5, 0.5), uv: .init(1, 1)),
            ]

            vertexBuffer = vertices.withUnsafeBytes { pointer in
                device.makeBuffer(
                    bytes: pointer.baseAddress!,
                    length: MemoryLayout<Vertex>.stride * vertices.count,
                    options: .storageModeShared
                )
            }
        }

        private func regenerateParticles() {
            guard let device, drawableSize.x > 0, drawableSize.y > 0 else { return }

            let area = drawableSize.x * drawableSize.y
            let density: Float = 0.00025 // tuned for "适中" density
            let count = max(128, Int(area * density))

            var particles = [Particle]()
            particles.reserveCapacity(count)

            for _ in 0 ..< count {
                let position = simd_float2(Float.random(in: 0 ..< drawableSize.x), Float.random(in: 0 ..< drawableSize.y))
                let baseSpeed = Float.random(in: 4 ... 12)
                let direction = Float.random(in: -.pi / 6 ... .pi / 6)
                let velocity = simd_float2(
                    sin(direction) * baseSpeed * 0.02,
                    -abs(cos(direction)) * baseSpeed * 0.02
                )

                let fadePhase = Float.random(in: 0 ..< .pi * 2)
                let fadeSpeed = Float.random(in: 0.3 ... 0.7)
                let size = Float.random(in: 1.4 ... 4.6)
                let blur = Float.random(in: 0.15 ... 0.65)
                let type: Float = Bool.random() ? 0 : 1

                let flickerPhase = Float.random(in: 0 ..< .pi * 2)
                let flickerAmplitude = Float.random(in: 0.05 ... 0.25)
                let baseIntensity = Float.random(in: 0.5 ... 0.8)

                particles.append(
                    .init(
                        position: position,
                        velocity: velocity,
                        fade: .init(fadePhase, fadeSpeed),
                        size: .init(size, blur),
                        flicker: .init(flickerPhase, flickerAmplitude),
                        properties: .init(type, baseIntensity)
                    )
                )
            }

            particleCount = particles.count
            particleBuffer = particles.withUnsafeBytes { pointer in
                device.makeBuffer(
                    bytes: pointer.baseAddress!,
                    length: MemoryLayout<Particle>.stride * particles.count,
                    options: .storageModeShared
                )
            }
        }

        func draw(in view: MTKView) {
            guard
                let device,
                let renderPipeline,
                let computePipeline,
                let commandQueue,
                let vertexBuffer,
                let particleBuffer,
                particleCount > 0
            else { return }

            guard let drawable = view.currentDrawable, let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

            let now = CACurrentMediaTime()
            if let lastFrameTimestamp {
                elapsedTime += Float(now - lastFrameTimestamp)
            } else {
                elapsedTime = 0
            }
            lastFrameTimestamp = now

            // compute step
            if let computeCommandBuffer = commandQueue.makeCommandBuffer(),
               let computeEncoder = computeCommandBuffer.makeComputeCommandEncoder()
            {
                computeEncoder.setComputePipelineState(computePipeline)
                computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
                computeEncoder.setBytes(&drawableSize, length: MemoryLayout<simd_float2>.stride, index: 1)
                computeEncoder.setBytes(&elapsedTime, length: MemoryLayout<Float>.stride, index: 2)

                let threadExecutionWidth = computePipeline.threadExecutionWidth
                let threadgroups = MTLSize(width: (particleCount + threadExecutionWidth - 1) / threadExecutionWidth, height: 1, depth: 1)
                let threadsPerGroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
                computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
                computeEncoder.endEncoding()
                computeCommandBuffer.commit()
            }

            // render step
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
            renderEncoder.setRenderPipelineState(renderPipeline)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 1)
            renderEncoder.setVertexBytes(&drawableSize, length: MemoryLayout<simd_float2>.stride, index: 2)
            renderEncoder.setVertexBytes(&elapsedTime, length: MemoryLayout<Float>.stride, index: 3)

            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: particleCount)
            renderEncoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}
    }
}
