//
//  BreakGlassView.swift
//  UIEffectKit
//
//  Created by GitHub Copilot on 10/4/25.
//

import MetalKit
import simd
import UIEffectKitBase

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

final class BreakGlassView: EffectKitView {
    private var device: MTLDevice!
    private var metalView: MTKView!
    private let renderer = Renderer()

    #if canImport(UIKit)
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupMetalDevice()
            setupMetalView()
            configureCommonProperties()
        }

    #elseif canImport(AppKit)
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            setupMetalDevice()
            setupMetalView()
            configureCommonProperties()
        }
    #endif

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        metalView.delegate = nil
        renderer.cancel()
    }

    func begin(
        with image: CGImage,
        targetFrame: CGRect,
        fractureCount: Int = 96,
        onFirstFrameRendered: @escaping () -> Void,
        onComplete: @escaping () -> Void
    ) {
        metalView.isPaused = false
        renderer.prepare(
            with: device,
            image: image,
            targetFrame: targetFrame.integral,
            fractureCount: fractureCount,
            onFirstFrameRendered: onFirstFrameRendered,
            onComplete: { [weak self] in
                guard let self else { return }
                pauseMetalView()
                onComplete()
            }
        )
        metalView.draw()
    }

    private func setupMetalDevice() {
        guard let device = Self.createSystemDefaultDevice() else {
            fatalError("failed to create Metal device")
        }
        self.device = device
    }

    private func setupMetalView() {
        #if canImport(UIKit)
            metalView = MTKView(frame: .zero, device: device)
            metalView.isPaused = false
            metalView.enableSetNeedsDisplay = false
        #elseif canImport(AppKit)
            metalView = MTKView(frame: .zero, device: device)
            metalView.isPaused = false
            metalView.enableSetNeedsDisplay = false
        #endif
        configureMetalView()
        addSubview(metalView)
        updateMetalViewLayout(for: bounds)
    }

    private func configureCommonProperties() {
        #if canImport(UIKit)
            clipsToBounds = false
            metalView.clipsToBounds = false
        #elseif canImport(AppKit)
            wantsLayer = true
            layer?.masksToBounds = false
            metalView.wantsLayer = true
            metalView.layer?.masksToBounds = false
        #endif
    }

    private func configureMetalView() {
        #if canImport(UIKit)
            metalView.layer.isOpaque = false
            metalView.backgroundColor = UIColor.clear
            metalView.isUserInteractionEnabled = false
        #elseif canImport(AppKit)
            metalView.wantsLayer = true
            metalView.layer?.isOpaque = false
            metalView.layer?.backgroundColor = NSColor.clear.cgColor
        #endif
        metalView.delegate = renderer
        metalView.framebufferOnly = false
        metalView.preferredFramesPerSecond = 60
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    }

    private func pauseMetalView() {
        metalView.isPaused = true
    }

    private static func createSystemDefaultDevice() -> MTLDevice? {
        MTLCreateSystemDefaultDevice()
    }

    private func updateMetalViewLayout(for bounds: CGRect) {
        let expandedBounds = bounds.insetBy(dx: -512, dy: -512)
        metalView.frame = expandedBounds

        #if canImport(UIKit)
            let scale = metalView.window?.screen.nativeScale
                ?? UIScreen.main.nativeScale
        #elseif canImport(AppKit)
            let scale = metalView.window?.backingScaleFactor
                ?? metalView.layer?.contentsScale
                ?? NSScreen.main?.backingScaleFactor
                ?? 1
        #endif

        let drawableSize = CGSize(
            width: expandedBounds.width * scale,
            height: expandedBounds.height * scale
        )
        metalView.drawableSize = drawableSize
    }

    #if canImport(UIKit)
        override func layoutSubviews() {
            super.layoutSubviews()
            updateMetalViewLayout(for: bounds)
        }

    #elseif canImport(AppKit)
        override func layout() {
            super.layout()
            updateMetalViewLayout(for: bounds)
        }
    #endif
}
