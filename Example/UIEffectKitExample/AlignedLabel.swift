//
//  AlignedLabel.swift
//  UIEffectKitExample
//
//  Created by qaq on 22/10/2025.
//

import SwiftUI

struct AlignedLabel: View {
    let icon: String
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey, systemImage: String) {
        self.text = text
        icon = systemImage
    }

    var body: some View {
        HStack {
            Image(systemName: "circle")
                .font(.body)
                .hidden()
                .overlay {
                    Image(systemName: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            Text(text)
                .font(.body)
        }
    }
}
