//
//  ShimmerGridPointsController.swift
//  UIEffectKitExample
//

import SwiftUI
import UIEffectKit

#if canImport(UIKit)
    import UIKit

    final class ShimmerGridPointsController: UIViewController {
        private let effectView = ShimmerGridPointsView(frame: .zero)
        private let titleLabel: UILabel = {
            let l = UILabel()
            l.text = "Shimmer Grid Points"
            l.font = .preferredFont(forTextStyle: .title1)
            l.textColor = .white
            l.textAlignment = .center
            return l
        }()

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            view.addSubview(effectView)
            view.addSubview(titleLabel)

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.maximumNumberOfTouches = 1
            effectView.addGestureRecognizer(pan)
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            effectView.frame = view.bounds
            titleLabel.sizeToFit()
            titleLabel.center = .init(x: view.bounds.midX, y: 64)
        }

        @objc private func handlePan(_ g: UIPanGestureRecognizer) {
            let loc = g.location(in: effectView)
            switch g.state {
            case .began, .changed:
                effectView.setHover(pointInView: loc)
            default:
                effectView.setHover(pointInView: nil)
            }
        }
    }

#elseif canImport(AppKit)
    import AppKit

    final class ShimmerGridPointsController: NSViewController {
        private let effectView = ShimmerGridPointsView(frame: .zero)
        private let titleField: NSTextField = {
            let f = NSTextField(labelWithString: "Shimmer Grid Points")
            f.font = .systemFont(ofSize: 24, weight: .semibold)
            f.textColor = .white
            f.alignment = .center
            return f
        }()

        override func loadView() {
            view = NSView()
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.clear.cgColor
            view.addSubview(effectView)
            view.addSubview(titleField)

            let tracking = NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect], owner: self, userInfo: nil)
            view.addTrackingArea(tracking)
        }

        override func viewDidLayout() {
            super.viewDidLayout()
            effectView.frame = view.bounds
            titleField.sizeToFit()
            titleField.frame.origin = .init(x: (view.bounds.width - titleField.frame.width) / 2, y: view.bounds.height - 64)
        }

        override func mouseMoved(with event: NSEvent) {
            let loc = view.convert(event.locationInWindow, from: nil)
            effectView.setHover(pointInView: loc)
        }
    }
#endif
