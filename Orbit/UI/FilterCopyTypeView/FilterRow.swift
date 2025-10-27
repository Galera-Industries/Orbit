//
//  FilterRow.swift
//  Orbit
//
//  Created by Кирилл Исаев on 27.10.2025.
//

import SwiftUI

struct FilterRow: View {
    let filter: Filter
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: filter.icon)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Text(filter.title)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}
