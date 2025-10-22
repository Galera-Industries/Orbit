//
//  ImagePreview.swift
//  Orbit
//
//  Created by Кирилл Исаев on 22.10.2025.
//

import SwiftUI

struct ImagePreview: View {
    let image: NSImage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Image")
                .font(.caption)
                .foregroundColor(.secondary)

            GeometryReader { geo in
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                    .cornerRadius(8)
            }
            .frame(height: 220)
        }
    }
}
