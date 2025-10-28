//
//  FilterMenu.swift
//  Orbit
//
//  Created by Кирилл Исаев on 27.10.2025.
//

import SwiftUI

struct FilterMenu: View {
    @Binding var selection: Filter
    @State private var isOpen = false
    @State private var search = ""

    let options: [Filter] = [.all, .text, .images, .files]

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isOpen.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selection.icon)
                Text(selection.title)
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isOpen)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 3, y: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isOpen, attachmentAnchor: .point(.bottomLeading), arrowEdge: .bottom) {
            FilterListView(
                selection: $selection,
                search: $search,
                options: options
            ) {
                isOpen = false
            }
        }
    }
}

