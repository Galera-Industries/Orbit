//
//  ResponsePanelView.swift
//  Orbit
//
//  Created by Auto on 2025.
//

import SwiftUI
import Combine
import AppKit // Не забудьте импортировать AppKit для работы с NSWindow
import WebKit

struct ResponsePanelView: View {
    @State private var chatgptResponse: String? = nil
    @State private var deepseekResponse: String? = nil
    @State private var timer: Timer?
    @State private var chatGPTProviderLabel: String = "got_proxy"
    @State private var chatGPTModelLabel: String = "По умолчанию сервера"
    
    // Настройки из UserDefaults
    @State private var layoutMode: String = UserDefaults.standard.string(forKey: "responsePanelLayoutMode") ?? "horizontal"
    @AppStorage("responsePanelBackgroundType") private var backgroundType: String = "colored"
    @AppStorage("responsePanelTransparentMode") private var transparentMode: Bool = false
    @AppStorage("responsePanelTextSize") private var textSize: Double = 12
    
    var body: some View {
        Group {
            if layoutMode == "horizontal" {
                VStack(spacing: 0) {
                    responseContent
                }
            } else {
                HStack(spacing: 0) {
                    responseContent
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if transparentMode {
                Color.clear
            } else {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow, state: .active)
            }
        }
        .onAppear {
            loadResponses()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                loadResponses()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .responsePanelToggleLayout)) { _ in
            toggleLayoutMode()
        }
        .onReceive(NotificationCenter.default.publisher(for: .responsePanelToggleBackground)) { _ in
            toggleBackground()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .responsePanelTextSizeDidChange)) { _ in
            // Принудительно читаем из UserDefaults для мгновенного обновления web-контента.
            textSize = UserDefaults.standard.double(forKey: "responsePanelTextSize")
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if abs(value.translation.width) > abs(value.translation.height) {
                        if value.translation.width > 30 {
                            layoutMode = "horizontal"
                            UserDefaults.standard.set("horizontal", forKey: "responsePanelLayoutMode")
                        } else if value.translation.width < -30 {
                            layoutMode = "vertical"
                            UserDefaults.standard.set("vertical", forKey: "responsePanelLayoutMode")
                        }
                    }
                }
        )
    }
    
    @ViewBuilder
    private var responseContent: some View {
        if let chatgpt = chatgptResponse, !chatgpt.isEmpty {
            responseCard(
                title: "ChatGPT",
                subtitle: "\(chatGPTProviderLabel) • \(chatGPTModelLabel)",
                content: chatgpt,
                backgroundColor: Color(red: 0.2, green: 0.9, blue: 0.2),
                textColor: (transparentMode || backgroundType != "colored") ? .primary : .black,
                markdownTextColor: (transparentMode || backgroundType != "colored") ? .labelColor : .black
            )
        }
        
        if let deepseek = deepseekResponse, !deepseek.isEmpty {
            responseCard(
                title: "DeepSeek",
                subtitle: "deepseek-chat",
                content: deepseek,
                backgroundColor: .blue,
                textColor: (transparentMode || backgroundType != "colored") ? .primary : .white,
                markdownTextColor: (transparentMode || backgroundType != "colored") ? .labelColor : .white
            )
        }
        
        if chatgptResponse == nil && deepseekResponse == nil {
            Text("Ожидание ответов...")
                .font(.system(size: max(9, textSize - 2)))
                .foregroundColor(.secondary)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private func responseCard(
        title: String,
        subtitle: String? = nil,
        content: String,
        backgroundColor: Color,
        textColor: Color,
        markdownTextColor: NSColor
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: max(8, textSize - 3), weight: .semibold))
                    .foregroundColor(textColor.opacity(0.9))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: max(7, textSize - 4), weight: .regular))
                        .foregroundColor(textColor.opacity(0.75))
                }
            }
            
            MarkdownWebView(content: content, textColor: markdownTextColor, baseFontSize: CGFloat(textSize))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
            maxWidth: layoutMode == "horizontal" ? .infinity : nil,
            maxHeight: layoutMode == "vertical" ? .infinity : nil,
            alignment: .topLeading
        )
        .padding(6)
        .background(
            Group {
                if transparentMode {
                    Color.clear
                } else if backgroundType == "colored" {
                    backgroundColor
                } else {
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow, state: .active)
                }
            }
        )
    }
    
    private func loadResponses() {
        let defaults = UserDefaults.standard
        let chatgptResponses = defaults.stringArray(forKey: "chatgptResponses") ?? []
        let deepseekResponses = defaults.stringArray(forKey: "deepseekResponses") ?? []
        let provider = defaults.string(forKey: "chatGPTProvider")?.lowercased() ?? "proxy"
        let rawModel = defaults.string(forKey: "chatGPTModel")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        chatgptResponse = chatgptResponses.isEmpty ? nil : chatgptResponses.first
        deepseekResponse = deepseekResponses.isEmpty ? nil : deepseekResponses.first
        
        chatGPTProviderLabel = provider == "eliza" ? "Eliza" : "got_proxy"
        if rawModel.isEmpty || rawModel == "server-default" {
            chatGPTModelLabel = provider == "eliza" ? "gpt-5.5" : "По умолчанию сервера"
        } else {
            chatGPTModelLabel = rawModel
        }
        
        let savedLayoutMode = defaults.string(forKey: "responsePanelLayoutMode") ?? "horizontal"
        if savedLayoutMode != layoutMode {
            layoutMode = savedLayoutMode
        }
    }
    
    private func toggleLayoutMode() {
        layoutMode = layoutMode == "horizontal" ? "vertical" : "horizontal"
        UserDefaults.standard.set(layoutMode, forKey: "responsePanelLayoutMode")
    }
    
    private func toggleBackground() {
        transparentMode.toggle()
        UserDefaults.standard.set(transparentMode, forKey: "responsePanelTransparentMode")
    }
}

private struct MarkdownWebView: NSViewRepresentable {
    let content: String
    let textColor: NSColor
    let baseFontSize: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let html = Self.htmlDocument(for: content, textColor: textColor, baseFontSize: baseFontSize)
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        nsView.loadHTMLString(html, baseURL: nil)
    }

    private static func htmlDocument(for markdown: String, textColor: NSColor, baseFontSize: CGFloat) -> String {
        let colorHex = colorHexString(textColor)
        let normalizedFont = max(9, min(24, baseFontSize))
        let heading1 = normalizedFont + 5
        let heading2 = normalizedFont + 3
        let heading3 = normalizedFont + 2
        let codeFont = max(10, normalizedFont - 1)
        let markdownHTML = markdownToHTML(markdown)
        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <script>
            window.MathJax = {
              tex: {
                inlineMath: [['$', '$'], ['\\\\(', '\\\\)']],
                displayMath: [['$$', '$$'], ['\\\\[', '\\\\]']],
                processEscapes: true
              },
              options: {
                skipHtmlTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code']
              }
            };
          </script>
          <script defer src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js"></script>
          <style>
            :root { color-scheme: light dark; }
            body {
              margin: 0;
              padding: 2px 0 0 0;
              font: \(normalizedFont)px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
              color: \(colorHex);
              line-height: 1.4;
              background: transparent;
              word-break: break-word;
            }
            p { margin: 0 0 8px 0; }
            h1,h2,h3,h4,h5,h6 { margin: 0 0 8px 0; line-height: 1.25; }
            h1 { font-size: \(heading1)px; } h2 { font-size: \(heading2)px; } h3 { font-size: \(heading3)px; }
            ul,ol { margin: 0 0 8px 18px; padding: 0; }
            li { margin: 0 0 4px 0; }
            blockquote {
              margin: 0 0 8px 0;
              padding: 0 0 0 10px;
              border-left: 3px solid rgba(128,128,128,0.5);
              opacity: 0.95;
            }
            pre {
              margin: 0 0 8px 0;
              padding: 8px;
              border-radius: 6px;
              background: rgba(0,0,0,0.15);
              overflow-x: auto;
            }
            .table-wrap {
              margin: 0 0 8px 0;
              overflow-x: auto;
            }
            table {
              border-collapse: collapse;
              width: max-content;
              min-width: 100%;
            }
            th, td {
              border: 1px solid rgba(128,128,128,0.35);
              padding: 6px 8px;
              text-align: left;
              vertical-align: top;
            }
            th {
              font-weight: 600;
              background: rgba(128,128,128,0.18);
            }
            code {
              font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, monospace;
              font-size: \(codeFont)px;
            }
            p code, li code, blockquote code {
              padding: 1px 4px;
              border-radius: 4px;
              background: rgba(0,0,0,0.12);
            }
            .MathJax {
              font-size: 1em !important;
            }
            mjx-container[jax="CHTML"][display="true"] {
              margin: 0.4em 0 !important;
              overflow-x: auto;
              overflow-y: hidden;
            }
            a { color: #0A84FF; text-decoration: underline; }
          </style>
        </head>
        <body>\(markdownHTML)</body>
        </html>
        """
    }

    private static func markdownToHTML(_ markdown: String) -> String {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var html: [String] = []
        var paragraphLines: [String] = []
        var quoteLines: [String] = []
        var listItems: [String] = []
        var listKind: String? = nil
        var codeLines: [String] = []
        var inCodeBlock = false
        var codeLanguage = ""

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            html.append("<p>\(inlineToHTML(paragraphLines.joined(separator: " ")))</p>")
            paragraphLines.removeAll()
        }

        func flushQuote() {
            guard !quoteLines.isEmpty else { return }
            html.append("<blockquote>\(inlineToHTML(quoteLines.joined(separator: " ")))</blockquote>")
            quoteLines.removeAll()
        }

        func flushList() {
            guard let kind = listKind, !listItems.isEmpty else { return }
            let items = listItems.map { "<li>\(inlineToHTML($0))</li>" }.joined()
            html.append("<\(kind)>\(items)</\(kind)>")
            listItems.removeAll()
            listKind = nil
        }

        func flushCode() {
            guard !codeLines.isEmpty else { return }
            let langClass = codeLanguage.isEmpty ? "" : " class=\"language-\(escapeHTML(codeLanguage))\""
            html.append("<pre><code\(langClass)>\(escapeHTML(codeLines.joined(separator: "\n")))</code></pre>")
            codeLines.removeAll()
            codeLanguage = ""
        }

        var index = 0
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if inCodeBlock {
                if trimmed.hasPrefix("```") {
                    inCodeBlock = false
                    flushCode()
                } else {
                    codeLines.append(line)
                }
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                flushParagraph()
                flushQuote()
                flushList()
                inCodeBlock = true
                codeLanguage = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                index += 1
                continue
            }

            if
                let headerCells = parseTableRow(trimmed),
                index + 1 < lines.count,
                let alignments = parseTableSeparatorRow(lines[index + 1].trimmingCharacters(in: .whitespaces)),
                alignments.count == headerCells.count
            {
                flushParagraph()
                flushQuote()
                flushList()

                var bodyRows: [[String]] = []
                var bodyIndex = index + 2
                while bodyIndex < lines.count {
                    let rowLine = lines[bodyIndex].trimmingCharacters(in: .whitespaces)
                    guard let rowCells = parseTableRow(rowLine), rowCells.count == headerCells.count else {
                        break
                    }
                    bodyRows.append(rowCells)
                    bodyIndex += 1
                }

                html.append(tableHTML(header: headerCells, alignments: alignments, bodyRows: bodyRows))
                index = bodyIndex
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                flushQuote()
                flushList()
                index += 1
                continue
            }

            if let heading = parseHeading(trimmed) {
                flushParagraph()
                flushQuote()
                flushList()
                html.append("<h\(heading.level)>\(inlineToHTML(heading.text))</h\(heading.level)>")
                index += 1
                continue
            }

            if let quote = parseQuote(trimmed) {
                flushParagraph()
                flushList()
                quoteLines.append(quote)
                index += 1
                continue
            }

            if let listItem = parseUnorderedListItem(trimmed) {
                flushParagraph()
                flushQuote()
                if listKind != "ul" {
                    flushList()
                    listKind = "ul"
                }
                listItems.append(listItem)
                index += 1
                continue
            }

            if let listItem = parseOrderedListItem(trimmed) {
                flushParagraph()
                flushQuote()
                if listKind != "ol" {
                    flushList()
                    listKind = "ol"
                }
                listItems.append(listItem)
                index += 1
                continue
            }

            flushQuote()
            flushList()
            paragraphLines.append(trimmed)
            index += 1
        }

        if inCodeBlock {
            flushCode()
        }
        flushParagraph()
        flushQuote()
        flushList()

        return html.joined(separator: "\n")
    }

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        var count = 0
        for char in line {
            if char == "#" { count += 1 } else { break }
        }
        guard count > 0 && count <= 6 else { return nil }
        let rest = line.dropFirst(count).trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty else { return nil }
        return (count, String(rest))
    }

    private static func parseQuote(_ line: String) -> String? {
        guard line.hasPrefix(">") else { return nil }
        return String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    private static func parseUnorderedListItem(_ line: String) -> String? {
        guard line.hasPrefix("- ") || line.hasPrefix("* ") else { return nil }
        return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }

    private static func parseOrderedListItem(_ line: String) -> String? {
        let pattern = #"^\d+\.\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard
            let match = regex.firstMatch(in: line, options: [], range: range),
            let textRange = Range(match.range(at: 1), in: line)
        else {
            return nil
        }
        return String(line[textRange]).trimmingCharacters(in: .whitespaces)
    }

    private static func parseTableRow(_ line: String) -> [String]? {
        guard line.contains("|") else { return nil }
        var normalized = line.trimmingCharacters(in: .whitespaces)
        if normalized.hasPrefix("|") {
            normalized.removeFirst()
        }
        if normalized.hasSuffix("|") {
            normalized.removeLast()
        }
        let cells = normalized
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
        guard cells.count >= 2 else { return nil }
        return cells
    }

    private static func parseTableSeparatorRow(_ line: String) -> [String]? {
        guard let cells = parseTableRow(line) else { return nil }
        var alignments: [String] = []

        for cell in cells {
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }

            let hasLeftColon = trimmed.hasPrefix(":")
            let hasRightColon = trimmed.hasSuffix(":")
            let dashes = trimmed.replacingOccurrences(of: ":", with: "")
            guard dashes.count >= 3, dashes.allSatisfy({ $0 == "-" }) else { return nil }

            if hasLeftColon && hasRightColon {
                alignments.append("center")
            } else if hasRightColon {
                alignments.append("right")
            } else if hasLeftColon {
                alignments.append("left")
            } else {
                alignments.append("left")
            }
        }

        return alignments
    }

    private static func tableHTML(header: [String], alignments: [String], bodyRows: [[String]]) -> String {
        let headerCells = zip(header, alignments).map { cell, alignment in
            "<th style=\"text-align:\(alignment)\">\(inlineToHTML(cell))</th>"
        }.joined()

        let body = bodyRows.map { row in
            let cells = zip(row, alignments).map { cell, alignment in
                "<td style=\"text-align:\(alignment)\">\(inlineToHTML(cell))</td>"
            }.joined()
            return "<tr>\(cells)</tr>"
        }.joined()

        return "<div class=\"table-wrap\"><table><thead><tr>\(headerCells)</tr></thead><tbody>\(body)</tbody></table></div>"
    }

    private static func inlineToHTML(_ markdownText: String) -> String {
        var text = escapeHTML(markdownText)

        text = replacing(
            pattern: #"\[([^\]]+)\]\(([^)\s]+)\)"#,
            in: text
        ) { match in
            let label = match[1]
            let url = match[2]
            return "<a href=\"\(url)\">\(label)</a>"
        }

        text = replacing(
            pattern: #"\*\*([^*]+)\*\*"#,
            in: text
        ) { match in
            "<strong>\(match[1])</strong>"
        }

        text = replacing(
            pattern: #"(?<!\*)\*([^*]+)\*(?!\*)"#,
            in: text
        ) { match in
            "<em>\(match[1])</em>"
        }

        text = replacing(
            pattern: #"`([^`]+)`"#,
            in: text
        ) { match in
            "<code>\(match[1])</code>"
        }

        return text
    }

    private static func replacing(
        pattern: String,
        in source: String,
        transform: ([String]) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return source }
        let nsSource = source as NSString
        let matches = regex.matches(in: source, range: NSRange(location: 0, length: nsSource.length))
        guard !matches.isEmpty else { return source }

        var result = source
        for match in matches.reversed() {
            var groups: [String] = []
            for idx in 0..<match.numberOfRanges {
                let range = match.range(at: idx)
                if range.location != NSNotFound {
                    groups.append(nsSource.substring(with: range))
                } else {
                    groups.append("")
                }
            }
            let replacement = transform(groups)
            if let swiftRange = Range(match.range, in: result) {
                result.replaceSubrange(swiftRange, with: replacement)
            }
        }
        return result
    }

    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func colorHexString(_ color: NSColor) -> String {
        let rgb = color.usingColorSpace(.deviceRGB) ?? .labelColor
        let r = Int((rgb.redComponent * 255).rounded())
        let g = Int((rgb.greenComponent * 255).rounded())
        let b = Int((rgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    final class Coordinator {
        var lastHTML: String?
    }
}
