//
//  BreakGlassView.swift
//  UIEffectKit
//
//  Created by GitHub Copilot on 10/4/25.
//

import MetalKit
import simd
import UIEffectKitBase

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

final class BreakGlassView: MetalHostView {
    private let renderer = Renderer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        apply(config: .init(extendingArea: .extending(pt: 512), framebufferOnly: false))
        setDelegate(renderer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { renderer.cancel() }

    func begin(
        with image: CGImage,
        targetFrame: CGRect,
        fractureCount: Int = 96,
        onFirstFrameRendered: @escaping () -> Void,
        onComplete: @escaping () -> Void
    ) {
        metalView.isPaused = false
        renderer.prepare(
            with: device,
            image: image,
            targetFrame: targetFrame.integral,
            fractureCount: fractureCount,
            onFirstFrameRendered: onFirstFrameRendered,
            onComplete: { [weak self] in
                guard let self else { return }
                pauseMetalView()
                onComplete()
            }
        )
        metalView.draw()
    }

    private func pauseMetalView() { metalView.isPaused = true }
}
