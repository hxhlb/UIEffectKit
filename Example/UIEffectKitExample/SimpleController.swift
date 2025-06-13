//
//  SimpleController.swift
//  UIEffectKitExample
//
//  Created by qaq on 22/10/2025.
//

import SwiftUI

#if canImport(UIKit)
    import UIKit

    struct SimpleController<T: UIViewController>: UIViewControllerRepresentable {
        typealias UIViewControllerType = T

        func makeUIViewController(context _: Context) -> T {
            .init()
        }

        func updateUIViewController(_: T, context _: Context) {}
    }

#elseif canImport(AppKit)
    import AppKit

    struct SimpleController<T: NSViewController>: NSViewControllerRepresentable {
        typealias NSViewControllerType = T

        func makeNSViewController(context _: Context) -> T {
            .init()
        }

        func updateNSViewController(_: T, context _: Context) {}
    }
#endif
