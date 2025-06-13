//
//  BreakGlassView+Renderer.swift
//  UIEffectKit
//
//  Created by GitHub Copilot on 10/4/25.
//

import MetalKit
import simd

extension BreakGlassView {
    final class Renderer: NSObject, MTKViewDelegate {
        private struct Vertex {
            var localPosition: simd_float2
            var uv: simd_float2
            var shardIndex: UInt32
            var padding: UInt32 = 0
        }

        private struct ShardUniform {
            var transform: simd_float4x4
            var parameters: simd_float4
        }

        private struct GlobalUniform {
            var viewportSize: simd_float2
            var targetSize: simd_float2
            var elapsed: Float
            var padding: Float
        }

        private struct ShardState {
            var center: simd_float2
            var velocity: simd_float2
            var acceleration: simd_float2
            var radialDirection: simd_float2
            var expansionBoost: Float
            var radialOpacity: Float
            var angularVelocity: Float
            var angularAcceleration: Float
            var rotation: Float
            var offset: simd_float2
            var life: Float
            var age: Float
            var delay: Float
            var opacity: Float
            var scale: Float
        }

        private var device: MTLDevice!
        private var commandQueue: MTLCommandQueue!
        private var pipelineState: MTLRenderPipelineState!
        private var samplerState: MTLSamplerState!
        private var vertexBuffer: MTLBuffer!
        private var shardUniformBuffer: MTLBuffer!
        private var globalUniformBuffer: MTLBuffer!
        private var shards: [ShardState] = []
        private var shardUniforms: [ShardUniform] = []
        private var globalUniform = GlobalUniform(viewportSize: .zero, targetSize: .zero, elapsed: 0, padding: 0)
        private var texture: MTLTexture!
        private var startTime: CFTimeInterval = 0
        private var lastUpdateTime: CFTimeInterval = 0
        private var isPrepared = false
        private var hasSentFirstFrame = false
        private var onFirstFrameRendered: (() -> Void)?
        private var onComplete: (() -> Void)?
        private var pendingVertices: [Vertex] = []
        private var targetFrameSize: simd_float2 = .zero
        private var isSettingUp = false
        private var isFinishing = false

        func prepare(
            with device: MTLDevice,
            image: CGImage,
            targetFrame: CGRect,
            fractureCount: Int,
            onFirstFrameRendered: @escaping () -> Void,
            onComplete: @escaping () -> Void
        ) {
            guard !isPrepared, !isSettingUp else { return }

            isSettingUp = true

            self.device = device
            self.onFirstFrameRendered = onFirstFrameRendered
            self.onComplete = onComplete
            hasSentFirstFrame = false
            startTime = 0
            lastUpdateTime = 0
            isFinishing = false

            let safeWidth = max(targetFrame.width, 1)
            let safeHeight = max(targetFrame.height, 1)
            targetFrameSize = .init(Float(safeWidth), Float(safeHeight))
            globalUniform.targetSize = targetFrameSize

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }

                setupPipeline()
                setupSampler()
                setupGeometry(targetFrame: targetFrame, fractureCount: fractureCount)
                setupBuffers(device: device)
                setupTexture(from: image, device: device)
                finalizeSetup(device: device)

                DispatchQueue.main.async {
                    self.isPrepared = true
                    self.isSettingUp = false
                }
            }
        }

        func draw(in view: MTKView) {
            guard isPrepared else { return }

            let viewBounds = view.bounds.size
            globalUniform.viewportSize = .init(Float(max(viewBounds.width, 1)), Float(max(viewBounds.height, 1)))
            let safeWidth = max(viewBounds.width, 1)
            let safeHeight = max(viewBounds.height, 1)
            globalUniform.viewportSize = .init(Float(safeWidth), Float(safeHeight))
            globalUniform.targetSize = targetFrameSize

            let deltaTime = updateTime()
            let aliveCount = updateShardStates(deltaTime: deltaTime)

            if aliveCount == 0 {
                handleCompletion()
                return
            }

            guard let commandQueue else { return }
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
            guard let drawable = view.currentDrawable else { return }

            updateBuffers()

            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(shardUniformBuffer, offset: 0, index: 1)
            renderEncoder.setVertexBuffer(globalUniformBuffer, offset: 0, index: 2)
            renderEncoder.setFragmentTexture(texture, index: 0)
            renderEncoder.setFragmentSamplerState(samplerState, index: 0)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: pendingVertices.count)
            renderEncoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()

            if !hasSentFirstFrame {
                hasSentFirstFrame = true
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    onFirstFrameRendered?()
                    onFirstFrameRendered = nil
                }
            }
        }

        func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {
            // No-op
        }

        // MARK: - Setup

        private func setupPipeline() {
            let library: MTLLibrary
            do {
                library = try device.makeDefaultLibrary(bundle: .module)
            } catch {
                fatalError("failed to create default library: \(error)")
            }

            guard
                let vertexFunction = library.makeFunction(name: "BGT_Vertex"),
                let fragmentFunction = library.makeFunction(name: "BGT_Fragment")
            else {
                fatalError("failed to find shader functions")
            }

            let vertexDescriptor = MTLVertexDescriptor()
            vertexDescriptor.attributes[0].format = .float2
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = 0
            vertexDescriptor.attributes[1].format = .float2
            vertexDescriptor.attributes[1].offset = MemoryLayout<simd_float2>.stride
            vertexDescriptor.attributes[1].bufferIndex = 0
            vertexDescriptor.attributes[2].format = .uint
            vertexDescriptor.attributes[2].offset = MemoryLayout<simd_float2>.stride * 2
            vertexDescriptor.attributes[2].bufferIndex = 0
            vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
            vertexDescriptor.layouts[0].stepRate = 1
            vertexDescriptor.layouts[0].stepFunction = .perVertex

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.vertexDescriptor = vertexDescriptor
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                fatalError("failed to make pipeline state: \(error)")
            }
        }

        private func setupSampler() {
            let descriptor = MTLSamplerDescriptor()
            descriptor.minFilter = .linear
            descriptor.magFilter = .linear
            descriptor.mipFilter = .notMipmapped
            descriptor.sAddressMode = .clampToEdge
            descriptor.tAddressMode = .clampToEdge
            samplerState = device.makeSamplerState(descriptor: descriptor)
        }

        private func setupGeometry(targetFrame: CGRect, fractureCount: Int) {
            let safeWidth = max(targetFrame.width, 1)
            let safeHeight = max(targetFrame.height, 1)

            let columns = max(3, Int(round(sqrt(Double(fractureCount) * Double(safeWidth / safeHeight)))))
            let rows = max(3, Int(round(Double(fractureCount) / Double(columns))))
            let columnCount = max(columns, 3)
            let rowCount = max(rows, 3)

            let cellWidth = Float(safeWidth) / Float(columnCount)
            let cellHeight = Float(safeHeight) / Float(rowCount)

            var gridPoints: [[simd_float2]] = Array(
                repeating: Array(repeating: .zero, count: columnCount + 1),
                count: rowCount + 1
            )

            for row in 0 ... rowCount {
                for column in 0 ... columnCount {
                    let isBoundary = row == 0 || row == rowCount || column == 0 || column == columnCount
                    let baseX = Float(column) * cellWidth
                    let baseY = Float(row) * cellHeight
                    let jitterX: Float = isBoundary ? 0 : Float.random(in: -cellWidth * 0.25 ... cellWidth * 0.25)
                    let jitterY: Float = isBoundary ? 0 : Float.random(in: -cellHeight * 0.25 ... cellHeight * 0.25)
                    let point = simd_float2(baseX + jitterX, baseY + jitterY)
                    gridPoints[row][column] = point
                }
            }

            let totalShards = columnCount * rowCount
            shards.reserveCapacity(totalShards)
            shardUniforms.reserveCapacity(totalShards)

            var vertices: [Vertex] = []
            vertices.reserveCapacity(totalShards * 6)

            let frameCenter = simd_float2(Float(safeWidth) / 2, Float(safeHeight) / 2)
            let maxDistance = max(simd_length(frameCenter), 1)

            for row in 0 ..< rowCount {
                for column in 0 ..< columnCount {
                    let p00 = gridPoints[row][column]
                    let p10 = gridPoints[row][column + 1]
                    let p01 = gridPoints[row + 1][column]
                    let p11 = gridPoints[row + 1][column + 1]

                    let shardIndex = shards.count
                    let useDiagonal = Bool.random()

                    let trianglePoints: [simd_float2] = if useDiagonal {
                        [p00, p10, p11, p00, p11, p01]
                    } else {
                        [p00, p10, p01, p10, p11, p01]
                    }

                    let uniquePoints = [p00, p10, p01, p11]
                    let centroid = uniquePoints.reduce(simd_float2.zero, +) / Float(uniquePoints.count)

                    let direction = normalizeSafe(centroid - frameCenter)
                    let distance = simd_length(centroid - frameCenter)
                    let normalizedDistance = min(1, distance / maxDistance)
                    let centerBias = max(0, 1 - normalizedDistance)
                    let radialOpacity = max(0.2, powf(max(0, 1 - normalizedDistance), 0.6))
                    let delay = Float(distance / maxDistance) * 0.18 + Float.random(in: 0 ... 0.05)

                    let speedBase: Float = 220
                    let speed = speedBase * (0.75 + Float.random(in: 0 ... 0.5))
                    let radialBoost = 1 + centerBias * 1.35
                    let radialVelocity = direction * speed * radialBoost
                    let lateralVariance = Float.random(in: -80 ... 80) * (0.6 + (1 - centerBias) * 0.4)
                    let lateral = perpendicular(direction) * lateralVariance
                    let initialVelocity = radialVelocity + lateral

                    let radialAccelerationMagnitude = 140 * centerBias + Float.random(in: 0 ... 60)
                    let radialAcceleration = direction * radialAccelerationMagnitude
                    let gravity = simd_float2(Float.random(in: -30 ... 30), 280)
                    let acceleration = gravity + radialAcceleration
                    let angularVelocity = Float.random(in: -3 ... 3)
                    let angularAcceleration = Float.random(in: -1.5 ... 1.5)
                    let life = Float.random(in: 1.4 ... 2.2)
                    let expansionBoost = 1 + centerBias * 1.65

                    var shardVertices: [Vertex] = []
                    shardVertices.reserveCapacity(6)

                    for point in trianglePoints {
                        let localPosition = point - centroid
                        let uv = simd_float2(
                            point.x / Float(safeWidth),
                            point.y / Float(safeHeight)
                        )
                        shardVertices.append(Vertex(
                            localPosition: localPosition,
                            uv: uv,
                            shardIndex: UInt32(shardIndex),
                            padding: 0
                        ))
                    }

                    vertices.append(contentsOf: shardVertices)

                    let shardState = ShardState(
                        center: centroid,
                        velocity: initialVelocity,
                        acceleration: acceleration,
                        radialDirection: direction,
                        expansionBoost: expansionBoost,
                        radialOpacity: radialOpacity,
                        angularVelocity: angularVelocity,
                        angularAcceleration: angularAcceleration,
                        rotation: Float.random(in: -0.35 ... 0.35),
                        offset: .zero,
                        life: life,
                        age: 0,
                        delay: delay,
                        opacity: 1,
                        scale: 1
                    )
                    shards.append(shardState)
                    shardUniforms.append(ShardUniform(
                        transform: makeTransformMatrix(translation: centroid, rotation: shardState.rotation, scale: 1),
                        parameters: simd_float4(radialOpacity, 0, 0, 0)
                    ))
                }
            }

            pendingVertices = vertices
        }

        private func setupBuffers(device: MTLDevice) {
            guard !pendingVertices.isEmpty else { return }
            let vertexBufferLength = MemoryLayout<Vertex>.stride * pendingVertices.count
            vertexBuffer = device.makeBuffer(length: vertexBufferLength, options: .storageModeShared)
            pendingVertices.withUnsafeBytes { pointer in
                vertexBuffer.contents().copyMemory(from: pointer.baseAddress!, byteCount: pointer.count)
            }

            let shardUniformLength = MemoryLayout<ShardUniform>.stride * shardUniforms.count
            shardUniformBuffer = device.makeBuffer(length: shardUniformLength, options: .storageModeShared)
            shardUniforms.withUnsafeBytes { pointer in
                shardUniformBuffer.contents().copyMemory(from: pointer.baseAddress!, byteCount: pointer.count)
            }

            globalUniform.viewportSize = targetFrameSize
            globalUniform.targetSize = targetFrameSize
            globalUniform.elapsed = 0
            globalUniformBuffer = device.makeBuffer(length: MemoryLayout<GlobalUniform>.stride, options: .storageModeShared)
            withUnsafePointer(to: &globalUniform) { pointer in
                globalUniformBuffer.contents().copyMemory(from: pointer, byteCount: MemoryLayout<GlobalUniform>.stride)
            }
        }

        private func setupTexture(from image: CGImage, device: MTLDevice) {
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

            guard let context = CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                fatalError("failed to create CGContext for snapshot")
            }

            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard let convertedImage = context.makeImage() else {
                fatalError("failed to convert snapshot image")
            }

            let loader = MTKTextureLoader(device: device)
            let options: [MTKTextureLoader.Option: Any] = [
                .SRGB: false,
                .textureStorageMode: MTLStorageMode.private.rawValue,
            ]

            do {
                texture = try loader.newTexture(cgImage: convertedImage, options: options)
            } catch {
                fatalError("failed to create texture: \(error)")
            }
        }

        private func finalizeSetup(device: MTLDevice) {
            commandQueue = device.makeCommandQueue()
            startTime = CACurrentMediaTime()
            lastUpdateTime = startTime
        }

        // MARK: - Frame Updates

        @discardableResult
        private func updateTime() -> Float {
            let current = CACurrentMediaTime()
            if startTime == 0 {
                startTime = current
                lastUpdateTime = current
            }

            let rawDelta = current - lastUpdateTime
            let clampedDelta = max(1.0 / 240.0, min(1.0 / 24.0, rawDelta))
            lastUpdateTime = current

            globalUniform.elapsed = Float(current - startTime)
            withUnsafePointer(to: &globalUniform) { pointer in
                globalUniformBuffer.contents().copyMemory(from: pointer, byteCount: MemoryLayout<GlobalUniform>.stride)
            }

            return Float(clampedDelta)
        }

        private func updateBuffers() {
            shardUniforms.withUnsafeBytes { pointer in
                shardUniformBuffer.contents().copyMemory(from: pointer.baseAddress!, byteCount: pointer.count)
            }
        }

        @discardableResult
        private func updateShardStates(deltaTime: Float) -> Int {
            let clampedDelta = max(1 / 240, min(1 / 30, deltaTime))
            let elapsed = Float(globalUniform.elapsed)

            var aliveCount = 0

            for index in shards.indices {
                var shard = shards[index]

                if elapsed < shard.delay {
                    shardUniforms[index].transform = makeTransformMatrix(
                        translation: shard.center,
                        rotation: shard.rotation,
                        scale: shard.scale
                    )
                    shard.opacity = shard.radialOpacity
                    shardUniforms[index].parameters = simd_float4(shard.opacity, 0, 0, 0)
                    shards[index] = shard
                    aliveCount += 1
                    continue
                }

                shard.age += clampedDelta

                shard.velocity += shard.acceleration * clampedDelta
                shard.velocity += shard.radialDirection * shard.expansionBoost * 45 * clampedDelta
                shard.velocity *= 0.992
                shard.offset += shard.velocity * clampedDelta

                shard.angularVelocity += shard.angularAcceleration * clampedDelta
                shard.angularVelocity *= 0.98
                shard.rotation += shard.angularVelocity * clampedDelta

                let fadeProgress = simd_smoothstep(shard.life - 0.75, shard.life, shard.age)
                let timeOpacity = max(0, 1 - fadeProgress)
                shard.opacity = min(timeOpacity, shard.radialOpacity)

                let growthAge = min(shard.age, shard.life)
                let expansionGrowth = min(0.5 * shard.expansionBoost, growthAge * 0.18 * shard.expansionBoost)
                shard.scale = 1 + expansionGrowth

                if shard.opacity > 0.005 {
                    aliveCount += 1
                } else {
                    shard.opacity = 0
                }

                let translation = shard.center + shard.offset
                shardUniforms[index].transform = makeTransformMatrix(
                    translation: translation,
                    rotation: shard.rotation,
                    scale: shard.scale
                )
                shardUniforms[index].parameters = simd_float4(shard.opacity, 0, 0, 0)

                shards[index] = shard
            }

            return aliveCount
        }

        // MARK: - Completion

        private func handleCompletion() {
            guard !isFinishing else { return }
            isFinishing = true

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                let completion = onComplete
                cleanupResources()
                completion?()
            }
        }

        private func cleanupResources() {
            isPrepared = false
            isSettingUp = false
            hasSentFirstFrame = false
            startTime = 0
            lastUpdateTime = 0
            targetFrameSize = .zero
            globalUniform = GlobalUniform(viewportSize: .zero, targetSize: .zero, elapsed: 0, padding: 0)

            shards.removeAll(keepingCapacity: false)
            shardUniforms.removeAll(keepingCapacity: false)
            pendingVertices.removeAll(keepingCapacity: false)

            vertexBuffer.setPurgeableState(.empty)
            vertexBuffer = nil
            shardUniformBuffer.setPurgeableState(.empty)
            shardUniformBuffer = nil
            globalUniformBuffer.setPurgeableState(.empty)
            globalUniformBuffer = nil
            texture.setPurgeableState(.empty)
            texture = nil
            commandQueue = nil
            pipelineState = nil
            samplerState = nil
            device = nil

            onFirstFrameRendered = nil
            onComplete = nil
            isFinishing = false
        }

        func cancel() {
            guard isPrepared || isSettingUp else { return }
            isFinishing = true

            DispatchQueue.main.async { [weak self] in
                self?.cleanupResources()
            }
        }

        // MARK: - Helpers

        private func makeTransformMatrix(translation: simd_float2, rotation: Float, scale: Float) -> simd_float4x4 {
            let cosValue = cos(rotation) * scale
            let sinValue = sin(rotation) * scale

            let column0 = simd_float4(cosValue, sinValue, 0, 0)
            let column1 = simd_float4(-sinValue, cosValue, 0, 0)
            let column2 = simd_float4(0, 0, 1, 0)
            let column3 = simd_float4(translation.x, translation.y, 0, 1)
            return simd_float4x4(columns: (column0, column1, column2, column3))
        }

        private func normalizeSafe(_ value: simd_float2) -> simd_float2 {
            let magnitudeSquared = simd_length_squared(value)
            guard magnitudeSquared > Float.ulpOfOne else {
                var random = simd_float2(Float.random(in: -1 ... 1), Float.random(in: -1 ... 1))
                if simd_length_squared(random) <= Float.ulpOfOne {
                    random = simd_float2(0, -1)
                }
                return simd_normalize(random)
            }
            return value / sqrt(magnitudeSquared)
        }

        private func perpendicular(_ value: simd_float2) -> simd_float2 {
            simd_float2(-value.y, value.x)
        }
    }
}
