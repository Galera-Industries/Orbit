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
        VStack(alignment: .leading, spacing: 12) {
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
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.05)))
        .animation(.easeInOut(duration: 0.2), value: item.id)
    }
}
