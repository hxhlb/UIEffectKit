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
            ScrollView {
                VStack(alignment: .leading) {
                    ExampleEntry(title: "Particle Transition", icon: "wind") {
                        SimpleController<ParticleTransitionController>()
                    }

                    ExampleEntry(title: "Break Glass Transition", icon: "hammer.fill") {
                        SimpleController<BreakGlassTransitionController>()
                    }

                    ExampleEntry(title: "Shimmer Background", icon: "sparkles") {
                        SimpleController<ShimmeringBackgroundController>()
                    }

                    ExampleEntry(title: "Shimmer Grid Points", icon: "star.square.fill") {
                        SimpleController<ShimmerGridPointsController>()
                    }

                    Divider().hidden()
                }
                .padding()
            }
            .navigationTitle("UIEffectKit")
        }
    }
}
