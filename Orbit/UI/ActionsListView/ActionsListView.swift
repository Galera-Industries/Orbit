//
//  ActionsListView.swift
//  Orbit
//
//  Created by Кирилл Исаев on 28.10.2025.
//

import SwiftUI

struct ActionsListView: View {
    @EnvironmentObject private var shell: ShellModel
    let actions: [Action]
    let onSelect: () -> Void
    
    // это нужно на экране clipboard history, потому что там в зависимости от состояния выбранного копирования
    // могут быть разные actions.
    // Мой кейс: я запинил объект, теперь в Actions Menu не должно быть pin, здесь должно быть .unpin,
    // как я это редактирую видно ниже в методе
    // Если на твоем экране тоже есть такое поведение, то редактируй это здесь, а первоначальный actions
    // здавай на родительском View
    private func getNeededActions() -> [Action] {
        guard let item = shell.selectedItem else { return [] }
        if let clipboardItem = item.source as? ClipboardItem {
            return clipboardItem.pinned == nil ? actions : [.unpin, .deleteThis, .deleteAll]
        }
        return actions
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(getNeededActions(), id: \.self) { action in
                        ActionRow(
                            action: action
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                onSelect()
                            }
                        }
                    }
                }
                .frame(minWidth: 240)
                .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: 280)
        }
        .frame(minWidth: 250, maxWidth: 300)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 8)
        .padding(8)
    }
}
