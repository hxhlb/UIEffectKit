//
//  MetalCheck.swift
//  UIEffectKit
//
//  Created by 秋星桥 on 6/13/25.
//

import MetalKit

public enum MetalCheck {
    public static var isMetalSupported: Bool {
        MTLCreateSystemDefaultDevice() != nil
    }
}
