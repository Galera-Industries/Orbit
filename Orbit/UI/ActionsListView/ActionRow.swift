//
//  ActionsRow.swift
//  Orbit
//
//  Created by Кирилл Исаев on 28.10.2025.
//

import SwiftUI

struct ActionRow: View {
    let action: Action
    let onSelect: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: action.icon)
                    .foregroundStyle(action == .deleteAll || action == .deleteThis ? .red : .primary)
                Text(action.title)
                    .foregroundStyle(action == .deleteAll || action == .deleteThis ? .red : .primary)
                Spacer()
                
                HStack(spacing: 4) {
                    switch action {
                    case .copyToClipboard:
                        Key(key: "⌘")
                        Key(key: "⏎")
                    case .pin:
                        Key(key: "⌃")
                        Key(key: "⇧")
                        Key(key: "P")
                    case .deleteThis:
                        Key(key: "⌃")
                        Key(key: "X")
                    case .deleteAll:
                        Key(key: "⌃")
                        Key(key: "⇧")
                        Key(key: "X")
                    }
                    
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovering ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
