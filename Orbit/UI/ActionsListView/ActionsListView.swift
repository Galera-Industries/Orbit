//
//  ActionsListView.swift
//  Orbit
//
//  Created by Кирилл Исаев on 28.10.2025.
//

import SwiftUI

struct ActionsListView: View {
    let actions: [Action]
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(actions, id: \.self) { action in
                        ActionRow(
                            action: action,
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                onSelect()
                            }
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: 280)
        }
        .frame(maxWidth: 300)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 8)
        .padding(8)
    }
}
