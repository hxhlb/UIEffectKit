//
//  BreakGlassView+Transition.swift
//  UIEffectKit
//
//  Created by GitHub Copilot on 10/4/25.
//

import UIEffectKitBase

#if canImport(UIKit)
    import UIKit

    public extension UIView {
        func removeFromSuperviewWithBreakGlassTransition(fractureCount: Int = 96) {
            guard superview != nil else {
                removeFromSuperview()
                return
            }

            let didStart = BreakGlassTransition.perform(
                on: self,
                fractureCount: fractureCount,
                onFirstFrame: { [weak self] in
                    DispatchQueue.main.async { self?.removeFromSuperview() }
                },
                completion: nil
            )

            if !didStart {
                removeFromSuperview()
            }
        }
    }

#elseif canImport(AppKit)
    import AppKit

    public extension NSView {
        func removeFromSuperviewWithBreakGlassTransition(fractureCount: Int = 96) {
            guard superview != nil else {
                removeFromSuperview()
                return
            }

            let didStart = BreakGlassTransition.perform(
                on: self,
                fractureCount: fractureCount,
                onFirstFrame: { [weak self] in
                    DispatchQueue.main.async { self?.removeFromSuperview() }
                },
                completion: nil
            )

            if !didStart {
                removeFromSuperview()
            }
        }
    }
#endif
