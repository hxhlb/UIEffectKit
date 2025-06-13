//
//  SwiftUIInfra.swift
//  UIEffectKitBase
//
//  Lightweight SwiftUI bridges for EffectKitView types.
//

import Foundation
import UIEffectKitBase

#if canImport(SwiftUI)
    import SwiftUI

    public protocol AnyEffectKitView: AnyObject {}
    extension EffectKitView: AnyEffectKitView {}

    // MARK: - Hosting View Accessor

    #if canImport(UIKit)
        public typealias PlatformView = UIView
        private struct HostingViewProbe: UIViewRepresentable {
            let onResolve: (UIView) -> Void
            func makeUIView(context _: Context) -> UIView { UIView(frame: .zero) }
            func updateUIView(_ uiView: UIView, context _: Context) {
                let candidate = uiView.superview ?? uiView
                let typeName = String(describing: type(of: candidate))
                if typeName.contains("PlatformViewHost") || typeName.contains("Hosting") {
                    onResolve(candidate.superview ?? candidate)
                } else {
                    onResolve(candidate)
                }
            }
        }

    #elseif canImport(AppKit)
        public typealias PlatformView = NSView
        private struct HostingViewProbe: NSViewRepresentable {
            let onResolve: (NSView) -> Void
            func makeNSView(context _: Context) -> NSView { NSView(frame: .zero) }
            func updateNSView(_ nsView: NSView, context _: Context) {
                let candidate = nsView.superview ?? nsView
                let typeName = String(describing: type(of: candidate))
                if typeName.contains("PlatformViewHost") || typeName.contains("Hosting") {
                    onResolve(candidate.superview ?? candidate)
                } else {
                    onResolve(candidate)
                }
            }
        }
    #endif

    private final class WeakBox<T: AnyObject> {
        weak var value: T?
        init(_ value: T? = nil) { self.value = value }
    }

    public extension View {
        func captureHostingView(_ onResolve: @escaping (PlatformView) -> Void) -> some View {
            background(HostingViewProbe(onResolve: onResolve))
        }
    }

    #if canImport(UIKit)
        import UIKit

        public struct EffectKitViewRepresentable<V: EffectKitView>: UIViewRepresentable {
            public typealias UIViewType = V

            private let make: () -> V
            private let update: (V) -> Void

            public init(make: @escaping () -> V, update: @escaping (V) -> Void) {
                self.make = make
                self.update = update
            }

            public func makeUIView(context _: Context) -> V { make() }
            public func updateUIView(_ view: V, context _: Context) { update(view) }
        }

    #elseif canImport(AppKit)
        import AppKit

        public struct EffectKitViewRepresentable<V: EffectKitView>: NSViewRepresentable {
            public typealias NSViewType = V

            private let make: () -> V
            private let update: (V) -> Void

            public init(make: @escaping () -> V, update: @escaping (V) -> Void) {
                self.make = make
                self.update = update
            }

            public func makeNSView(context _: Context) -> V { make() }
            public func updateNSView(_ view: V, context _: Context) { update(view) }
        }

    #endif

#endif
