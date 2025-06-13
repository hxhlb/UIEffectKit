//
//  PlatformView.swift
//  UIEffectKit
//
//  Created by 秋星桥 on 6/13/25.
//

import Foundation

#if canImport(UIKit)
    import UIKit

    open class EffectKitView: UIView {}

    public extension UIView {
        func createViewSnapshot() -> UIImage {
            let renderer = UIGraphicsImageRenderer(bounds: bounds)
            return renderer.image { context in
                // clear the background
                context.cgContext.setFillColor(UIColor.clear.cgColor)
                context.cgContext.fill(bounds)

                // MUST USE DRAW HIERARCHY TO RENDER VISUAL EFFECT VIEW
                self.drawHierarchy(in: bounds, afterScreenUpdates: false)
            }
        }
    }

#elseif canImport(AppKit)
    import AppKit

    open class EffectKitView: NSView {}

    public extension NSView {
        func createViewSnapshot() -> CGImage? {
            guard let bitmapRep = bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
            bitmapRep.size = bounds.size
            cacheDisplay(in: bounds, to: bitmapRep)
            return bitmapRep.cgImage
        }
    }
#endif
