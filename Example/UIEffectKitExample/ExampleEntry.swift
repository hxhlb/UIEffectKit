//
//  ExampleEntry.swift
//  UIEffectKitExample
//
//  Created by qaq on 22/10/2025.
//

import SwiftUI

struct ExampleEntry<D: View>: View {
    let title: LocalizedStringKey
    let icon: String

    @ViewBuilder
    let destination: () -> D

    var body: some View {
        NavigationLink {
            destination()
                .navigationTitle(title)
        } label: {
            AlignedLabel(title, systemImage: icon)
        }
    }
}
