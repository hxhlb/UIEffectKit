//
//  ShimmerGridPointsView+Renderer.swift
//  UIEffectKit
//

import MetalKit
import QuartzCore

extension ShimmerGridPointsView {
    final class Renderer: NSObject, MTKViewDelegate {
        struct GridPoint {
            var origin: simd_float2
            var jitter: simd_float2
            var size: simd_float2 // (baseRadius, blur)
            var props: simd_float2 // (type, baseIntensity)
            var wave: simd_float2 // (rowPhase, colPhase)
        }

        struct Vertex {
            var position: simd_float2
        }

        private var device: MTLDevice?
        private var commandQueue: MTLCommandQueue?
        private var renderPipeline: MTLRenderPipelineState?
        private var vertexBuffer: MTLBuffer?
        private var pointsBuffer: MTLBuffer?
        private var instanceCount: Int = 0
        private var drawableSize: simd_float2 = .zero
        private var time: Float = 0
        private var last: CFTimeInterval?

        func setup(with device: MTLDevice) {
            self.device = device
            commandQueue = device.makeCommandQueue()
            setupPipeline(device: device)
            setupVertex(device: device)
            regenerateGrid()
        }

        func updateDrawableSize(_ size: CGSize) {
            drawableSize = .init(Float(size.width), Float(size.height))
            last = nil
            regenerateGrid()
        }

        private func setupPipeline(device: MTLDevice) {
            guard let library = try? device.makeDefaultLibrary(bundle: .module) else {
                assertionFailure("Failed to load metal library")
                return
            }
            let v = library.makeFunction(name: "SGP_Vertex")
            let f = library.makeFunction(name: "SGP_Fragment")
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = v
            desc.fragmentFunction = f
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm
            desc.colorAttachments[0].isBlendingEnabled = true
            desc.colorAttachments[0].rgbBlendOperation = .add
            desc.colorAttachments[0].alphaBlendOperation = .add
            desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            desc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            do {
                renderPipeline = try device.makeRenderPipelineState(descriptor: desc)
            } catch {
                assertionFailure("Pipeline fail: \(error)")
            }
        }

        private func setupVertex(device: MTLDevice) {
            let vertices: [Vertex] = [
                .init(position: .init(-0.5, -0.5)),
                .init(position: .init(0.5, -0.5)),
                .init(position: .init(-0.5, 0.5)),
                .init(position: .init(0.5, 0.5)),
            ]
            vertexBuffer = vertices.withUnsafeBytes { p in
                device.makeBuffer(bytes: p.baseAddress!, length: MemoryLayout<Vertex>.stride * vertices.count, options: .storageModeShared)
            }
        }

        private func regenerateGrid() {
            guard let device, drawableSize.x > 0, drawableSize.y > 0 else { return }

            // Create a regular grid spacing; ensure neat alignment
            let spacing: Float = 16 // px grid spacing
            let margin: Float = 8
            let startX = margin
            let startY = margin
            let cols = max(1, Int((drawableSize.x - margin * 2) / spacing))
            let rows = max(1, Int((drawableSize.y - margin * 2) / spacing))

            var points = [GridPoint]()
            points.reserveCapacity(rows * cols)

            for r in 0 ..< rows {
                for c in 0 ..< cols {
                    let x = startX + Float(c) * spacing
                    let y = startY + Float(r) * spacing

                    // Alternate shape types to add visual variety, but still ordered
                    let type: Float = ((r + c) % 2 == 0) ? 0 : 1

                    // Radius within 4–8 px range as asked
                    let radius = Float.random(in: 4.0 ... 8.0)
                    let blur = Float.random(in: 0.08 ... 0.25)

                    let jitter = simd_float2(Float.random(in: 0 ..< .pi * 2), Float.random(in: 0 ..< .pi * 2))
                    let baseIntensity = Float.random(in: 0.6 ... 0.9)

                    // Wave phases derived from row/col to form stripes/diagonals
                    let rowPhase = Float(r) * 0.35
                    let colPhase = Float(c) * 0.42

                    points.append(
                        .init(
                            origin: .init(x, y),
                            jitter: jitter,
                            size: .init(radius, blur),
                            props: .init(type, baseIntensity),
                            wave: .init(rowPhase, colPhase)
                        )
                    )
                }
            }

            instanceCount = points.count
            pointsBuffer = points.withUnsafeBytes { p in
                device.makeBuffer(bytes: p.baseAddress!, length: MemoryLayout<GridPoint>.stride * points.count, options: .storageModeShared)
            }
        }

        func draw(in view: MTKView) {
            guard
                let renderPipeline,
                let commandQueue,
                let vertexBuffer,
                let pointsBuffer,
                instanceCount > 0
            else { return }

            guard let drawable = view.currentDrawable, let rpd = view.currentRenderPassDescriptor else { return }

            let now = CACurrentMediaTime()
            if let last { time += Float(now - last) } else { time = 0 }
            last = now

            rpd.colorAttachments[0].loadAction = .clear
            rpd.colorAttachments[0].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)

            guard let cb = commandQueue.makeCommandBuffer(), let re = cb.makeRenderCommandEncoder(descriptor: rpd) else { return }
            re.setRenderPipelineState(renderPipeline)
            re.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            re.setVertexBuffer(pointsBuffer, offset: 0, index: 1)
            var ds = drawableSize
            var t = time
            re.setVertexBytes(&ds, length: MemoryLayout<simd_float2>.stride, index: 2)
            re.setVertexBytes(&t, length: MemoryLayout<Float>.stride, index: 3)
            re.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: instanceCount)
            re.endEncoding()

            cb.present(drawable)
            cb.commit()
        }

        func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}
    }
}

