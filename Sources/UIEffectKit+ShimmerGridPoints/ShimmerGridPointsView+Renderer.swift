//
//  ShimmerGridPointsView+Renderer.swift
//  UIEffectKit
//

import MetalKit
import QuartzCore

extension ShimmerGridPointsView {
    final class Renderer: NSObject, MTKViewDelegate {
        struct Uniforms {
            var drawableSize: simd_float2
            var time: Float
            var baseColor: simd_float3
            var waveSpeed: Float
            var waveStrength: Float
            var waveAxis: simd_float2
            var blurMin: Float
            var blurMax: Float
            var intensityMin: Float
            var intensityMax: Float
            var shapeMode: Int32 // 0 mixed, 1 circles, 2 diamonds
            var enableWiggle: Int32
            var hoverPos: simd_float2
            var hoverRadius: Float
            var hoverBoost: Float
            var edrGain: Float
        }

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
        private var pipelinePixelFormat: MTLPixelFormat = .bgra8Unorm
        private var vertexBuffer: MTLBuffer?
        private var pointsBuffer: MTLBuffer?
        private var uniforms = Uniforms(
            drawableSize: .zero,
            time: 0,
            baseColor: .init(0.95, 0.96, 1.0),
            waveSpeed: 1.1,
            waveStrength: 0.8,
            waveAxis: .init(0.7071, 0.7071),
            blurMin: 0.08,
            blurMax: 0.25,
            intensityMin: 0.6,
            intensityMax: 0.95,
            shapeMode: 0,
            enableWiggle: 0,
            hoverPos: .init(-1e6, -1e6),
            hoverRadius: 96,
            hoverBoost: 0.6,
            edrGain: 1.0
        )
        private var instanceCount: Int = 0
        private var drawableSize: simd_float2 = .zero
        private var time: Float = 0
        private var last: CFTimeInterval?
        private var spacing: Float = 64
        private var radiusRange: ClosedRange<Float> = 4.0 ... 8.0
        private var supportsEDR: Bool = false
        private var preferredPixelFormat: MTLPixelFormat = .bgra8Unorm

        func setup(with device: MTLDevice) {
            self.device = device
            commandQueue = device.makeCommandQueue()
            detectEDR(device: device)
            setupPipeline(device: device)
            setupVertex(device: device)
            regenerateGrid()
        }

        func updateDrawableSize(_ size: CGSize) {
            drawableSize = .init(Float(size.width), Float(size.height))
            last = nil
            regenerateGrid()
        }

        @MainActor
        func updateConfiguration(_ config: ShimmerGridPointsView.Configuration) {
            spacing = max(1, config.spacing)
            uniforms.baseColor = config.baseColor
            uniforms.waveSpeed = config.waveSpeed
            uniforms.waveStrength = config.waveStrength
            let radians = config.waveAngle * Float.pi / 180
            var axis = simd_float2(cos(radians), sin(radians))
            if simd_length_squared(axis) < 1e-4 {
                axis = .init(1, 0)
            } else {
                axis = simd_normalize(axis)
            }
            uniforms.waveAxis = axis
            uniforms.blurMin = config.blurRange.lowerBound
            uniforms.blurMax = config.blurRange.upperBound
            uniforms.intensityMin = config.intensityRange.lowerBound
            uniforms.intensityMax = config.intensityRange.upperBound
            radiusRange = config.radiusRange
            switch config.shapeMode {
            case .mixed: uniforms.shapeMode = 0
            case .circles: uniforms.shapeMode = 1
            case .diamonds: uniforms.shapeMode = 2
            }
            uniforms.enableWiggle = config.enableWiggle ? 1 : 0
            uniforms.hoverRadius = config.hoverRadius
            uniforms.hoverBoost = config.hoverBoost
            uniforms.edrGain = (config.enableEDR && supportsEDR) ? max(config.edrGain, 1.0) : 1.0
            // EDR selection: rgba16Float when enabled and supported, else 8-bit
            let newFormat: MTLPixelFormat = (config.enableEDR && supportsEDR) ? .rgba16Float : .bgra8Unorm
            let formatChanged = (newFormat != preferredPixelFormat)
            preferredPixelFormat = newFormat
            if formatChanged {
                // Recreate pipeline to match the new pixel format
                if let device { setupPipeline(device: device) }
            }
            regenerateGrid()
        }

        func currentPixelFormat() -> MTLPixelFormat { preferredPixelFormat }

        @MainActor
        func setHover(_ pos: simd_float2?) {
            if let p = pos { uniforms.hoverPos = p } else { uniforms.hoverPos = .init(-1e6, -1e6) }
        }

        private func detectEDR(device _: MTLDevice) {
            #if canImport(UIKit)
                if #available(iOS 16.0, *) {
                    // Prefer wide color/EDR if available; MTKView sets output format but we keep pipeline in sync
                    supportsEDR = true
                    preferredPixelFormat = .rgba16Float
                }
            #elseif canImport(AppKit)
                if #available(macOS 12.0, *) {
                    supportsEDR = true
                    preferredPixelFormat = .rgba16Float
                }
            #endif
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
            desc.colorAttachments[0].pixelFormat = preferredPixelFormat
            desc.colorAttachments[0].isBlendingEnabled = true
            desc.colorAttachments[0].rgbBlendOperation = .add
            desc.colorAttachments[0].alphaBlendOperation = .add
            desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            desc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            do {
                renderPipeline = try device.makeRenderPipelineState(descriptor: desc)
                pipelinePixelFormat = preferredPixelFormat
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

            // Regular grid to edges. Start at 0 and extend past edge by +1 to ensure fill.
            let startX: Float = 0
            let startY: Float = 0
            let cols = max(1, Int(ceil(drawableSize.x / spacing)) + 1)
            let rows = max(1, Int(ceil(drawableSize.y / spacing)) + 1)

            var points = [GridPoint]()
            points.reserveCapacity(rows * cols)

            for r in 0 ..< rows {
                for c in 0 ..< cols {
                    let x = startX + Float(c) * spacing
                    let y = startY + Float(r) * spacing

                    // Alternate shape types to add visual variety, but still ordered
                    let type: Float = switch uniforms.shapeMode {
                    case 1: 0 // circles
                    case 2: 1 // diamonds
                    default: ((r + c) % 2 == 0) ? 0 : 1 // mixed
                    }

                    // Radius within configurable range
                    let radius = Float.random(in: radiusRange)
                    let blur = Float.random(in: uniforms.blurMin ... uniforms.blurMax)

                    let jitter = simd_float2(Float.random(in: 0 ..< .pi * 2), Float.random(in: 0 ..< .pi * 2))
                    let baseIntensity = Float.random(in: uniforms.intensityMin ... uniforms.intensityMax)

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
            // Ensure the MTKView's pixelFormat matches our pipeline target before acquiring a drawable.
            if view.colorPixelFormat != preferredPixelFormat {
                view.colorPixelFormat = preferredPixelFormat
                // Defer drawing this frame so a new drawable with the correct format is created next tick.
                return
            }
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
            uniforms.drawableSize = drawableSize
            uniforms.time = time
            re.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 2)
            // Pass uniforms to fragment too at index 0 per shader signature
            re.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            re.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: instanceCount)
            re.endEncoding()

            cb.present(drawable)
            cb.commit()
        }

        func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}
    }
}
