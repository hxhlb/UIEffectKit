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
                    NavigationLink {
                        SimpleController<ParticleTransitionController>()
                            .navigationTitle("ParticleTransition")
                    } label: {
                        Label("ParticleTransition", systemImage: "wind")
                    }

                    NavigationLink {
                        SimpleController<BreakGlassTransitionController>()
                            .navigationTitle("BreakGlassTransition")
                    } label: {
                        Label("BreakGlassTransition", systemImage: "hammer.fill")
                    }

                    Divider().hidden()
                }
                .padding()
            }
            // avoid problem on Mac
            .toolbar { Button("") {}.hidden() }
            .navigationTitle("UIEffectKit")
        }
    }
}
