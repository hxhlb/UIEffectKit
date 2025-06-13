//
//  ContentView.swift
//  UIEffectKitExample
//
//  Created by 秋星桥 on 6/13/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            Form {
                ExampleEntry(title: "Explode Transition", icon: "sparkles") {
                    SimpleController<ParticleTransitionController>()
                }

                ExampleEntry(title: "Break Glass Transition", icon: "hammer.fill") {
                    SimpleController<BreakGlassTransitionController>()
                }

                ExampleEntry(title: "Shimmer Grid Points", icon: "star.square.fill") {
                    ShimmerGridPointsPanel()
                }
            }
            .navigationTitle("UIEffectKit")
        }
    }
}
