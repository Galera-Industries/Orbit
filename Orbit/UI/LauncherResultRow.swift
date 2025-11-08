//
//  LauncherResultRow.swift
//  Orbit
//
//  Created by Tom Tim on 08.11.2025.
//

import SwiftUI
import AppKit

struct LauncherResultRow: View {
    let item: ResultItem
    let isSelected: Bool
    
    @State private var icon: NSImage? = nil
    @State private var isLoadingIcon = false
    
    private var isPinned: Bool {
        (item.source as? ClipboardItem)?.pinned != nil
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.22)
        } else if isPinned {
            return Color.accentColor.opacity(0.08)
        } else {
            return .clear
        }
    }
    
    private var borderColor: Color {
        isPinned ? Color.accentColor.opacity(0.5) : .clear
    }
    
    var body: some View {
        draggableIfClipboard()
            .onAppear { loadIconIfNeeded() }
    }
    
    private var rowContent: some View {
        HStack(alignment: .center, spacing: 12) {
            if shouldShowIconArea {
                iconView
                    .frame(width: 36, height: 36)
            }
            
            // MAIN TEXT
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
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(borderColor, lineWidth: 2)
        )
    }
    
    private var shouldShowIconArea: Bool {
        // Show icon area for URLs (apps/files) and for the web search item.
        if item.source is URL { return true }
        if item.subtitle == "Search in default browser" { return true } // web search
        return false // base commands and clipboard placeholders -> no icon area
    }
    
    @ViewBuilder
    private var iconView: some View {
        if let nsimg = icon {
            Image(nsImage: nsimg)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if item.subtitle == "Search in default browser" {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .frame(width: 20, height: 20)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 36, height: 36)
                if isLoadingIcon {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: "doc")
                }
            }
        }
    }
    
    @ViewBuilder
    private func draggableIfClipboard() -> some View {
        if let clip = item.source as? ClipboardItem {
            switch clip.type {
            case .text:
                rowContent.draggable(String(data: clip.content, encoding: .utf8) ?? "")
            case .image:
                rowContent.draggable(imageFile(clip))
            case .fileURL:
                rowContent.draggable(existingFileURL(clip))
            }
        } else {
            rowContent
        }
    }
    
    private func loadIconIfNeeded() {
        guard icon == nil, !isLoadingIcon else { return }
        guard let url = item.source as? URL else { return }
        
        isLoadingIcon = true
        AppIconProvider.shared.loadIcon(forPath: url.path) { loaded in
            self.icon = loaded
            self.isLoadingIcon = false
        }
    }
    
    private func imageFile(_ clip: ClipboardItem) -> FileURLPayload {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("orbit-\(clip.id.uuidString).png")
        if let img = NSImage(data: clip.content),
           let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
        } else {
            try? clip.content.write(to: url)
        }
        return FileURLPayload(url: url)
    }
    
    private func existingFileURL(_ clip: ClipboardItem) -> FileURLPayload {
        let paths = (try? JSONDecoder().decode([String].self, from: clip.content)) ?? []
        let file = paths.first.map { URL(fileURLWithPath: $0) } ?? FileManager.default.temporaryDirectory
        return FileURLPayload(url: file)
    }
}
