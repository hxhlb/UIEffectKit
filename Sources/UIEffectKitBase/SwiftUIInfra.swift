//
//  SwiftUIInfra.swift
//  UIEffectKitBase
//
//  Lightweight SwiftUI bridges for EffectKitView types.
//

import Foundation

#if canImport(SwiftUI)
import SwiftUI

public protocol AnyEffectKitView: AnyObject {}

extension EffectKitView: AnyEffectKitView {}

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

