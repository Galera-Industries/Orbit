//
//  ResultRow.swift
//  Orbit
//
//  Created by Tom Tim on 20.10.2025.
//

import UniformTypeIdentifiers
import AppKit
import SwiftUI

struct ResultRow: View {
    let item: ResultItem
    let isSelected: Bool
    
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
    }
    
    private var rowContent: some View {
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
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(borderColor, lineWidth: 2)
        )
    }
    
    @ViewBuilder
    private func draggableIfClipboard() -> some View {
        if let clip = item.source as? ClipboardItem {
            switch clip.type {
            case .text:
                self.rowContent.draggable(String(data: clip.content, encoding: .utf8) ?? "")
            case .image:
                self.rowContent.draggable(imageFile(clip))
            case .fileURL:
                self.rowContent.draggable(existingFileURL(clip))
            }
        } else {
            self.rowContent
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

