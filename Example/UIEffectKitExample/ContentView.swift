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

#if canImport(UIKit)
    import UIKit

    struct SimpleController<T: UIViewController>: UIViewControllerRepresentable {
        typealias UIViewControllerType = T

        func makeUIViewController(context _: Context) -> T {
            .init()
        }

        func updateUIViewController(_: T, context _: Context) {}
    }

#elseif canImport(AppKit)
    import AppKit

    struct SimpleController<T: NSViewController>: NSViewControllerRepresentable {
        typealias NSViewControllerType = T

        func makeNSViewController(context _: Context) -> T {
            .init()
        }

        func updateNSViewController(_: T, context _: Context) {}
    }
#endif
