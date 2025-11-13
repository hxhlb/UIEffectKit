//
//  SweepBandContainerView.swift
//  UIEffectKit
//

import QuartzCore
import UIEffectKitBase

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// Hosts arbitrary content and reveals it through a traveling, feathered mask band.
/// Pair it with shimmer effects for glint-style highlights or use it alone for entry/exit wipes.
public final class SweepBandContainerView: EffectKitView {
    public struct Configuration: Equatable {
        /// Leading edge of the visible band along the sweep axis (0 = start, 1 = end).
        public var entryFraction: CGFloat
        /// Trailing edge of the visible band along the sweep axis (0 = start, 1 = end).
        public var leavingFraction: CGFloat
        /// Normalized width of the feather applied to both band edges (0–0.5).
        public var featherFraction: CGFloat
        /// Direction of travel in degrees. 0° sweeps left-to-right, 90° bottom-to-top.
        public var directionAngle: CGFloat

        public init(
            entryFraction: CGFloat = 0.85,
            leavingFraction: CGFloat = 0.0,
            featherFraction: CGFloat = 0.08,
            directionAngle: CGFloat = 90
        ) {
            self.entryFraction = entryFraction
            self.leavingFraction = leavingFraction
            self.featherFraction = featherFraction
            self.directionAngle = directionAngle
        }
    }

    public var configuration: Configuration {
        get { storedConfiguration }
        set { performConfigurationUpdate(newValue, animated: false, duration: 0, timingFunction: nil) }
    }

    #if canImport(UIKit)
        public let contentView = UIView()
    #else
        public let contentView = NSView()
    #endif

    private let gradientMask = CAGradientLayer()
    private var storedConfiguration = Configuration()
    private var pendingAnimationContext: AnimationContext?

    // MARK: - Lifecycle

    #if canImport(UIKit)
        override public init(frame: CGRect) {
            super.init(frame: frame)
            commonInit()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override public func layoutSubviews() {
            super.layoutSubviews()
            gradientMask.frame = bounds
        }

    #elseif canImport(AppKit)
        override public init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            commonInit()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override public func layout() {
            super.layout()
            gradientMask.frame = bounds
        }
    #endif

    // MARK: - Configuration Updates

    /// Update the entry/leaving band fractions with optional implicit animation.
    public func setEntryFraction(
        _ entryFraction: CGFloat,
        leavingFraction: CGFloat? = nil,
        animated: Bool = true,
        duration: CFTimeInterval = 0.35,
        timingFunction: CAMediaTimingFunction? = nil
    ) {
        var next = storedConfiguration
        next.entryFraction = entryFraction
        if let leavingFraction { next.leavingFraction = leavingFraction }
        performConfigurationUpdate(next, animated: animated, duration: duration, timingFunction: timingFunction)
    }

    /// Update the sweep direction in degrees.
    public func setDirectionAngle(_ angle: CGFloat, animated: Bool = false, duration: CFTimeInterval = 0.35) {
        var next = storedConfiguration
        next.directionAngle = angle
        performConfigurationUpdate(next, animated: animated, duration: duration, timingFunction: nil)
    }

    /// Update the feather width (0–0.5) applied symmetrically to both edges.
    public func setFeatherFraction(_ feather: CGFloat, animated: Bool = false, duration: CFTimeInterval = 0.35) {
        var next = storedConfiguration
        next.featherFraction = feather
        performConfigurationUpdate(next, animated: animated, duration: duration, timingFunction: nil)
    }

    private func performConfigurationUpdate(
        _ newValue: Configuration,
        animated: Bool,
        duration: CFTimeInterval,
        timingFunction: CAMediaTimingFunction?
    ) {
        storedConfiguration = newValue
        if animated {
            pendingAnimationContext = .init(duration: duration, timingFunction: timingFunction)
        } else {
            pendingAnimationContext = nil
        }
        applyConfiguration(animated: animated)
    }

    // MARK: - Setup

    private func commonInit() {
        #if canImport(UIKit)
            backgroundColor = .clear
            contentView.backgroundColor = .clear
        #elseif canImport(AppKit)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
        #endif

        gradientMask.type = .axial
        gradientMask.needsDisplayOnBoundsChange = true
        gradientMask.frame = bounds
        #if canImport(UIKit)
            layer.mask = gradientMask
        #else
            layer?.mask = gradientMask
        #endif
        setupContentView()
        applyConfiguration(animated: false)
    }

    private func setupContentView() {
        addSubview(contentView)
        #if canImport(UIKit)
            contentView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
                contentView.topAnchor.constraint(equalTo: topAnchor),
                contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        #elseif canImport(AppKit)
            contentView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
                contentView.topAnchor.constraint(equalTo: topAnchor),
                contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        #endif
    }

    // MARK: - Mask Application

    private func applyConfiguration(animated: Bool) {
        let parameters = sanitizedParameters(from: storedConfiguration)
        let stops = [
            CGFloat(0),
            parameters.lower,
            parameters.lowerFeatherEnd,
            parameters.upperFeatherStart,
            parameters.upper,
            CGFloat(1),
        ]
        let alphas: [CGFloat] = [0, 0, 1, 1, 0, 0]
        let colors = alphas.map { maskColor(alpha: $0) }
        let points = Self.gradientPoints(for: parameters.directionAngle)

        CATransaction.begin()
        if animated, let context = pendingAnimationContext {
            CATransaction.setAnimationDuration(context.duration)
            if let tf = context.timingFunction {
                CATransaction.setAnimationTimingFunction(tf)
            }
        } else {
            CATransaction.setDisableActions(true)
        }

        gradientMask.locations = stops.map { NSNumber(value: Double($0)) }
        gradientMask.colors = colors
        gradientMask.startPoint = points.start
        gradientMask.endPoint = points.end

        CATransaction.commit()
        pendingAnimationContext = nil
    }

    private func sanitizedParameters(from config: Configuration) -> BandParameters {
        let entry = config.entryFraction.clamped(to: 0 ... 1)
        let leaving = config.leavingFraction.clamped(to: 0 ... 1)
        let lower = min(entry, leaving)
        let upper = max(entry, leaving)
        let span = max(upper - lower, 0.0001)
        let requestedFeather = config.featherFraction.clamped(to: 0 ... 0.5)
        let feather = min(span / 2, requestedFeather)
        let lowerFeatherEnd = min(lower + feather, upper)
        let upperFeatherStart = max(upper - feather, lowerFeatherEnd)
        return BandParameters(
            lower: lower,
            upper: upper,
            lowerFeatherEnd: lowerFeatherEnd,
            upperFeatherStart: upperFeatherStart,
            directionAngle: config.directionAngle
        )
    }

    private static func gradientPoints(for angle: CGFloat) -> (start: CGPoint, end: CGPoint) {
        let radians = angle * CGFloat.pi / 180
        let dx = cos(radians)
        let dy = sin(radians)
        let start = CGPoint(x: 0.5 - dx / 2, y: 0.5 - dy / 2)
        let end = CGPoint(x: 0.5 + dx / 2, y: 0.5 + dy / 2)
        return (start, end)
    }

    private func maskColor(alpha: CGFloat) -> CGColor {
        #if canImport(UIKit)
            return UIColor(white: 1, alpha: alpha).cgColor
        #else
            return NSColor(white: 1, alpha: alpha).cgColor
        #endif
    }
}

private extension SweepBandContainerView {
    struct AnimationContext {
        let duration: CFTimeInterval
        let timingFunction: CAMediaTimingFunction?
    }

    struct BandParameters {
        let lower: CGFloat
        let upper: CGFloat
        let lowerFeatherEnd: CGFloat
        let upperFeatherStart: CGFloat
        let directionAngle: CGFloat
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// Backwards compatibility for earlier naming.
public typealias SweepTransitionView = SweepBandContainerView
