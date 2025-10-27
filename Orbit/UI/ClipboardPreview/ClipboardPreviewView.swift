//
//  ClipboardPreviewView.swift
//  Orbit
//
//  Created by Кирилл Исаев on 22.10.2025.
//

import SwiftUI

struct ClipboardPreviewView: View {
    let item: ClipboardItem

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                previewContent
                Divider()
                informationContent
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.05)))
            .animation(.easeInOut(duration: 0.2), value: item.id)
        }
        .scrollIndicators(.automatic)
    }
    
    @ViewBuilder
    var previewContent: some View {
        switch item.type {
        case .text:
            TextPreview(string: item.displayText)
        case .image:
            ImagePreview(image: NSImage(data: item.content) ?? NSImage(size: CGSize(width: 100, height: 100)))
        case .fileURL:
            if let paths = try? JSONDecoder().decode([String].self, from: item.content), !paths.isEmpty {
                let urls = paths.map { URL(fileURLWithPath: $0) }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(urls.enumerated()), id: \.element) { index, url in
                            VStack(alignment: .leading, spacing: 8) {
                                FilePreview(url: url)
                            }
                            if index != urls.count - 1 {
                                Divider()
                                    .opacity(0.3)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        Spacer(minLength: 0)
    }
    
    @ViewBuilder
    var informationContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Information")
                .font(.headline)
                .padding(.bottom, 4)
            
            infoRow(label: "Source", value: "Safari")
            Divider().padding(.vertical, -5)
            infoRow(label: "Content type", value: item.type.rawValue.capitalized)
            Divider().padding(.vertical, -5)
            infoRow(label: "Dimensions", value: "350×151")
            Divider().padding(.vertical, -5)
            infoRow(label: "Image size", value: "54 KB")
            Divider().padding(.vertical, -5)
            infoRow(label: "Created", value: "Today, 14:45")
            
            Spacer(minLength: 40)
        }
        .font(.system(size: 14))
        .padding(.horizontal, 16)
    }
    
    func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            Spacer()
            Text(value)
        }
    }
}
