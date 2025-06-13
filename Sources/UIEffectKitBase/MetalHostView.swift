//
//  MetalHostView.swift
//  UIEffectKitBase
//
//  A reusable host view for Metal-based effects with configurable
//  extending drawing area and unified cross‑platform setup.
//

import Foundation
import MetalKit

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public enum ExtendingArea: Equatable {
    case none
    case multiple(by: CGFloat)
    case extending(pt: CGFloat)
}

open class MetalHostView: EffectKitView {
    public private(set) var device: MTLDevice!
    public private(set) var metalView: MTKView!

    public var extendingArea: ExtendingArea = .none {
        didSet { setNeedsLayoutForPlatform() }
    }

    public var preferredFramesPerSecond: Int = 60 {
        didSet { metalView?.preferredFramesPerSecond = preferredFramesPerSecond }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupMetalDevice()
        setupMetalView()
        configureCommonProperties()
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { metalView?.delegate = nil }

    // MARK: - Public API

    public func setDelegate(_ delegate: MTKViewDelegate?) {
        metalView.delegate = delegate
    }

    public func setPaused(_ paused: Bool) {
        metalView.isPaused = paused
    }

    public func setFramebufferOnly(_ value: Bool) {
        metalView.framebufferOnly = value
    }

    public func setClearColor(_ color: MTLClearColor) {
        metalView.clearColor = color
    }

    // MARK: - Setup

    private func setupMetalDevice() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("failed to create Metal device")
        }
        self.device = device
    }

    private func setupMetalView() {
        metalView = MTKView(frame: .zero, device: device)
        configureMetalView()
        addSubview(metalView)
        updateMetalViewLayout(for: bounds)
    }

    private func configureCommonProperties() {
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

    private func configureMetalView() {
        #if canImport(UIKit)
            metalView.layer.isOpaque = false
            metalView.backgroundColor = .clear
        #elseif canImport(AppKit)
            metalView.wantsLayer = true
            metalView.layer?.isOpaque = false
            metalView.layer?.backgroundColor = NSColor.clear.cgColor
        #endif
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = false
        metalView.preferredFramesPerSecond = preferredFramesPerSecond
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        metalView.framebufferOnly = false
    }

    // MARK: - Layout / Metrics

    private func expandedBounds(for bounds: CGRect) -> CGRect {
        switch extendingArea {
        case .none:
            return bounds
        case let .extending(pt):
            return bounds.insetBy(dx: -pt, dy: -pt)
        case let .multiple(by):
            guard by > 1 else { return bounds }
            let w = bounds.width * by
            let h = bounds.height * by
            let dx = (w - bounds.width) / 2
            let dy = (h - bounds.height) / 2
            return bounds.insetBy(dx: -dx, dy: -dy)
        }
    }

    private func displayScale() -> CGFloat {
        #if canImport(UIKit)
            return metalView.window?.screen.nativeScale ?? UIScreen.main.nativeScale
        #elseif canImport(AppKit)
            return metalView.window?.backingScaleFactor
                ?? metalView.layer?.contentsScale
                ?? NSScreen.main?.backingScaleFactor
                ?? 1
        #endif
    }

    private func updateMetalViewLayout(for bounds: CGRect) {
        let expanded = expandedBounds(for: bounds)
        metalView.frame = expanded
        let scale = displayScale()
        let drawableSize = CGSize(width: expanded.width * scale, height: expanded.height * scale)
        metalView.drawableSize = drawableSize
    }

    #if canImport(UIKit)
        override open func layoutSubviews() {
            super.layoutSubviews()
            updateMetalViewLayout(for: bounds)
        }

    #elseif canImport(AppKit)
        override open func layout() {
            super.layout()
            updateMetalViewLayout(for: bounds)
        }
    #endif

    private func setNeedsLayoutForPlatform() {
        #if canImport(UIKit)
            setNeedsLayout()
        #elseif canImport(AppKit)
            needsLayout = true
        #endif
    }
}
