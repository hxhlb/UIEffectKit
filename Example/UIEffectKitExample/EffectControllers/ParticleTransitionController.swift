//
//  ParticleTransitionController.swift
//  UIEffectKitExample
//
//  Created by 秋星桥 on 6/13/25.
//

import SwiftUI
import UIEffectKit

#if canImport(UIKit)
    import UIKit

    class ParticleTransitionController: UIViewController {
        let imageView = UIImageView(image: .dontRoll)

        override func viewDidLoad() {
            super.viewDidLoad()

            view.addSubview(imageView)
            imageView.contentMode = .scaleAspectFit

            let tap = UITapGestureRecognizer(target: self, action: #selector(explode))
            view.isUserInteractionEnabled = true
            view.addGestureRecognizer(tap)
        }

        override func viewWillLayoutSubviews() {
            super.viewWillLayoutSubviews()
            imageView.frame = .init(x: 0, y: 0, width: 256, height: 256)
            imageView.center = view.center
        }

        @objc func explode() {
            if imageView.superview != nil {
                imageView.removeFromSuperviewWithExplodeEffect()
            } else {
                view.addSubview(imageView)
                view.setNeedsLayout()
            }
        }
    }

#elseif canImport(AppKit)
    import AppKit

    class ParticleTransitionController: NSViewController {
        private let imageView = NSImageView()

        override func viewDidLoad() {
            super.viewDidLoad()

            view.addSubview(imageView)
            imageView.image = .dontRoll
            imageView.imageScaling = .scaleProportionallyUpOrDown

            let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(explode))
            view.addGestureRecognizer(clickGesture)
        }

        override func viewWillLayout() {
            super.viewWillLayout()
            imageView.frame = view.bounds.insetBy(dx: 100, dy: 100)
        }

        @objc private func explode() {
            if imageView.superview != nil {
                imageView.removeFromSuperviewWithExplodeEffect()
            } else {
                view.addSubview(imageView)
                view.needsLayout = true
            }
        }
    }
#endif
