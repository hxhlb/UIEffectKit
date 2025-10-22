//
//  ShimmeringBackgroundView.swift
//  UIEffectKit
//
//  Created by GitHub Copilot on 10/22/25.
//

import MetalKit
import simd
import UIEffectKitBase

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public final class ShimmeringBackgroundView: EffectKitView {
    private var device: MTLDevice?
    private var metalView: MTKView?
    private let renderer = Renderer()

    #if canImport(UIKit)
        public override init(frame: CGRect) {
            super.init(frame: frame)
            commonInit()
        }
    #elseif canImport(AppKit)
        public override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            commonInit()
        }
    #endif

    deinit {
        metalView?.delegate = nil
    }

    private func commonInit() {
        guard MetalCheck.isMetalSupported else { return }
        guard let device = MTLCreateSystemDefaultDevice() else {
            assertionFailure("failed to create Metal device")
            return
        }

        self.device = device
        setupMetalView(with: device)
        setupViewProperties()
        renderer.setup(with: device)
    }

    private func setupMetalView(with device: MTLDevice) {
        let metalView = MTKView(frame: bounds, device: device)
        configureMetalView(metalView)
        addSubview(metalView)
        self.metalView = metalView
        updateMetalViewLayout(for: bounds)
    }

    private func configureMetalView(_ metalView: MTKView) {
        #if canImport(UIKit)
            metalView.layer.isOpaque = false
            metalView.backgroundColor = .clear
            metalView.preferredFramesPerSecond = 60
        #elseif canImport(AppKit)
            metalView.wantsLayer = true
            metalView.layer?.isOpaque = false
            metalView.layer?.backgroundColor = NSColor.clear.cgColor
            metalView.preferredFramesPerSecond = 60
        #endif
        metalView.framebufferOnly = false
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = false
        metalView.delegate = renderer
    }

    private func setupViewProperties() {
        guard let metalView else { return }
        #if canImport(UIKit)
            clipsToBounds = false
            metalView.clipsToBounds = false
            backgroundColor = .clear
        #elseif canImport(AppKit)
            wantsLayer = true
            layer?.masksToBounds = false
            layer?.backgroundColor = NSColor.clear.cgColor
            metalView.wantsLayer = true
            metalView.layer?.masksToBounds = false
        #endif
    }

    private func updateMetalViewLayout(for bounds: CGRect) {
        guard let metalView else { return }
        metalView.frame = bounds

        #if canImport(UIKit)
            let scale = metalView.window?.screen.nativeScale ?? UIScreen.main.nativeScale
        #elseif canImport(AppKit)
            let scale = metalView.window?.backingScaleFactor
                ?? metalView.layer?.contentsScale
                ?? NSScreen.main?.backingScaleFactor
                ?? 1
            metalView.layer?.contentsScale = scale
        #endif

        let drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        metalView.drawableSize = drawableSize
        renderer.updateDrawableSize(drawableSize)
    }

    #if canImport(UIKit)
        public override func layoutSubviews() {
            super.layoutSubviews()
            updateMetalViewLayout(for: bounds)
        }
    #elseif canImport(AppKit)
        public override func layout() {
            super.layout()
            updateMetalViewLayout(for: bounds)
        }
    #endif

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
