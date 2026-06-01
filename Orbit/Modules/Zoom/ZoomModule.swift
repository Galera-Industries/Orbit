//
//  ZoomModule.swift — File Research
//  Orbit
//

import Foundation
import SwiftUI
import PDFKit
internal import os

final class FileResearchModule: ModulePlugin, ZoomMonitorDelegate {
    let mode: AppMode = .zoom

    private weak var shellModel: ShellModel?
    private var emit: (([ResultItem]) -> Void)?
    private var recentFiles: [ZoomDetectedFile] = []
    private var processingFiles: Set<URL> = []
    private var statusMessage: String = ""
    private var statusIsError: Bool = false

    // MARK: - ModulePlugin

    func activate(context: ModuleContext) {
        ZoomMonitorService.shared.delegate = self
        ZoomMonitorService.shared.start()
    }

    func deactivate() {
        ZoomMonitorService.shared.stop()
        ZoomMonitorService.shared.delegate = nil
    }

    func parse(query: ParsedQuery) -> Any? {
        guard query.mode == .zoom else { return nil }
        return query.text
    }

    func search(intent: Any, cancellation: @escaping () -> Bool, emit: @escaping ([ResultItem]) -> Void) {
        self.emit = emit

        var items: [ResultItem] = []

        let hasKey = DeepSeekService.shared.hasChatGPTToken
        let watchFolder = ZoomMonitorService.shared.watchFolder

        let statusTitle: String
        let statusSubtitle: String
        let statusIcon: String

        if !hasKey {
            statusTitle = "API ключ не настроен"
            statusSubtitle = "Открой Settings → AI Сервисы и введи OpenAI API ключ"
            statusIcon = "exclamationmark.triangle"
        } else if !statusMessage.isEmpty {
            statusTitle = statusMessage
            statusSubtitle = statusIsError ? "Проверь API ключ и подключение" : "Ответ сохранён в панели (⌘⌥R)"
            statusIcon = statusIsError ? "xmark.circle" : "checkmark.circle.fill"
        } else {
            statusTitle = "File Research активен"
            statusSubtitle = "Папка: \(watchFolder.path)"
            statusIcon = "folder.fill"
        }

        items.append(ResultItem(
            title: statusTitle,
            subtitle: statusSubtitle,
            icon: statusIcon,
            primaryAction: {}
        ))

        items.append(ResultItem(
            title: "Отправить последний файл в ChatGPT",
            subtitle: "Найти самый новый файл в папке и обработать",
            icon: "arrow.up.circle",
            primaryAction: { FileResearchModule.sendLatestFileToChatGPT() }
        ))

        items.append(ResultItem(
            title: "Сканировать папку сейчас",
            subtitle: watchFolder.path,
            icon: "arrow.clockwise.circle",
            primaryAction: { [weak self] in self?.scanAndProcessExisting() }
        ))

        for file in recentFiles.suffix(10).reversed() {
            let name = file.url.lastPathComponent
            items.append(ResultItem(
                title: name,
                subtitle: "Папка: \(file.meetingFolder)",
                icon: iconName(for: file.url),
                accessory: "Обработан",
                primaryAction: { NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: "") }
            ))
        }

        emit(items)
    }

    func execute(item: ResultItem, modifiers: EventModifiers) -> Outcome { .done }

    func backgroundTick() {}

    func setShellModel(_ model: ShellModel) {
        shellModel = model
    }

    // MARK: - ZoomMonitorDelegate

    func zoomMonitor(_ monitor: ZoomMonitorService, didDetectFile file: ZoomDetectedFile) {
        guard !processingFiles.contains(file.url) else { return }
        processingFiles.insert(file.url)
        if !recentFiles.contains(where: { $0.url == file.url }) {
            recentFiles.append(file)
        }
        L.zoom.info("Processing file: \(file.url.lastPathComponent)")

        processFile(file) { [weak self] result in
            guard let self else { return }
            self.processingFiles.remove(file.url)
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    L.zoom.info("File processed OK")
                    self.storeResponse(response, fileName: file.url.lastPathComponent)
                    self.setStatus("✓ \(file.url.lastPathComponent) обработан", isError: false)
                case .failure(let error):
                    L.zoom.error("File error: \(error.localizedDescription)")
                    self.setStatus("Ошибка: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    // MARK: - Direct send (called from hotkey without opening Orbit)

    static func sendLatestFileToChatGPT() {
        let folder = ZoomMonitorService.shared.watchFolder
        let supported: Set<String> = ["pdf", "png", "jpg", "jpeg", "gif", "txt", "csv"]

        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            L.zoom.error("sendLatestFile: folder not accessible: \(folder.path)")
            return
        }

        var latestURL: URL?
        var latestDate: Date?

        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            guard supported.contains(url.pathExtension.lowercased()) else { continue }
            let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if latestDate == nil || (modDate != nil && modDate! > latestDate!) {
                latestDate = modDate
                latestURL = url
            }
        }

        guard let url = latestURL else {
            L.zoom.info("sendLatestFile: no files found in \(folder.path)")
            return
        }

        L.zoom.info("sendLatestFile: sending \(url.lastPathComponent) to ChatGPT")
        let prompt = UserDefaults.standard.string(forKey: "zoomPrompt")
            ?? "Проанализируй этот файл. Дай краткое резюме содержимого."

        processFileAt(url, prompt: prompt) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    L.zoom.info("sendLatestFile: success")
                    var responses = UserDefaults.standard.stringArray(forKey: "chatgptResponses") ?? []
                    responses.insert(response, at: 0)
                    if responses.count > 50 { responses = Array(responses.prefix(50)) }
                    UserDefaults.standard.set(responses, forKey: "chatgptResponses")

                    var zoomResponses = UserDefaults.standard.stringArray(forKey: "zoomResponses") ?? []
                    zoomResponses.insert("[\(url.lastPathComponent)] \(response)", at: 0)
                    if zoomResponses.count > 20 { zoomResponses = Array(zoomResponses.prefix(20)) }
                    UserDefaults.standard.set(zoomResponses, forKey: "zoomResponses")
                case .failure(let error):
                    L.zoom.error("sendLatestFile: error \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Manual scan

    private func scanAndProcessExisting() {
        let folder = ZoomMonitorService.shared.watchFolder
        let supported: Set<String> = ["pdf", "png", "jpg", "jpeg", "gif", "txt", "csv"]

        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            setStatus("Папка не найдена: \(folder.path)", isError: true)
            return
        }

        var found = 0
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            guard supported.contains(url.pathExtension.lowercased()) else { continue }
            guard !processingFiles.contains(url) else { continue }
            found += 1

            let relComponents = url.pathComponents.dropFirst(folder.pathComponents.count)
            let meetingFolder = relComponents.count >= 2 ? String(relComponents.first ?? "Files") : "Files"
            let detected = ZoomDetectedFile(url: url, meetingFolder: meetingFolder, detectedAt: Date())
            zoomMonitor(ZoomMonitorService.shared, didDetectFile: detected)
        }

        if found == 0 {
            setStatus("Нет файлов в папке", isError: false)
        }
    }

    private func setStatus(_ message: String, isError: Bool) {
        statusMessage = message
        statusIsError = isError
        if let emit = self.emit {
            search(intent: "", cancellation: { false }, emit: emit)
        }
    }

    // MARK: - File Processing (instance)

    private func processFile(_ file: ZoomDetectedFile, completion: @escaping (Result<String, Error>) -> Void) {
        let prompt = UserDefaults.standard.string(forKey: "zoomPrompt")
            ?? "Проанализируй этот файл. Дай краткое резюме содержимого."
        Self.processFileAt(file.url, prompt: prompt, completion: completion)
    }

    // MARK: - File Processing (static, shared)

    static func processFileAt(_ url: URL, prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            if let text = extractPDFText(from: url), !text.isEmpty {
                DeepSeekService.shared.sendTextToChatGPT(
                    prompt: "\(prompt)\n\nФайл: \(url.lastPathComponent)\n\n\(text)",
                    completion: completion
                )
            } else {
                completion(.failure(FileResearchError.unreadableFile))
            }

        case "png", "jpg", "jpeg", "gif":
            guard let imageData = try? Data(contentsOf: url) else {
                completion(.failure(FileResearchError.unreadableFile))
                return
            }
            DeepSeekService.shared.sendToChatGPT(
                imageBase64: imageData.base64EncodedString(),
                prompt: "\(prompt)\n\nФайл: \(url.lastPathComponent)",
                completion: completion
            )

        case "txt", "csv":
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                completion(.failure(FileResearchError.unreadableFile))
                return
            }
            DeepSeekService.shared.sendTextToChatGPT(
                prompt: "\(prompt)\n\nФайл: \(url.lastPathComponent)\n\n\(text)",
                completion: completion
            )

        default:
            if let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty {
                DeepSeekService.shared.sendTextToChatGPT(
                    prompt: "\(prompt)\n\nФайл: \(url.lastPathComponent)\n\n\(text)",
                    completion: completion
                )
            } else {
                completion(.failure(FileResearchError.unsupportedFormat))
            }
        }
    }

    private static func extractPDFText(from url: URL) -> String? {
        guard let doc = PDFDocument(url: url) else { return nil }
        return (0..<doc.pageCount).compactMap { doc.page(at: $0)?.string }.joined(separator: "\n")
    }

    private func storeResponse(_ response: String, fileName: String) {
        var zoomResponses = UserDefaults.standard.stringArray(forKey: "zoomResponses") ?? []
        zoomResponses.insert("[\(fileName)] \(response)", at: 0)
        if zoomResponses.count > 20 { zoomResponses = Array(zoomResponses.prefix(20)) }
        UserDefaults.standard.set(zoomResponses, forKey: "zoomResponses")

        var chatgptResponses = UserDefaults.standard.stringArray(forKey: "chatgptResponses") ?? []
        chatgptResponses.insert(response, at: 0)
        if chatgptResponses.count > 50 { chatgptResponses = Array(chatgptResponses.prefix(50)) }
        UserDefaults.standard.set(chatgptResponses, forKey: "chatgptResponses")
    }

    private func iconName(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "png", "jpg", "jpeg", "gif": return "photo"
        case "txt": return "doc.text"
        case "csv": return "tablecells"
        default: return "doc"
        }
    }
}

// Keep old name as typealias for any references
typealias ZoomModule = FileResearchModule

enum FileResearchError: LocalizedError {
    case unreadableFile
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .unreadableFile: return "Не удалось прочитать файл"
        case .unsupportedFormat: return "Неподдерживаемый формат файла"
        }
    }
}

enum ZoomError: LocalizedError {
    case unreadableFile
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .unreadableFile: return "Не удалось прочитать файл"
        case .unsupportedFormat: return "Неподдерживаемый формат файла"
        }
    }
}
