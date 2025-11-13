//
//  SweepTransitionView.swift
//  UIEffectKit
//

import QuartzCore
import UIEffectKitBase

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public final class SweepTransitionView: EffectKitView {
    public struct Configuration: Equatable {
        /// Leading edge of the visible band along the sweep axis (0 = start, 1 = end).
        public var entryFraction: CGFloat
        /// Trailing edge of the visible band along the sweep axis.
        public var leavingFraction: CGFloat
        /// Normalized width of the feather applied to both edges (0–0.5).
        public var featherFraction: CGFloat
        /// Direction of the sweep in degrees. 0° is left-to-right, 90° is bottom-to-top.
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
        set {
            storedConfiguration = newValue
            applyConfiguration(animated: false)
        }
    }

    #if canImport(UIKit)
        public let contentView = UIView()
    #else
        public let contentView = NSView()
    #endif

    private let gradientMask = CAGradientLayer()
    private var storedConfiguration = Configuration()
    private var pendingAnimationContext: AnimationContext?

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

    /// Update the entry/leaving values with optional implicit animation.
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

    public func setDirectionAngle(_ angle: CGFloat, animated: Bool = false, duration: CFTimeInterval = 0.35) {
        var next = storedConfiguration
        next.directionAngle = angle
        performConfigurationUpdate(next, animated: animated, duration: duration, timingFunction: nil)
    }

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
        if animated {
            pendingAnimationContext = .init(duration: duration, timingFunction: timingFunction)
        } else {
            pendingAnimationContext = nil
        }
        storedConfiguration = newValue
        applyConfiguration(animated: animated)
    }

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

    private func applyConfiguration(animated: Bool) {
        let config = storedConfiguration
        let entry = config.entryFraction.clamped(to: 0 ... 1)
        let leaving = config.leavingFraction.clamped(to: 0 ... 1)
        let lower = min(entry, leaving)
        let upper = max(entry, leaving)
        let span = max(upper - lower, 0.0001)
        let maxFeather = span / 2
        let requestedFeather = config.featherFraction.clamped(to: 0 ... 0.5)
        let feather = min(maxFeather, requestedFeather)
        let lowerEdgeEnd = min(lower + feather, upper)
        let upperEdgeStart = max(upper - feather, lowerEdgeEnd)

        let stops = [
            CGFloat(0),
            lower,
            lowerEdgeEnd,
            upperEdgeStart,
            upper,
            CGFloat(1),
        ]
        let colors: [CGColor] = [
            maskColor(0),
            maskColor(0),
            maskColor(1),
            maskColor(1),
            maskColor(0),
            maskColor(0),
        ]

        let points = Self.gradientPoints(for: config.directionAngle)

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

    private static func gradientPoints(for angle: CGFloat) -> (start: CGPoint, end: CGPoint) {
        let radians = angle * CGFloat.pi / 180
        let dx = cos(radians)
        let dy = sin(radians)
        let start = CGPoint(x: 0.5 - dx / 2, y: 0.5 - dy / 2)
        let end = CGPoint(x: 0.5 + dx / 2, y: 0.5 + dy / 2)
        return (start, end)
    }

    private func maskColor(_ value: CGFloat) -> CGColor {
        #if canImport(UIKit)
            return UIColor(white: value, alpha: 1).cgColor
        #else
            return NSColor(white: value, alpha: 1).cgColor
        #endif
    }
}

private extension SweepTransitionView {
    struct AnimationContext {
        let duration: CFTimeInterval
        let timingFunction: CAMediaTimingFunction?
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
