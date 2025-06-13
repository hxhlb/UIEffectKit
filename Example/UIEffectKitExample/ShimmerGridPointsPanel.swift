//
//  ShimmerGridPointsPanel.swift
//  UIEffectKitExample
//

import SwiftUI
import UIEffectKit
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

import ColorfulX

struct ShimmerGridPointsPanel: View {
    @State private var spacing: Double = 32
    @State private var baseHue: Double = 220
    @State private var waveSpeed: Double = 1.1
    @State private var waveStrength: Double = 0.8
    @State private var blurMin: Double = 0.08
    @State private var blurMax: Double = 0.25
    @State private var intensityMin: Double = 0.6
    @State private var intensityMax: Double = 0.95
    @State private var radiusMin: Double = 4
    @State private var radiusMax: Double = 8
    @State private var shapeMode: Int = 0
    @State private var enableWiggle: Bool = false
    @State private var hoverRadius: Double = 96
    @State private var hoverBoost: Double = 0.6
    @State private var enableEDR: Bool = true
    @State private var edrGain: Double = 1.35

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                ColorfulView(
                    color: .appleIntelligence,
                    animationDirector: SpeckleAnimationRoundedRectangleDirector(
                        movementRate: 0.5,
                        positionResponseRate: 0.75
                    )
                )
                effectView
                    .allowsHitTesting(true)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    stepper("Spacing", value: $spacing, range: 8 ... 128, step: 4)
                    slider("Hue", value: $baseHue, range: 0 ... 360)
                    slider("Wave Speed", value: $waveSpeed, range: 0 ... 4)
                    slider("Wave Strength", value: $waveStrength, range: 0 ... 2)
                    range("Blur", min: $blurMin, max: $blurMax, bounds: 0 ... 0.8, step: 0.01)
                    range("Intensity", min: $intensityMin, max: $intensityMax, bounds: 0 ... 1, step: 0.01)
                    range("Radius", min: $radiusMin, max: $radiusMax, bounds: 2 ... 24, step: 0.5)
                    picker("Shape", selection: $shapeMode) {
                        Text("Mixed").tag(0)
                        Text("Circles").tag(1)
                        Text("Diamonds").tag(2)
                    }
                    Toggle("Wiggle", isOn: $enableWiggle)
                    slider("Hover Radius", value: $hoverRadius, range: 0 ... 240)
                    slider("Hover Boost", value: $hoverBoost, range: 0 ... 2)
                    Toggle("Extra Dynamic Range", isOn: $enableEDR)
                    if enableEDR {
                        slider("EDR 增益", value: $edrGain, range: 1.0 ... 2.0)
                    }
                }
            }
        }
        .padding()
    }

    private var effectView: some View {
        EffectKitViewRepresentable<ShimmerGridPointsView>(make: {
            let v = ShimmerGridPointsView(frame: .zero)
            return v
        }, update: { view in
            var cfg = ShimmerGridPointsView.Configuration()
            cfg.spacing = Float(spacing)
            let color = Color(hue: baseHue / 360.0, saturation: 0.06, brightness: 1.0)
            let rgb = Self.rgb(from: color)
            cfg.baseColor = .init(Float(rgb.r), Float(rgb.g), Float(rgb.b))
            cfg.waveSpeed = Float(waveSpeed)
            cfg.waveStrength = Float(waveStrength)
            // Normalize ranges to avoid invalid ClosedRange construction
            let bLo = min(blurMin, blurMax), bHi = max(blurMin, blurMax)
            let iLo = min(intensityMin, intensityMax), iHi = max(intensityMin, intensityMax)
            let rLo = min(radiusMin, radiusMax), rHi = max(radiusMin, radiusMax)
            cfg.blurRange = Float(bLo) ... Float(bHi)
            cfg.intensityRange = Float(iLo) ... Float(iHi)
            cfg.radiusRange = Float(rLo) ... Float(rHi)
            cfg.shapeMode = [ShimmerGridPointsView.Configuration.ShapeMode.mixed, .circles, .diamonds][min(max(shapeMode, 0), 2)]
            cfg.enableWiggle = enableWiggle
            cfg.hoverRadius = Float(hoverRadius)
            cfg.hoverBoost = Float(hoverBoost)
            cfg.enableEDR = enableEDR
            cfg.edrGain = Float(edrGain)
            view.configuration = cfg
            if let h = hoverSubject { view.setHover(pointInView: h) } else { view.setHover(pointInView: nil) }
        })
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { value in
                let point = CGPoint(x: value.location.x, y: value.location.y)
                hoverPoint = point
            }
            .onEnded { _ in hoverPoint = nil }
        )
        .background(HoverReporter { pt in hoverPoint = pt })
        .onChange(of: hoverPoint) { new in
            hoverSubject = new
        }
        .onAppear { hoverPoint = nil }
    }

    // Hover forwarding to the underlying view via preference key
    @State private var hoverPoint: CGPoint? = nil
    @State private var hoverSubject: CGPoint? = nil
}

// MARK: - Simple Controls

private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double = 0.01) -> some View {
    VStack(alignment: .leading) {
        Text("\(title): \(String(format: "%.2f", value.wrappedValue))")
        Slider(value: value, in: range, step: step)
    }
}

private func stepper(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double = 1) -> some View {
    VStack(alignment: .leading) {
        HStack {
            Text("\(title): \(Int(value.wrappedValue))")
            Spacer()
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
        }
    }
}

private func range(_ title: String, min: Binding<Double>, max: Binding<Double>, bounds: ClosedRange<Double>, step: Double = 0.01) -> some View {
    VStack(alignment: .leading) {
        Text(title)
        HStack {
            Slider(value: min, in: bounds, step: step)
            Slider(value: max, in: bounds, step: step)
        }
    }
}

private func picker(_ title: String, selection: Binding<some Hashable>, @ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading) {
        Text(title)
        Picker(title, selection: selection) { content() }
            .pickerStyle(.segmented)
    }
}

// MARK: - Hover reporting helper

private struct HoverReporter: View {
    var onHover: (CGPoint?) -> Void
    var body: some View {
        Rectangle().fill(Color.clear).contentShape(Rectangle())
            .onHover { inside in if !inside { onHover(nil) } }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in onHover(CGPoint(x: v.location.x, y: v.location.y)) }
                .onEnded { _ in onHover(nil) }
            )
    }
}

private extension ShimmerGridPointsPanel {
    static func rgb(from color: Color) -> (r: Double, g: Double, b: Double) {
        #if canImport(UIKit)
            let ui = UIColor(color)
            var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
            return (Double(r), Double(g), Double(b))
        #elseif canImport(AppKit)
            let ns = NSColor(color)
            let conv = ns.usingColorSpace(.deviceRGB) ?? ns.usingColorSpace(.sRGB) ?? ns
            return (Double(conv.redComponent), Double(conv.greenComponent), Double(conv.blueComponent))
        #else
            return (1, 1, 1)
        #endif
    }
}
