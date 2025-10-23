//
//  ShimmerGridPointsView.swift
//  UIEffectKit
//
//  Creates a regular grid of points (diamond or circular star-like) that
//  shimmer with wave rhythms and subtle wiggle within 4–8 px.
//

import MetalKit
import simd
import UIEffectKitBase

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public final class ShimmerGridPointsView: EffectKitView {
    private var device: MTLDevice?
    private var metalView: MTKView?
    private let renderer = Renderer()

    public struct Configuration: Equatable {
        public enum ShapeMode: Equatable {
            case mixed
            case circles
            case diamonds
        }

        public var spacing: Float = 32
        public var baseColor: SIMD3<Float> = .init(0.95, 0.96, 1.0)
        public var waveSpeed: Float = 1.1
        public var waveStrength: Float = 0.8
        public var blurRange: ClosedRange<Float> = 0.08 ... 0.25
        public var intensityRange: ClosedRange<Float> = 0.6 ... 0.95
        public var shapeMode: ShapeMode = .mixed
        public var enableWiggle: Bool = false
        public var hoverRadius: Float = 96
        public var hoverBoost: Float = 0.6
        public var enableEDR: Bool = false
        public var radiusRange: ClosedRange<Float> = 4.0 ... 8.0

        public init() {}
    }

    @MainActor
    public var configuration = Configuration() {
        didSet {
            renderer.updateConfiguration(configuration)
            #if canImport(UIKit) || canImport(AppKit)
                if let metalView {
                    metalView.colorPixelFormat = renderer.currentPixelFormat()
                }
            #endif
        }
    }

    @MainActor
    public func setHover(pointInView: CGPoint?) {
        guard let metalView else {
            renderer.setHover(nil)
            return
        }
        guard let pointInView else {
            renderer.setHover(nil)
            return
        }
        #if canImport(UIKit)
            let scale = metalView.window?.screen.nativeScale ?? UIScreen.main.nativeScale
            let pixel = SIMD2<Float>(Float(pointInView.x * scale), Float(pointInView.y * scale))
            renderer.setHover(pixel)
        #elseif canImport(AppKit)
            let scale = metalView.window?.backingScaleFactor
                ?? metalView.layer?.contentsScale
                ?? NSScreen.main?.backingScaleFactor
                ?? 1
            // AppKit uses bottom-left origin for view coords. Our shader expects
            // pixel coordinates with top-left origin, so flip Y within bounds.
            let flippedY = metalView.bounds.height - pointInView.y
            let pixel = SIMD2<Float>(Float(pointInView.x * scale), Float(flippedY * scale))
            renderer.setHover(pixel)
        #endif
    }

    #if canImport(UIKit)
        override public init(frame: CGRect) {
            super.init(frame: frame)
            commonInit()
        }

    #elseif canImport(AppKit)
        override public init(frame frameRect: NSRect) {
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
            if #available(iOS 13.4, *) {
                let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
                metalView.addGestureRecognizer(hover)
            }
        #elseif canImport(AppKit)
            wantsLayer = true
            layer?.masksToBounds = false
            layer?.backgroundColor = NSColor.clear.cgColor
            metalView.wantsLayer = true
            metalView.layer?.masksToBounds = false
            addTrackingArea(NSTrackingArea(
                rect: bounds,
                options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
                owner: self,
                userInfo: nil
            ))
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
        override public func layoutSubviews() {
            super.layoutSubviews()
            updateMetalViewLayout(for: bounds)
        }

    #elseif canImport(AppKit)
        override public func layout() {
            super.layout()
            updateMetalViewLayout(for: bounds)
        }
    #endif

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    #if canImport(UIKit)
        @objc private func handleHover(_ g: UIHoverGestureRecognizer) {
            let location = g.location(in: metalView)
            switch g.state {
            case .began, .changed:
                setHover(pointInView: location)
            default:
                setHover(pointInView: nil)
            }
        }
    #elseif canImport(AppKit)
        override public func mouseMoved(with event: NSEvent) {
            let loc = convert(event.locationInWindow, from: nil)
            setHover(pointInView: loc)
        }
    #endif
}
