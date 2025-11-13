//
//  SweepTransitionPanel.swift
//  UIEffectKitExample
//

import SwiftUI
import UIEffectKit
import ColorfulX
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

struct SweepTransitionPanel: View {
    @State private var entryFraction: Double = 0.7
    @State private var leavingFraction: Double = 0.25
    @State private var featherFraction: Double = 0.08
    @State private var directionAngle: Double = 90
    @State private var shimmerHue: Double = 210

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                ColorfulView(color: .sunsetGlory)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                sweepPreview
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(8)
            }
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    slider("Entry", value: $entryFraction, range: 0 ... 1, step: 0.01)
                    slider("Leaving", value: $leavingFraction, range: 0 ... 1, step: 0.01)
                    slider("Feather", value: $featherFraction, range: 0 ... 0.3, step: 0.005)
                    slider("Direction (deg)", value: $directionAngle, range: 0 ... 360, step: 1)
                    slider("Shimmer Hue", value: $shimmerHue, range: 0 ... 360, step: 1)
                    Text("Tip: Keep entry ≥ leaving for a traveling reveal; animate them over time for sweeping transitions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    private var sweepPreview: some View {
        EffectKitViewRepresentable<SweepTransitionView>(make: {
            let view = SweepTransitionView(frame: .zero)
            view.layer.cornerRadius = 20
            view.layer.masksToBounds = true
            #if canImport(UIKit)
                view.contentView.layer.cornerRadius = 20
                view.contentView.clipsToBounds = true
            #elseif canImport(AppKit)
                view.contentView.wantsLayer = true
                view.contentView.layer?.cornerRadius = 20
                view.contentView.layer?.masksToBounds = true
            #endif
            Self.installShimmer(in: view)
            return view
        }, update: { view in
            var cfg = SweepTransitionView.Configuration()
            cfg.entryFraction = CGFloat(entryFraction)
            cfg.leavingFraction = CGFloat(leavingFraction)
            cfg.featherFraction = CGFloat(featherFraction)
            cfg.directionAngle = CGFloat(directionAngle)
            view.configuration = cfg
            if let shimmer = Self.findShimmer(in: view) {
                var shimmerConfig = shimmer.configuration
                let color = Color(hue: shimmerHue / 360, saturation: 0.12, brightness: 1.0)
                let rgb = Self.colorComponents(from: color)
                shimmerConfig.baseColor = .init(Float(rgb.r), Float(rgb.g), Float(rgb.b))
                shimmerConfig.waveAngle = Float(directionAngle)
                shimmerConfig.waveSpeed = 1.6
                shimmerConfig.waveStrength = 1.2
                shimmerConfig.enableEDR = false
                shimmer.configuration = shimmerConfig
            }
        })
        .frame(minWidth: 320, maxWidth: .infinity, minHeight: 320, maxHeight: 360)
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading) {
            Text("\(title): \(formatted(value.wrappedValue))")
            Slider(value: value, in: range, step: step)
        }
    }

    private func formatted(_ value: Double) -> String {
        if value >= 0 && value <= 1 {
            return String(format: "%.2f", value)
        } else {
            return String(format: "%.0f", value)
        }
    }

    private static func installShimmer(in sweep: SweepTransitionView) {
        guard findShimmer(in: sweep) == nil else { return }
        let shimmer = ShimmerGridPointsView(frame: .zero)
        shimmer.translatesAutoresizingMaskIntoConstraints = false
        #if canImport(UIKit)
            shimmer.backgroundColor = .clear
        #elseif canImport(AppKit)
            shimmer.wantsLayer = true
            shimmer.layer?.backgroundColor = NSColor.clear.cgColor
        #endif
        sweep.contentView.addSubview(shimmer)
        NSLayoutConstraint.activate([
            shimmer.leadingAnchor.constraint(equalTo: sweep.contentView.leadingAnchor),
            shimmer.trailingAnchor.constraint(equalTo: sweep.contentView.trailingAnchor),
            shimmer.topAnchor.constraint(equalTo: sweep.contentView.topAnchor),
            shimmer.bottomAnchor.constraint(equalTo: sweep.contentView.bottomAnchor),
        ])
        shimmer.configuration.enableWiggle = false
        shimmer.configuration.hoverRadius = 0
    }

    private static func findShimmer(in sweep: SweepTransitionView) -> ShimmerGridPointsView? {
        #if canImport(UIKit)
            return sweep.contentView.subviews.compactMap { $0 as? ShimmerGridPointsView }.first
        #elseif canImport(AppKit)
            return sweep.contentView.subviews.compactMap { $0 as? ShimmerGridPointsView }.first
        #endif
    }

    private static func colorComponents(from color: Color) -> (r: Double, g: Double, b: Double) {
        #if canImport(UIKit)
            let uiColor = UIColor(color)
            var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            return (Double(r), Double(g), Double(b))
        #elseif canImport(AppKit)
            let nsColor = NSColor(color)
            let converted = nsColor.usingColorSpace(.deviceRGB) ?? nsColor.usingColorSpace(.sRGB) ?? nsColor
            return (
                Double(converted.redComponent),
                Double(converted.greenComponent),
                Double(converted.blueComponent)
            )
        #else
            return (1, 1, 1)
        #endif
    }
}
