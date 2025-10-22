//
//  TextPreview.swift
//  Orbit
//
//  Created by Кирилл Исаев on 22.10.2025.
//

import SwiftUI

struct TextPreview: View {
    let string: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView {
                Text(string)
                    .font(.system(size: 15))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 240)
        }
    }
}
