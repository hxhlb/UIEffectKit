//
//  ExplodeTransition.swift
//  UIEffectKit
//

import UIEffectKitBase

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public enum ExplodeTransition {
    #if canImport(UIKit)
        @discardableResult
        public static func performInWindow(for target: UIView) -> Bool {
            guard let window = target.window else { return false }
            guard MetalCheck.isMetalSupported else { return false }
            guard let image = target.createViewSnapshot().cgImage else { return false }

            let frameInWindow = target.convert(target.bounds, to: window)
            let overlay = UIView(frame: window.bounds)
            overlay.isUserInteractionEnabled = false
            overlay.backgroundColor = .clear
            window.addSubview(overlay)

            let effect = ParticleView(frame: overlay.bounds)
            overlay.addSubview(effect)
            effect.beginWith(image, targetFrame: frameInWindow, onComplete: { overlay.removeFromSuperview() }, onFirstFrameRendered: {})
            return true
        }

    #elseif canImport(AppKit)
        @discardableResult
        public static func performInWindow(for target: NSView) -> Bool {
            guard let window = target.window, let content = window.contentView else { return false }
            guard MetalCheck.isMetalSupported else { return false }
            guard let image = target.createViewSnapshot() else { return false }

            let frameInWindow = target.convert(target.bounds, to: content)
            let overlay = NSView(frame: content.bounds)
            overlay.wantsLayer = true
            overlay.layer?.backgroundColor = .none
            content.addSubview(overlay, positioned: .above, relativeTo: nil)

            let effect = ParticleView(frame: overlay.bounds)
            overlay.addSubview(effect)
            effect.beginWith(image, targetFrame: frameInWindow, onComplete: { overlay.removeFromSuperview() }, onFirstFrameRendered: {})
            return true
        }
    #endif
}
