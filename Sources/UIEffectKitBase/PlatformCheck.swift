//
//  PlatformCheck.swift
//  UIEffectKit
//
//  Created by 秋星桥 on 6/13/25.
//

import Foundation

#if !canImport(UIKit) && !canImport(AppKit)
    #error("Unsupported Platform")
#endif
