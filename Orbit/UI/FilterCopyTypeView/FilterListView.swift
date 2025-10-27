//
//  FilterListView.swift
//  Orbit
//
//  Created by Кирилл Исаев on 27.10.2025.
//

import SwiftUI

struct FilterListView: View {
    @Binding var selection: Filter
    @Binding var search: String
    let options: [Filter]
    let onSelect: () -> Void
    
    private var filteredOptions: [Filter] {
        guard !search.isEmpty else { return options }
        return options.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredOptions, id: \.self) { item in
                        FilterRow(
                            filter: item,
                            isSelected: item == selection
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selection = item
                                onSelect()
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(minWidth: 260, maxHeight: 280)
        }
        .frame(maxWidth: 300)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 8)
        .padding(8)
    }
}
