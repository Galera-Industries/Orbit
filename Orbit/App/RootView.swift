//
//  RootView.swift
//  Orbit
//
//  Created by Tom Tim on 20.10.2025.
//

import SwiftUI
import AppKit
internal import os

struct RootView: View {
    @EnvironmentObject var shell: ShellModel
    @EnvironmentObject var windowManager: WindowManager
    @FocusState private var isSearchFocused: Bool
    @State private var keyMonitor: KeyEventMonitor?
    @State private var selectedFilter: Filter = .all // текущий фильтр в clipboard history
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
            GlassPanel {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        TextField("Type to search…", text: $shell.query, onCommit: {
                            shell.executeSelected()
                        })
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .medium))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.08)))
                        .focused($isSearchFocused)
                        
                        if shell.currentMode == .clipboard {
                            FilterMenu(selection: $selectedFilter)
                                .onChange(of: selectedFilter) { newFilter in
                                    shell.switchFilter(filter: newFilter)
                                }
                        }
                    }
                    .onChange(of: shell.query) { newQ in
                        L.search.info("query changed -> '\(newQ, privacy: .public)'")
                        
                        shell.resetSelection()
                        shell.performSearch()
                    }
                    
                    PreviewHStack()
                    
                    Spacer(minLength: 40)
                }
                .padding(16)
                .frame(minWidth: 720, minHeight: 420)
            }
            BottomPanel()
        }
        .onAppear {
            isSearchFocused = true
            keyMonitor = KeyEventMonitor { event in
                switch event.keyCode {
                case 126: shell.moveSelection(-1); return nil
                case 125: shell.moveSelection(1); return nil
                case 36, 76:
                    let alt = event.modifierFlags.contains(.shift)
                    shell.executeSelected(alternative: alt); return nil
                case 53: shell.handleEscape(); return nil
                default: return event
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearchField)) { _ in
            L.window.info("focusSearchField notification")
            isSearchFocused = true
        }
        .onDisappear { keyMonitor = nil }
    }
}

struct PreviewHStack: View {
    @EnvironmentObject var shell: ShellModel
    var body: some View {
        HStack {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(shell.filteredItems.enumerated()), id: \.element.id) { index, item in
                        ResultRow(item: item, isSelected: index == shell.selectedIndex)
                            .onHover { hovering in if hovering { shell.selectedIndex = index } }
                            .onTapGesture { shell.selectedIndex = index; shell.executeSelected() }
                    }
                }
                .padding(6)
            }
            .scrollIndicators(.never)
            .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.06)))
            .frame(width: 320)
            
            if let selectedItem = shell.selectedItem,
               let clipItem = selectedItem.source as? ClipboardItem { // превью для Clipboard, для остальных можно свое делать
                ClipboardPreviewView(item: clipItem)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                VStack {
                    Text("No item selected")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct BottomPanel: View {
    @EnvironmentObject private var shell: ShellModel
    @State private var hoverOnActions = false
    @State private var isOpen = false
    
    private func getActions() -> [Action] {
        switch shell.currentMode {
        case .launcher:
            return [] // что душе угодно
        case .clipboard:
            return [.copyToClipboard, .pin, .deleteThis, .deleteAll]
        case .tasks:
            return [] // что душе угодно
        case .pomodoro:
            return [] // что душе угодно
        }
    }
    
    var body: some View {
        HStack {
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isOpen.toggle()
                }
            }) {
                ButtonLabel(hoverOnActions: $hoverOnActions)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isOpen, attachmentAnchor: .point(.topLeading), arrowEdge: .top) {
                ActionsListView(actions: getActions()) {
                    isOpen = false
                }
                .frame(maxWidth: 260, maxHeight: 200)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.08))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .padding(.bottom, 0)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.25), value: hoverOnActions)
    }
}

struct ButtonLabel: View {
    @Binding var hoverOnActions: Bool
    var body: some View {
        HStack(spacing: 4) {
            Key(key: "⌘")
            Key(key: "K")
            Text("Actions")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.06))
        )
        .onHover { inside in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoverOnActions = inside
            }
        }
        .opacity(hoverOnActions ? 0.95 : 0.8)
        .scaleEffect(hoverOnActions ? 1.02 : 1.0)
    }
}

extension ShellModel {
    var selectedItem: ResultItem? {
        guard selectedIndex >= 0 && selectedIndex < filteredItems.count else { return nil }
        return filteredItems[selectedIndex]
    }
}
