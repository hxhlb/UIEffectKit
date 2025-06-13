//
//  BreakGlassTransitionController.swift
//  UIEffectKitExample
//

#if canImport(UIKit)
    import UIEffectKit
    import UIKit

    class BreakGlassTransitionController: UIViewController {
        private var targetView: UIView?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground
            createTargetView()
        }

        private func createTargetView() {
            let containerView = UIView()
            containerView.backgroundColor = .systemBlue
            containerView.layer.cornerRadius = 16
            containerView.translatesAutoresizingMaskIntoConstraints = false
            containerView.isUserInteractionEnabled = true

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            containerView.addGestureRecognizer(tapGesture)

            let label = UILabel()
            label.text = "🔨 Break Me!"
            label.font = .systemFont(ofSize: 32, weight: .bold)
            label.textColor = .white
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false

            containerView.addSubview(label)
            view.addSubview(containerView)

            NSLayoutConstraint.activate([
                containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
                containerView.widthAnchor.constraint(equalToConstant: 300),
                containerView.heightAnchor.constraint(equalToConstant: 200),

                label.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            ])

            targetView = containerView
        }

        @objc private func handleTap() {
            guard let targetView else { return }
            targetView.removeFromSuperviewWithBreakGlassTransition(fractureCount: 96)
            self.targetView = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.createTargetView() }
        }
    }

#elseif canImport(AppKit)
    import AppKit
    import UIEffectKit

    class BreakGlassTransitionController: NSViewController {
        private var targetView: NSView?

        override func loadView() {
            view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            createTargetView()
        }

        private func createTargetView() {
            let containerView = NSView()
            containerView.wantsLayer = true
            containerView.layer?.backgroundColor = NSColor.systemBlue.cgColor
            containerView.layer?.cornerRadius = 16
            containerView.translatesAutoresizingMaskIntoConstraints = false

            let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleTap))
            containerView.addGestureRecognizer(clickGesture)

            let label = NSTextField(labelWithString: "🔨 Break Me!")
            label.font = .systemFont(ofSize: 32, weight: .bold)
            label.textColor = .white
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false

            containerView.addSubview(label)
            view.addSubview(containerView)

            NSLayoutConstraint.activate([
                containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                containerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
                containerView.widthAnchor.constraint(equalToConstant: 300),
                containerView.heightAnchor.constraint(equalToConstant: 200),

                label.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            ])

            targetView = containerView
        }

        @objc private func handleTap() {
            guard let targetView else { return }
            targetView.removeFromSuperviewWithBreakGlassTransition(fractureCount: 96)
            self.targetView = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.createTargetView() }
        }
    }
#endif
