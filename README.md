UIEffectKit
===========

Unified, ergonomic UI effects with Metal and SwiftUI bridges.

What’s inside
- MetalHostView: A reusable base view that owns an `MTKView` and centralizes Metal setup, layout, device, and scale handling.
- ExtendingArea: Simple API to render beyond bounds for effects like glass shards or particle trails.
- Helpers: Blended pipeline + sampler helpers, platform snapshot shortcuts.
- Effects: Break Glass Transition, Particle Explode, Shimmer Grid Points.
- SwiftUI: Declarative embedding via `EffectContainer`, and removal transitions/modifiers.

Key Types
- `MetalHostView` (Sources/UIEffectKitBase/MetalHostView.swift):
  - `extendingArea: ExtendingArea` controls drawing region.
  - `setDelegate(_:)`, `setPaused(_:)`, `setFramebufferOnly(_:)`, `setClearColor(_:)`.
  - Auto-scales `drawableSize` from window scale and adjusts layout on resize.
- `ExtendingArea` (in base):
  - `.none`: default, draws within bounds
  - `.multiple(by: CGFloat)`: expand by a multiple of the bounds
  - `.extending(pt: CGFloat)`: expand with a fixed padding in points
- `EffectHostConfig` (Sources/UIEffectKitBase/EffectHostConfig.swift):
  - Value-type container for host setup (extending area, FPS, framebufferOnly, clear color)
  - `MetalHostView.apply(config:)` to configure in one call
- `MetalHelpers` (Sources/UIEffectKitBase/MetalHelpers.swift):
  - `blendedPipelineDescriptor(...)`, `makeLinearClampSampler(...)`
- Snapshot Helpers (Sources/UIEffectKitBase/PlatformView.swift):
  - `UIView.makeSnapshotCGImage()` and `NSView.makeSnapshotCGImage()`

SwiftUI Integration
- `EffectContainer<V: EffectKitView>`: Declarative wrapper for any `EffectKitView` subclass.
  - Example:
    EffectContainer(make: { ShimmerGridPointsView(frame: .zero) }) { view in
        var cfg = ShimmerGridPointsView.Configuration()
        cfg.spacing = 32
        view.configuration = cfg
    }
- Removal transitions and modifiers (Sources/UIEffectKit/SwiftUIEffects.swift):
  - `.breakGlassOnDisappear(fractureCount:)`
  - `.explodeOnDisappear()`
  - `.transition(.breakGlassTransition)`
  - `.transition(.explodeTransition)`

UIKit / AppKit Utilities
- Break Glass Transition: `BreakGlassTransition.perform(on:fractureCount:onFirstFrame:completion:)`
- Particle Explode: `UIView.removeFromSuperviewWithExplodeEffect()` and `NSView.removeFromSuperviewWithExplodeEffect()`

Examples
- Example/UIEffectKitExample shows:
  - UIKit controllers for Break Glass and Particle Explode
  - SwiftUI demos using `.transition(.breakGlassTransition)` and `.transition(.explodeTransition)`
  - Shimmer grid effect embedded via `EffectContainer`

Notes and Style
- Follows Swift Code Style in AGENTS.md: 4-space indent, early returns, value types for configuration.
- Avoids protocol-oriented overuse; favors composition + helpers.
- Debug uses `assert()` for invariants; runtime failures call `fatalError` where setup is impossible.

