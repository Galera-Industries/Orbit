//
//  ScreenshotSettingsView.swift
//  Orbit
//

import SwiftUI
import AppKit

struct ScreenshotSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SettingsTab = .ai

    var body: some View {
        GlassPanel {
            HStack(spacing: 0) {
                sidebar
                Divider()
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 700, height: 560)
        .presentationBackground(.clear)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Настройки")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ForEach(SettingsTab.allCases) { tab in
                SidebarRow(tab: tab, isSelected: selectedTab == tab) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedTab = tab
                    }
                }
            }

            Spacer()
        }
        .frame(width: 200)
        .background(.black.opacity(0.04))
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch selectedTab {
                case .ai:      AIServicesTab()
                case .zoom:    ZoomTab()
                case .messaging: MessagingTab()
                case .panel:   ResponsePanelTab()
                case .hotkeys: HotkeysTab()
                }
            }
            .padding(24)
        }
        .scrollIndicators(.never)
    }
}

// MARK: - Tab enum

enum SettingsTab: String, CaseIterable, Identifiable {
    case ai, zoom, messaging, panel, hotkeys
    var id: String { rawValue }

    var label: String {
        switch self {
        case .ai: return "AI Сервисы"
        case .zoom: return "Файлы"
        case .messaging: return "Мессенджеры"
        case .panel: return "Панель ответов"
        case .hotkeys: return "Горячие клавиши"
        }
    }

    var icon: String {
        switch self {
        case .ai: return "cpu"
        case .zoom: return "folder"
        case .messaging: return "bubble.left.and.bubble.right"
        case .panel: return "rectangle.on.rectangle"
        case .hotkeys: return "keyboard"
        }
    }
}

// MARK: - Sidebar Row

struct SidebarRow: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                Text(tab.label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : (isHovered ? Color.black.opacity(0.05) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Shared Components

struct SettingsCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.black.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.08)))
        )
    }
}

struct SecureKeyField: View {
    let placeholder: String
    @Binding var value: String
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isVisible {
                    TextField(placeholder, text: $value)
                } else {
                    SecureField(placeholder, text: $value)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 7).fill(.black.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.08)))

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
    }
}

struct HotkeyBadge: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(.black.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.1)))
    }
}

// MARK: - AI Services Tab

struct AIServicesTab: View {
    private static let providerValues: [String] = ["proxy", "eliza"]
    private static let predefinedChatGPTModels: [String] = [
        "gpt-5.5",
        "gpt-5.5-pro",
        "gpt-5.4",
        "gpt-5.4-pro",
        "gpt-5.4-mini",
        "gpt-5.4-nano",
        "gpt-5",
        "gpt-5-pro",
        "gpt-5-mini",
        "gpt-5-nano",
        "gpt-4.1",
        "gpt-4.1-mini",
        "gpt-4o",
        "gpt-4o-mini",
        "o4-mini"
    ]
    
    private static let predefinedElizaModels: [String] = [
        "gpt-5.5",
        "openai/gpt-5.4",
        "anthropic/claude-opus-4-7",
        "anthropic/claude-sonnet-4.6"
    ]
    
    @State private var chatGPTKey: String = KeychainService.shared.get(forKey: "chatGPTToken") ?? ""
    @State private var elizaToken: String = KeychainService.shared.get(forKey: "elizaToken") ?? ""
    @State private var selectedProvider: String = UserDefaults.standard.string(forKey: "chatGPTProvider") ?? "proxy"
    @State private var selectedChatGPTModel: String = "server-default"
    @State private var customChatGPTModel: String = ""
    @State private var deepSeekKey: String = KeychainService.shared.get(forKey: "deepseekApiKey") ?? ""
    @State private var prompt: String = UserDefaults.standard.string(forKey: "deepseekPrompt") ?? "Что изображено на этом скриншоте?"
    @State private var systemMsg: String = UserDefaults.standard.string(forKey: "systemMessage") ?? ""
    @State private var datasetFolder: String = UserDefaults.standard.string(forKey: "datasetQuestionsFolder") ?? ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: "OpenAI / ChatGPT / Eliza", subtitle: "Для скриншотов и текстовых запросов", icon: "key") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Провайдер запросов")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $selectedProvider) {
                        Text("got_proxy").tag("proxy")
                        Text("Eliza").tag("eliza")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedProvider) { value in
                        if Self.providerValues.contains(value) {
                            UserDefaults.standard.set(value, forKey: "chatGPTProvider")
                            if value == "eliza" && selectedChatGPTModel == "server-default" {
                                selectedChatGPTModel = "gpt-5.5"
                                saveChatGPTModel()
                            }
                        }
                    }
                }
                
                if selectedProvider == "proxy" {
                    SecureKeyField(placeholder: "sk-...", value: $chatGPTKey)
                        .onChange(of: chatGPTKey) { KeychainService.shared.set($0, forKey: "chatGPTToken") }
                } else {
                    SecureKeyField(placeholder: "OAuth token", value: $elizaToken)
                        .onChange(of: elizaToken) { KeychainService.shared.set($0, forKey: "elizaToken") }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedProvider == "proxy" ? "Модель ChatGPT" : "Модель Eliza")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $selectedChatGPTModel) {
                        if selectedProvider == "proxy" {
                            Text("По умолчанию сервера").tag("server-default")
                        }
                        
                        ForEach(modelOptions, id: \.self) { model in
                            Text(model).tag(model)
                        }
                        
                        Text("Custom...").tag("custom")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedChatGPTModel) { _ in
                        saveChatGPTModel()
                    }
                    
                    if selectedChatGPTModel == "custom" {
                        TextField(customModelPlaceholder, text: $customChatGPTModel)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 7).fill(.black.opacity(0.06)))
                            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.08)))
                            .onChange(of: customChatGPTModel) { _ in
                                saveChatGPTModel()
                            }
                    }
                }
                
                if selectedProvider == "proxy" {
                    Text("Используется через got_proxy (5.34.212.145:8000). Начинается с sk-")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Если выбрать «По умолчанию сервера», модель берется из GPT_MODEL на сервере.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text("Eliza endpoint: https://api.eliza.yandex.net/{vendor}/v1/chat/completions")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Authorization: OAuth <token>. Для моделей вида vendor/model используется vendor openrouter.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            SettingsCard(title: "DeepSeek API Key", subtitle: "Для текстовых запросов", icon: "key.fill") {
                SecureKeyField(placeholder: "Введите API ключ DeepSeek", value: $deepSeekKey)
                    .onChange(of: deepSeekKey) { KeychainService.shared.set($0, forKey: "deepseekApiKey") }
            }

            SettingsCard(title: "Промпт по умолчанию", subtitle: "User message для скриншотов и браузера", icon: "text.bubble") {
                TextEditor(text: $prompt)
                    .frame(height: 80)
                    .font(.system(size: 13))
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 7).fill(.black.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.08)))
                    .onChange(of: prompt) { UserDefaults.standard.set($0, forKey: "deepseekPrompt") }
            }

            SettingsCard(title: "System Message", subtitle: "Опционально — поведение модели", icon: "text.alignleft") {
                TextEditor(text: $systemMsg)
                    .frame(height: 80)
                    .font(.system(size: 13))
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 7).fill(.black.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.08)))
                    .onChange(of: systemMsg) { UserDefaults.standard.set($0, forKey: "systemMessage") }
                Text("Если пусто — system message не отправляется")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            SettingsCard(title: "Папка для ⌘⌥N и ⌘⌥P", subtitle: "train.csv, test.csv и main.py", icon: "folder") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Папка с локальными CSV")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Text(datasetFolder.isEmpty ? "Папка не выбрана" : datasetFolder)
                            .font(.system(size: 11))
                            .foregroundColor(datasetFolder.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.06)))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.08)))

                        Button("Выбрать") {
                            pickDatasetFolder()
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.07)))
                        .buttonStyle(.plain)
                    }
                }

                Text("⌘⌥N читает train.csv и test.csv из этой папки. ⌘⌥P дополнительно читает main.py и, если есть, output.txt (иначе берет текст из буфера обмена).")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loadProvider()
            loadChatGPTModel()
        }
    }
    
    private var modelOptions: [String] {
        selectedProvider == "eliza" ? Self.predefinedElizaModels : Self.predefinedChatGPTModels
    }
    
    private var customModelPlaceholder: String {
        if selectedProvider == "eliza" {
            return "Введите id модели (например: openai/gpt-5.4)"
        }
        return "Введите id модели (например: gpt-5)"
    }
    
    private func loadProvider() {
        let provider = UserDefaults.standard.string(forKey: "chatGPTProvider") ?? "proxy"
        selectedProvider = Self.providerValues.contains(provider) ? provider : "proxy"
    }
    
    private func loadChatGPTModel() {
        let saved = UserDefaults.standard.string(forKey: "chatGPTModel")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if saved.isEmpty {
            selectedChatGPTModel = selectedProvider == "eliza" ? "gpt-5.5" : "server-default"
            customChatGPTModel = ""
        } else if modelOptions.contains(saved) {
            selectedChatGPTModel = saved
            customChatGPTModel = ""
        } else {
            selectedChatGPTModel = "custom"
            customChatGPTModel = saved
        }
    }
    
    private func saveChatGPTModel() {
        switch selectedChatGPTModel {
        case "server-default":
            if selectedProvider == "proxy" {
                UserDefaults.standard.set("", forKey: "chatGPTModel")
            } else {
                UserDefaults.standard.set("gpt-5.5", forKey: "chatGPTModel")
            }
        case "custom":
            UserDefaults.standard.set(customChatGPTModel.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "chatGPTModel")
        default:
            UserDefaults.standard.set(selectedChatGPTModel, forKey: "chatGPTModel")
        }
    }

    private func pickDatasetFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Выберите папку с train.csv, test.csv и main.py"
        panel.prompt = "Выбрать"

        if panel.runModal() == .OK, let url = panel.url {
            datasetFolder = url.path
            UserDefaults.standard.set(url.path, forKey: "datasetQuestionsFolder")
        }
    }
}

// MARK: - File Research Tab

struct ZoomTab: View {
    @State private var zoomPrompt: String = UserDefaults.standard.string(forKey: "zoomPrompt")
        ?? "Проанализируй этот файл. Дай краткое резюме содержимого."
    @State private var isEnabled: Bool = UserDefaults.standard.bool(forKey: "zoomMonitorEnabled")
    @State private var selectedFolder: String = {
        UserDefaults.standard.string(forKey: "fileResearchFolder")
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Zoom").path
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: "File Research", subtitle: "Мониторинг папки и отправка файлов в ChatGPT", icon: "folder") {
                Toggle("Включить автоматический мониторинг папки", isOn: $isEnabled)
                    .onChange(of: isEnabled) {
                        UserDefaults.standard.set($0, forKey: "zoomMonitorEnabled")
                    }
                    .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Папка для слежения")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Text(selectedFolder)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.06)))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.08)))

                        Button("Выбрать") {
                            pickFolder()
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.07)))
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Поддерживаемые форматы")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        ForEach(["PDF", "PNG", "JPG", "TXT", "CSV"], id: \.self) { fmt in
                            Text(fmt)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.06)))
                        }
                    }
                }

                HStack(spacing: 12) {
                    HotkeyBadge(label: "⌘⌥Z")
                    Text("Отправить последний файл из папки в GPT (напрямую, без открытия Orbit)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            SettingsCard(title: "Промпт для файлов", subtitle: "Инструкция для ChatGPT при анализе файлов", icon: "text.bubble.fill") {
                TextEditor(text: $zoomPrompt)
                    .frame(height: 100)
                    .font(.system(size: 13))
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 7).fill(.black.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.08)))
                    .onChange(of: zoomPrompt) { UserDefaults.standard.set($0, forKey: "zoomPrompt") }
                Text("Этот промпт будет добавлен перед содержимым каждого файла")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Выберите папку для File Research"
        panel.prompt = "Выбрать"
        if panel.runModal() == .OK, let url = panel.url {
            selectedFolder = url.path
            UserDefaults.standard.set(url.path, forKey: "fileResearchFolder")
            ZoomMonitorService.shared.restart()
        }
    }
}

// MARK: - Messaging Tab

struct MessagingTab: View {
    @State private var telegramToken: String = KeychainService.shared.get(forKey: "telegramBotToken") ?? ""
    @State private var telegramChatID: String = UserDefaults.standard.string(forKey: "telegramChatID") ?? ""
    @State private var vkToken: String = KeychainService.shared.get(forKey: "vkAccessToken") ?? ""
    @State private var vkPeerID: String = UserDefaults.standard.string(forKey: "vkPeerID") ?? ""
    @State private var watchChannel: String = UserDefaults.standard.string(forKey: "watchChannelNumber") ?? "1"
    @State private var isChatIDEditable: Bool = (UserDefaults.standard.string(forKey: "telegramChatID") ?? "").isEmpty
    @State private var isCheckingBot = false
    @State private var botStatus = ""
    @State private var isCheckingVk = false
    @State private var vkStatus = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Telegram
            SettingsCard(title: "Telegram Bot", subtitle: "Отправка ответов в Telegram", icon: "paperplane") {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bot Token")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        SecureKeyField(placeholder: "Токен от @BotFather", value: $telegramToken)
                            .onChange(of: telegramToken) { KeychainService.shared.set($0, forKey: "telegramBotToken") }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chat ID")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            TextField("Chat ID", text: $telegramChatID)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 7).fill(.black.opacity(0.06)))
                                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.08)))
                                .disabled(!isChatIDEditable)
                                .onChange(of: telegramChatID) {
                                    if !$0.isEmpty { UserDefaults.standard.set($0, forKey: "telegramChatID") }
                                }
                            if !isChatIDEditable {
                                Button("Изменить") { isChatIDEditable = true }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.07)))
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            checkTelegramBot()
                        } label: {
                            HStack(spacing: 6) {
                                if isCheckingBot { ProgressView().scaleEffect(0.65) }
                                else { Image(systemName: "checkmark.circle").font(.system(size: 12)) }
                                Text("Проверить бота").font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.07)))
                        }
                        .buttonStyle(.plain).disabled(isCheckingBot)

                        if !botStatus.isEmpty {
                            Text(botStatus)
                                .font(.system(size: 11))
                                .foregroundColor(botStatus.contains("успешно") || botStatus.contains("работает") ? .green : .red)
                        }
                    }
                }
            }

            // VK
            SettingsCard(title: "VKontakte", subtitle: "Отправка ответов в VK", icon: "v.circle") {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Access Token")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        SecureKeyField(placeholder: "VK Access Token", value: $vkToken)
                            .onChange(of: vkToken) { KeychainService.shared.set($0, forKey: "vkAccessToken") }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Peer ID")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("User ID или беседа", text: $vkPeerID)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 7).fill(.black.opacity(0.06)))
                            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.08)))
                            .onChange(of: vkPeerID) {
                                if $0.allSatisfy({ $0.isNumber || $0 == "-" }) {
                                    UserDefaults.standard.set($0, forKey: "vkPeerID")
                                }
                            }
                    }

                    HStack(spacing: 10) {
                        Button {
                            checkVK()
                        } label: {
                            HStack(spacing: 6) {
                                if isCheckingVk { ProgressView().scaleEffect(0.65) }
                                else { Image(systemName: "checkmark.circle").font(.system(size: 12)) }
                                Text("Проверить токен").font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.07)))
                        }
                        .buttonStyle(.plain).disabled(isCheckingVk)

                        if !vkStatus.isEmpty {
                            Text(vkStatus)
                                .font(.system(size: 11))
                                .foregroundColor(vkStatus.contains("успешно") || vkStatus.contains("валидный") ? .green : .red)
                        }
                    }
                }
            }

            // Apple Watch
            SettingsCard(title: "Apple Watch", subtitle: "Канал для бэкенда", icon: "applewatch") {
                HStack(spacing: 8) {
                    TextField("Номер канала", text: $watchChannel)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 7).fill(.black.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.08)))
                        .frame(width: 100)
                        .onChange(of: watchChannel) { v in
                            let filtered = v.filter(\.isNumber)
                            if filtered != v { watchChannel = filtered }
                            else { UserDefaults.standard.set(filtered.isEmpty ? "1" : filtered, forKey: "watchChannelNumber") }
                        }
                    Text("Совпадает с номером канала в настройках Apple Watch")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear { migrateMessagingKeys() }
    }

    private func migrateMessagingKeys() {
        KeychainService.shared.migrateFromUserDefaults(key: "telegramBotToken")
        KeychainService.shared.migrateFromUserDefaults(key: "vkAccessToken")
        telegramToken = KeychainService.shared.get(forKey: "telegramBotToken") ?? ""
        vkToken = KeychainService.shared.get(forKey: "vkAccessToken") ?? ""
    }

    private func checkTelegramBot() {
        isCheckingBot = true
        botStatus = ""
        TelegramBotService.shared.checkBotStatus { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ok) where ok:
                    self.botStatus = "Бот работает. Получаю Chat ID..."
                    TelegramBotService.shared.fetchChatID { r in
                        DispatchQueue.main.async {
                            self.isCheckingBot = false
                            switch r {
                            case .success(let id):
                                self.telegramChatID = id
                                self.botStatus = "Chat ID успешно получен: \(id)"
                                self.isChatIDEditable = false
                            case .failure(let e):
                                self.botStatus = "Ошибка: \(e.localizedDescription)"
                            }
                        }
                    }
                case .success:
                    self.isCheckingBot = false
                    self.botStatus = "Бот не отвечает"
                case .failure(let e):
                    self.isCheckingBot = false
                    self.botStatus = "Ошибка: \(e.localizedDescription)"
                }
            }
        }
    }

    private func checkVK() {
        isCheckingVk = true
        vkStatus = ""
        VKService.shared.checkTokenStatus { result in
            DispatchQueue.main.async {
                self.isCheckingVk = false
                switch result {
                case .success(let ok):
                    self.vkStatus = ok ? "Токен VK валидный" : "Токен не валидный"
                case .failure(let e):
                    self.vkStatus = "Ошибка: \(e.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Response Panel Tab

struct ResponsePanelTab: View {
    @State private var position: String = {
        let p = UserDefaults.standard.string(forKey: "responsePanelPosition") ?? "right-top"
        if p == "left" { return "left-top" }
        if p == "right" { return "right-top" }
        return p
    }()
    @State private var panelWidth: Double = {
        let w = UserDefaults.standard.double(forKey: "responsePanelWidth")
        return w > 0 ? w : 50
    }()
    @State private var panelHeight: Double = {
        let h = UserDefaults.standard.double(forKey: "responsePanelHeight")
        return h > 0 ? h : 50
    }()
    @State private var horizontalInset: Double = {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "responsePanelHorizontalInset") != nil else { return 20 }
        return defaults.double(forKey: "responsePanelHorizontalInset")
    }()
    @State private var verticalInset: Double = {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "responsePanelVerticalInset") != nil else { return 20 }
        return defaults.double(forKey: "responsePanelVerticalInset")
    }()
    @State private var textSize: Double = {
        let value = UserDefaults.standard.double(forKey: "responsePanelTextSize")
        return value > 0 ? value : 12
    }()
    @State private var layoutMode: String = UserDefaults.standard.string(forKey: "responsePanelLayoutMode") ?? "horizontal"
    @State private var backgroundType: String = UserDefaults.standard.string(forKey: "responsePanelBackgroundType") ?? "colored"
    @State private var hotkeyKey: String = UserDefaults.standard.string(forKey: "responsePanelHotkeyKey") ?? "r"
    @State private var cmdMod: Bool = {
        (UserDefaults.standard.stringArray(forKey: "responsePanelHotkeyModifiers") ?? ["cmd", "opt"]).contains("cmd")
    }()
    @State private var optMod: Bool = {
        (UserDefaults.standard.stringArray(forKey: "responsePanelHotkeyModifiers") ?? ["cmd", "opt"]).contains("opt")
    }()
    @State private var shiftMod: Bool = {
        (UserDefaults.standard.stringArray(forKey: "responsePanelHotkeyModifiers") ?? ["cmd", "opt"]).contains("shift")
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: "Позиция и размер", icon: "rectangle.on.rectangle") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Угол привязки")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Picker("", selection: $position) {
                            Text("↗ Правый верхний").tag("right-top")
                            Text("↖ Левый верхний").tag("left-top")
                            Text("↘ Правый нижний").tag("right-bottom")
                            Text("↙ Левый нижний").tag("left-bottom")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                        .onChange(of: position) {
                            UserDefaults.standard.set($0, forKey: "responsePanelPosition")
                            ResponsePanelManager.shared.updatePanel()
                        }
                    }

                    freeNumberFieldRow(
                        title: "Ширина панели",
                        value: $panelWidth,
                        suffix: "px"
                    ) { value in
                        guard value > 0 else { return }
                        UserDefaults.standard.set(value, forKey: "responsePanelWidth")
                        ResponsePanelManager.shared.updatePanel()
                    }

                    freeNumberFieldRow(
                        title: "Высота панели",
                        value: $panelHeight,
                        suffix: "px"
                    ) { value in
                        guard value > 0 else { return }
                        UserDefaults.standard.set(value, forKey: "responsePanelHeight")
                        ResponsePanelManager.shared.updatePanel()
                    }

                    freeNumberFieldRow(
                        title: "Горизонтальный отступ",
                        value: $horizontalInset,
                        suffix: "px"
                    ) { value in
                        UserDefaults.standard.set(value, forKey: "responsePanelHorizontalInset")
                        ResponsePanelManager.shared.updatePanel()
                    }

                    freeNumberFieldRow(
                        title: "Вертикальный отступ",
                        value: $verticalInset,
                        suffix: "px"
                    ) { value in
                        UserDefaults.standard.set(value, forKey: "responsePanelVerticalInset")
                        ResponsePanelManager.shared.updatePanel()
                    }
                }
            }

            SettingsCard(title: "Внешний вид", icon: "paintbrush") {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Режим отображения").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                        Picker("", selection: $layoutMode) {
                            Text("Горизонтальный").tag("horizontal")
                            Text("Вертикальный").tag("vertical")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                        .onChange(of: layoutMode) { UserDefaults.standard.set($0, forKey: "responsePanelLayoutMode") }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Тип фона (⌘⌥B)").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                        Picker("", selection: $backgroundType) {
                            Text("Цветной").tag("colored")
                            Text("Размытый").tag("blurred")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                        .onChange(of: backgroundType) { UserDefaults.standard.set($0, forKey: "responsePanelBackgroundType") }
                    }
                }
                .padding(.bottom, 2)

                numberControlRow(
                    title: "Размер текста",
                    value: $textSize,
                    range: 9...24,
                    suffix: "pt"
                ) { value in
                    UserDefaults.standard.set(value, forKey: "responsePanelTextSize")
                    NotificationCenter.default.post(name: .responsePanelTextSizeDidChange, object: nil)
                }
            }

            SettingsCard(title: "Горячая клавиша", subtitle: "Показать / скрыть панель", icon: "keyboard") {
                HStack(spacing: 8) {
                    Toggle("⌘", isOn: $cmdMod)
                        .toggleStyle(.button).font(.system(size: 11))
                        .onChange(of: cmdMod) { _ in saveHotkeyMods() }
                    Toggle("⌥", isOn: $optMod)
                        .toggleStyle(.button).font(.system(size: 11))
                        .onChange(of: optMod) { _ in saveHotkeyMods() }
                    Toggle("⇧", isOn: $shiftMod)
                        .toggleStyle(.button).font(.system(size: 11))
                        .onChange(of: shiftMod) { _ in saveHotkeyMods() }

                    Text("+").foregroundColor(.secondary)

                    TextField("R", text: $hotkeyKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.06)))
                        .frame(width: 45)
                        .onChange(of: hotkeyKey) { v in
                            let filtered = String(v.prefix(1).lowercased())
                            UserDefaults.standard.set(filtered, forKey: "responsePanelHotkeyKey")
                            ResponsePanelManager.shared.updateHotkey()
                        }
                }
            }
        }
    }

    private func saveHotkeyMods() {
        var mods: [String] = []
        if cmdMod { mods.append("cmd") }
        if optMod { mods.append("opt") }
        if shiftMod { mods.append("shift") }
        UserDefaults.standard.set(mods, forKey: "responsePanelHotkeyModifiers")
        ResponsePanelManager.shared.updateHotkey()
    }

    @ViewBuilder
    private func numberControlRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        suffix: String,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        HStack(spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(value.wrappedValue)) \(suffix)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField("", value: value, format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.08)))
                .frame(width: 68)
                .multilineTextAlignment(.center)

            Stepper("", value: value, in: range, step: 1)
                .labelsHidden()
        }
        .onChange(of: value.wrappedValue) { newValue in
            let clamped = min(range.upperBound, max(range.lowerBound, newValue))
            if abs(clamped - newValue) > 0.001 {
                value.wrappedValue = clamped
            }
            onChange(clamped)
        }
    }

    @ViewBuilder
    private func freeNumberFieldRow(
        title: String,
        value: Binding<Double>,
        suffix: String,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        HStack(spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(value.wrappedValue)) \(suffix)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField("", value: value, format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.08)))
                .frame(width: 88)
                .multilineTextAlignment(.center)
        }
        .onChange(of: value.wrappedValue) { newValue in
            onChange(newValue)
        }
    }
}

// MARK: - Hotkeys Tab

struct HotkeysTab: View {
    @ObservedObject private var config = HotkeyConfig.shared
    @State private var expandedID: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: "Глобальные горячие клавиши", subtitle: "Включайте/выключайте и настраивайте комбинации", icon: "keyboard") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach($config.entries) { $entry in
                        VStack(alignment: .leading, spacing: 0) {
                            HotkeyRow(entry: $entry, isExpanded: expandedID == entry.id) {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    expandedID = (expandedID == entry.id) ? nil : entry.id
                                }
                            } onChanged: {
                                config.save()
                                HotkeyBootstrap.reload()
                            }

                            if expandedID == entry.id && entry.keyChar != "1-9" && entry.keyChar != "space" {
                                HotkeyEditor(entry: $entry) {
                                    config.save()
                                    HotkeyBootstrap.reload()
                                }
                                .padding(.leading, 44)
                                .padding(.bottom, 8)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        if entry.id != config.entries.last?.id {
                            Divider().opacity(0.4)
                        }
                    }
                }
            }

            SettingsCard(title: "Панель ответов и другие", subtitle: "Настраиваются в разделе «Панель ответов»", icon: "info.circle") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach([
                        ("⌘⌥R", "Показать/скрыть панель ответов"),
                        ("⌘⌥L", "Переключить layout панели"),
                        ("⌘⌥B", "Переключить фон панели"),
                        ("⌘⌥− / ⌘⌥+", "Уменьшить/увеличить размер текста"),
                    ], id: \.0) { key, desc in
                        HStack(spacing: 12) {
                            HotkeyBadge(label: key).frame(width: 130, alignment: .leading)
                            Text(desc).font(.system(size: 12)).foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}

struct HotkeyRow: View {
    @Binding var entry: HotkeyEntry
    let isExpanded: Bool
    let onTap: () -> Void
    let onChanged: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $entry.enabled)
                .toggleStyle(.switch)
                .scaleEffect(0.75)
                .frame(width: 40)
                .onChange(of: entry.enabled) { _ in onChanged() }

            Text(entry.label)
                .font(.system(size: 12))
                .foregroundColor(entry.enabled ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HotkeyBadge(
                label: HotkeyConfig.displayString(keyChar: entry.keyChar, modifiers: entry.modifiers)
            )
            .opacity(entry.enabled ? 1.0 : 0.4)

            if entry.keyChar != "1-9" && entry.keyChar != "space" {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            if entry.keyChar != "1-9" && entry.keyChar != "space" {
                onTap()
            }
        }
    }
}

struct HotkeyEditor: View {
    @Binding var entry: HotkeyEntry
    let onChanged: () -> Void

    @State private var keyChar: String = ""
    @State private var cmdMod: Bool = false
    @State private var optMod: Bool = false
    @State private var shiftMod: Bool = false
    @State private var ctrlMod: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Toggle("⌃", isOn: $ctrlMod)
                .toggleStyle(.button).font(.system(size: 11))
                .onChange(of: ctrlMod) { _ in saveMods() }
            Toggle("⌥", isOn: $optMod)
                .toggleStyle(.button).font(.system(size: 11))
                .onChange(of: optMod) { _ in saveMods() }
            Toggle("⇧", isOn: $shiftMod)
                .toggleStyle(.button).font(.system(size: 11))
                .onChange(of: shiftMod) { _ in saveMods() }
            Toggle("⌘", isOn: $cmdMod)
                .toggleStyle(.button).font(.system(size: 11))
                .onChange(of: cmdMod) { _ in saveMods() }

            Text("+").foregroundColor(.secondary)

            TextField("z", text: $keyChar)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .padding(7)
                .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.06)))
                .frame(width: 40)
                .onChange(of: keyChar) { v in
                    let filtered = String(v.prefix(1).lowercased())
                    if filtered != v { keyChar = filtered }
                    if !filtered.isEmpty {
                        entry.keyChar = filtered
                        onChanged()
                    }
                }
        }
        .onAppear {
            keyChar = entry.keyChar
            cmdMod   = entry.modifiers.contains("cmd")
            optMod   = entry.modifiers.contains("opt")
            shiftMod = entry.modifiers.contains("shift")
            ctrlMod  = entry.modifiers.contains("ctrl")
        }
    }

    private func saveMods() {
        var mods: [String] = []
        if ctrlMod  { mods.append("ctrl") }
        if optMod   { mods.append("opt") }
        if shiftMod { mods.append("shift") }
        if cmdMod   { mods.append("cmd") }
        entry.modifiers = mods
        onChanged()
    }
}
