//
//  KeyView.swift
//  Orbit
//
//  Created by Кирилл Исаев on 28.10.2025.
//

import SwiftUI

struct Key: View {
    let key: String
    var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white.opacity(0.08))
            )
    }
}
