//
//  ParticleView+Removal.swift
//  UIEffectKit
//
//  Created by 秋星桥 on 6/13/25.
//

import UIEffectKitBase

#if canImport(UIKit)
    import UIKit

    public extension UIView {
        func removeFromSuperviewWithExplodeEffect() {
            guard let superview else { return }
            guard MetalCheck.isMetalSupported else {
                removeFromSuperview()
                return
            }

            let image = createViewSnapshot()
            guard let cgImage = image.cgImage else {
                removeFromSuperview()
                return
            }

            let frameInSuperview = frame
            let particleView = ParticleView(frame: frameInSuperview)

            insertParticleViewInSuperview(particleView, superview: superview)
            configureParticleView(particleView, frameInSuperview: frameInSuperview)
            startParticleAnimation(particleView, cgImage: cgImage, frameInSuperview: frameInSuperview)
        }

        private func insertParticleViewInSuperview(_ particleView: ParticleView, superview: UIView) {
            if let currentIndex = superview.subviews.firstIndex(of: self) {
                superview.insertSubview(particleView, at: currentIndex + 1)
            } else {
                assertionFailure()
                superview.addSubview(particleView)
            }
        }

        private func configureParticleView(_ particleView: ParticleView, frameInSuperview _: CGRect) {
            particleView.layer.zPosition = layer.zPosition
            particleView.center = center
            particleView.setNeedsLayout()
        }

        private func startParticleAnimation(_ particleView: ParticleView, cgImage: CGImage, frameInSuperview: CGRect) {
            // Defer to next runloop to avoid interfering with current layout pass.
            DispatchQueue.main.async {
                particleView.beginWith(cgImage, targetFrame: frameInSuperview, onComplete: {
                    particleView.removeFromSuperview()
                }, onFirstFrameRendered: { [weak self] in
                    DispatchQueue.main.async { self?.removeFromSuperview() }
                })
            }
        }
    }

#elseif canImport(AppKit)
    import AppKit

    public extension NSView {
        func removeFromSuperviewWithExplodeEffect() {
            guard let superview else { return }
            guard MetalCheck.isMetalSupported else {
                removeFromSuperview()
                return
            }

            let image = createViewSnapshot()
            guard let cgImage = image else {
                removeFromSuperview()
                return
            }

            let frameInSuperview = frame
            let particleView = ParticleView(frame: frameInSuperview)

            insertParticleViewInSuperview(particleView, superview: superview)
            configureParticleView(particleView, frameInSuperview: frameInSuperview)

            startParticleAnimation(particleView, cgImage: cgImage, frameInSuperview: frameInSuperview)
        }

        private func insertParticleViewInSuperview(_ particleView: ParticleView, superview: NSView) {
            superview.addSubview(particleView, positioned: .above, relativeTo: self)
        }

        private func configureParticleView(_ particleView: ParticleView, frameInSuperview _: CGRect) {
            if let layer, let particleLayer = particleView.layer {
                particleLayer.zPosition = layer.zPosition
            }
            particleView.needsLayout = true
        }

        private func startParticleAnimation(_ particleView: ParticleView, cgImage: CGImage, frameInSuperview: CGRect) {
            // Defer to next runloop to avoid layout recursion warnings from SwiftUI.
            DispatchQueue.main.async {
                particleView.beginWith(cgImage, targetFrame: frameInSuperview, onComplete: {
                    particleView.removeFromSuperview()
                }, onFirstFrameRendered: { [weak self] in
                    self?.removeFromSuperview()
                })
            }
        }
    }

#endif
