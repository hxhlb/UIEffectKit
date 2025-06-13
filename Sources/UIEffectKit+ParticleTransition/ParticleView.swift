//
//  ParticleView.swift
//  TrollNFC
//
//  Created by 砍砍 on 6/8/25.
//

import MetalKit
import simd
import UIEffectKitBase

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

class ParticleView: MetalHostView {
    private var renderer = Renderer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        apply(config: .init(extendingArea: .multiple(by: 3)))
        setDelegate(renderer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    deinit { renderer.cancel() }

    func beginWith(
        _ image: CGImage,
        targetFrame: CGRect,
        onComplete: @escaping () -> Void,
        onFirstFrameRendered: @escaping () -> Void
    ) {
        renderer.prepareResources(
            with: device,
            image: image,
            targetFrame: targetFrame,
            onComplete: onComplete,
            onFirstFrameRendered: onFirstFrameRendered
        )
        metalView.draw()
    }
}
