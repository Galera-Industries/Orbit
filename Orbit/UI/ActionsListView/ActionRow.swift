//
//  ActionsRow.swift
//  Orbit
//
//  Created by Кирилл Исаев on 28.10.2025.
//

import SwiftUI

struct ActionRow: View {
    @EnvironmentObject private var shell: ShellModel
    let action: Action
    let onSelect: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: {
            if action == .pin {
                if let item = shell.selectedItem, let copyItem = item.source as? ClipboardItem {
                    shell.pin(item: copyItem)
                }
            }
            if action == .unpin {
                if let item = shell.selectedItem, let copyItem = item.source as? ClipboardItem {
                    shell.unpin(item: copyItem)
                }
            }
            if action == .deleteThis {
                if let item = shell.selectedItem, let copyItem = item.source as? ClipboardItem {
                    shell.deleteItem(item: copyItem)
                }
            }
            if action == .deleteAll {
                shell.deleteAllFromClipboardHistory()
            }
            onSelect()
        }) {
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
                    case .unpin:
                        Key(key: "⌃")
                        Key(key: "⌥")
                        Key(key: "⇧")
                        Key(key: "P")
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
