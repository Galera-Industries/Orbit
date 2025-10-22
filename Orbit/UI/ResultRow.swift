//
//  ResultRow.swift
//  Orbit
//
//  Created by Tom Tim on 20.10.2025.
//

import SwiftUI

struct ResultRow: View {
    let item: ResultItem
    let isSelected: Bool
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                        .lineLimit(1)
                }
            }
            Spacer()
            if let accessory = item.accessory {
                Text(accessory)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.22) : .clear)
        )
    }
}
