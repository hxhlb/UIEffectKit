//
//  EffectHostConfig.swift
//  UIEffectKitBase
//
//  A lightweight configuration object for MetalHostView to reduce
//  repeated boilerplate and enable declarative setup.
//

import Foundation
import MetalKit

public struct EffectHostConfig: Equatable {
    public var extendingArea: ExtendingArea
    public var preferredFramesPerSecond: Int
    public var framebufferOnly: Bool
    public var clearColor: MTLClearColor

    public init(
        extendingArea: ExtendingArea = .none,
        preferredFramesPerSecond: Int = 60,
        framebufferOnly: Bool = false,
        clearColor: MTLClearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    ) {
        self.extendingArea = extendingArea
        self.preferredFramesPerSecond = preferredFramesPerSecond
        self.framebufferOnly = framebufferOnly
        self.clearColor = clearColor
    }

    public static let standard = EffectHostConfig()
}

public func == (lhs: EffectHostConfig, rhs: EffectHostConfig) -> Bool {
    lhs.extendingArea == rhs.extendingArea
        && lhs.preferredFramesPerSecond == rhs.preferredFramesPerSecond
        && lhs.framebufferOnly == rhs.framebufferOnly
        && lhs.clearColor.red == rhs.clearColor.red
        && lhs.clearColor.green == rhs.clearColor.green
        && lhs.clearColor.blue == rhs.clearColor.blue
        && lhs.clearColor.alpha == rhs.clearColor.alpha
}

public extension MetalHostView {
    func apply(config: EffectHostConfig) {
        extendingArea = config.extendingArea
        preferredFramesPerSecond = config.preferredFramesPerSecond
        setFramebufferOnly(config.framebufferOnly)
        setClearColor(config.clearColor)
    }
}

public extension ExtendingArea {
    static var standard: ExtendingArea { .none }
    static func multiple(_ by: CGFloat) -> ExtendingArea { .multiple(by: by) }
    static func padding(_ pt: CGFloat) -> ExtendingArea { .extending(pt: pt) }
}
