//
//  FilePreview.swift
//  Orbit
//
//  Created by Кирилл Исаев on 22.10.2025.
//

import SwiftUI

struct FilePreview: View {
    let url: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("File")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 48, height: 48)
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(url.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                    Text(url.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            Divider()

            if url.isImage {
                if let nsImage = NSImage(contentsOf: url) {
                    ImagePreview(image: nsImage)
                }
            } else if url.isText {
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    TextPreview(string: text)
                }
            } else {
                Text("No preview available for this file type.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding(.top, 8)
            }
        }
    }
}

private extension URL {
    var isImage: Bool { ["png", "jpg", "jpeg", "gif", "heic"].contains(pathExtension.lowercased()) }
    var isText: Bool { ["txt", "md", "json", "csv", "log"].contains(pathExtension.lowercased()) }
}
