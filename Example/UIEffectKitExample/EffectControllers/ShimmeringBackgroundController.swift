//
//  ShimmeringBackgroundController.swift
//  UIEffectKitExample
//
//  Created by GitHub Copilot on 10/22/25.
//

import SwiftUI
import UIEffectKit

#if canImport(UIKit)
    import UIKit

    final class ShimmeringBackgroundController: UIViewController {
        private let shimmeringView = ShimmeringBackgroundView(frame: .zero)
        private let titleLabel: UILabel = {
            let label = UILabel()
            label.text = "Shimmering Background"
            label.font = .preferredFont(forTextStyle: .largeTitle)
            label.textColor = .white
            label.textAlignment = .center
            label.numberOfLines = 1
            return label
        }()

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black

            view.addSubview(shimmeringView)
            view.addSubview(titleLabel)
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            shimmeringView.frame = view.bounds
            titleLabel.sizeToFit()
            titleLabel.center = .init(x: view.bounds.midX, y: view.bounds.midY)
        }
    }

#elseif canImport(AppKit)
    import AppKit

    final class ShimmeringBackgroundController: NSViewController {
        private let shimmeringView = ShimmeringBackgroundView(frame: .zero)
        private let titleTextField: NSTextField = {
            let field = NSTextField(labelWithString: "Shimmering")
            field.font = .systemFont(ofSize: 42, weight: .bold)
            field.textColor = .white
            field.alignment = .center
            return field
        }()

        override func loadView() {
            view = NSView()
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.black.cgColor

            view.addSubview(shimmeringView)
            view.addSubview(titleTextField)
        }

        override func viewDidLayout() {
            super.viewDidLayout()
            shimmeringView.frame = view.bounds
            titleTextField.sizeToFit()
            titleTextField.frame.origin = .init(
                x: (view.bounds.width - titleTextField.frame.width) / 2,
                y: (view.bounds.height - titleTextField.frame.height) / 2
            )
        }
    }
#endif
