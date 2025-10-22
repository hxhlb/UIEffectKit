//
//  BreakGlassTransition.swift
//  UIEffectKit
//
//  Created by GitHub Copilot on 10/4/25.
import UIEffectKitBase

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public enum BreakGlassTransition {
    #if canImport(UIKit)
        @discardableResult
        public static func perform(
            on target: UIView,
            fractureCount: Int = 96,
            onFirstFrame: (() -> Void)? = nil,
            completion: (() -> Void)? = nil
        ) -> Bool {
            guard let superview = target.superview else { return false }
            guard MetalCheck.isMetalSupported else {
                completion?()
                return false
            }

            let snapshot = target.createViewSnapshot()
            guard let image = snapshot.cgImage else {
                completion?()
                return false
            }

            let transitionView = BreakGlassView(frame: target.frame)
            if let index = superview.subviews.firstIndex(of: target) {
                superview.insertSubview(transitionView, at: index + 1)
            } else {
                superview.addSubview(transitionView)
            }

            transitionView.layer.zPosition = target.layer.zPosition
            transitionView.center = target.center
            transitionView.bounds = target.bounds
            transitionView.setNeedsLayout()
            transitionView.layoutIfNeeded()

            transitionView.begin(
                with: image,
                targetFrame: target.frame,
                fractureCount: fractureCount,
                onFirstFrameRendered: {
                    onFirstFrame?()
                },
                onComplete: {
                    completion?()
                    transitionView.removeFromSuperview()
                }
            )
            return true
        }

    #elseif canImport(AppKit)
        @discardableResult
        public static func perform(
            on target: NSView,
            fractureCount: Int = 96,
            onFirstFrame: (() -> Void)? = nil,
            completion: (() -> Void)? = nil
        ) -> Bool {
            guard let superview = target.superview else { return false }
            guard MetalCheck.isMetalSupported else {
                completion?()
                return false
            }

            guard let image = target.createViewSnapshot() else {
                completion?()
                return false
            }

            let transitionView = BreakGlassView(frame: target.frame)
            superview.addSubview(transitionView, positioned: .above, relativeTo: target)
            if let sourceLayer = target.layer, let transitionLayer = transitionView.layer {
                transitionLayer.zPosition = sourceLayer.zPosition
            }
            transitionView.needsLayout = true
            transitionView.layoutSubtreeIfNeeded()

            transitionView.begin(
                with: image,
                targetFrame: target.frame,
                fractureCount: fractureCount,
                onFirstFrameRendered: {
                    onFirstFrame?()
                },
                onComplete: {
                    completion?()
                    transitionView.removeFromSuperview()
                }
            )
            return true
        }
    #endif
}
