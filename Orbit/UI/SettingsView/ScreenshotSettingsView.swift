//
//  ScreenshotSettingsView.swift
//  Orbit
//
//  Created by Auto on 2025.
//

import SwiftUI

struct ScreenshotSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var deepSeekPrompt: String = UserDefaults.standard.string(forKey: "deepseekPrompt") ?? "Что изображено на этом скриншоте?"
    @State private var systemMessage: String = UserDefaults.standard.string(forKey: "systemMessage") ?? ""
    @State private var deepSeekApiKey: String = UserDefaults.standard.string(forKey: "deepseekApiKey") ?? ""
    @State private var telegramBotToken: String = UserDefaults.standard.string(forKey: "telegramBotToken") ?? ""
    @State private var telegramChatID: String = UserDefaults.standard.string(forKey: "telegramChatID") ?? ""
    @State private var vkAccessToken: String = UserDefaults.standard.string(forKey: "vkAccessToken") ?? ""
    @State private var vkPeerID: String = UserDefaults.standard.string(forKey: "vkPeerID") ?? ""
    @State private var watchChannelNumber: String = UserDefaults.standard.string(forKey: "watchChannelNumber") ?? "1"
    @State private var showApiKey: Bool = false
    @State private var showBotToken: Bool = false
    @State private var showVkToken: Bool = false
    @State private var isCheckingBot: Bool = false
    @State private var botStatusMessage: String = ""
    @State private var isChatIDEditable: Bool = false
    @State private var isCheckingVk: Bool = false
    @State private var vkStatusMessage: String = ""
    @State private var isCloseButtonHovered: Bool = false
    
    var body: some View {
        GlassPanel {
            VStack(spacing: 0) {
                headerView
                Divider()
                    .padding(.horizontal, 20)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        chatGPTTokenSection
                        deepSeekApiKeySection
                        promptSection
                        systemMessageSection
                        telegramBotTokenSection
                        telegramChatIDSection
                        vkAccessTokenSection
                        vkPeerIDSection
                        watchChannelSection
                        responsePanelSection
                        hotkeysSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
        }
        .frame(width: 600)
        .frame(minHeight: 500)
        .presentationBackground(.clear)
    }
    
    private var headerView: some View {
        HStack {
            Text("Screenshot Settings")
                .font(.system(size: 18, weight: .semibold))
            Spacer()
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .opacity(isCloseButtonHovered ? 1.0 : 0.6)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isCloseButtonHovered = hovering
                }
            }
            .help("Закрыть (Esc)")
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    private var chatGPTTokenSection: some View {
        SettingsSection(title: "API Token для анализа скриншотов", subtitle: "ChatGPT через got_proxy") {
            SecureField("Введите ваш OpenAI API ключ", text: Binding(
                get: { UserDefaults.standard.string(forKey: "chatGPTToken") ?? "" },
                set: { UserDefaults.standard.set($0, forKey: "chatGPTToken") }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.06)))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Этот токен используется для отправки скриншотов в ChatGPT через got_proxy (5.34.212.145:8000)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("Формат: OpenAI API ключ (начинается с sk-)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
    }
    
    private var deepSeekApiKeySection: some View {
        SettingsSection(title: "DeepSeek API Key", subtitle: "Альтернативные API (опционально)") {
            HStack(spacing: 8) {
                Group {
                    if showApiKey {
                        TextField("Введите API ключ", text: $deepSeekApiKey)
                            .onChange(of: deepSeekApiKey) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "deepseekApiKey")
                            }
                    } else {
                        SecureField("Введите API ключ", text: $deepSeekApiKey)
                            .onChange(of: deepSeekApiKey) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "deepseekApiKey")
                            }
                    }
                }
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.06)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showApiKey.toggle()
                    }
                }) {
                    Image(systemName: showApiKey ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
            
            Text("Используется для текстовых запросов.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
    
    private var promptSection: some View {
        SettingsSection(title: "Промпт для анализа", subtitle: "User message") {
            TextEditor(text: $deepSeekPrompt)
                .frame(height: 100)
                .font(.system(size: 13))
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.06)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
                .onChange(of: deepSeekPrompt) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "deepseekPrompt")
                }
            
            Text("Этот промпт будет использоваться как user message при отправке каждого скриншота")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
    
    private var systemMessageSection: some View {
        SettingsSection(title: "System Message", subtitle: "Опционально") {
            TextEditor(text: $systemMessage)
                .frame(height: 100)
                .font(.system(size: 13))
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.06)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
                .onChange(of: systemMessage) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "systemMessage")
                }
            
            Text("Системное сообщение для настройки поведения модели (опционально). Если пусто, system message не будет отправляться.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
    
    private var telegramBotTokenSection: some View {
        SettingsSection(title: "Telegram Bot Token") {
            HStack(spacing: 8) {
                Group {
                    if showBotToken {
                        TextField("Bot Token", text: $telegramBotToken)
                            .onChange(of: telegramBotToken) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "telegramBotToken")
                            }
                    } else {
                        SecureField("Bot Token", text: $telegramBotToken)
                            .onChange(of: telegramBotToken) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "telegramBotToken")
                            }
                    }
                }
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.06)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showBotToken.toggle()
                    }
                }) {
                    Image(systemName: showBotToken ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
            
            Text("Токен бота Telegram (получите у @BotFather)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
    
    private var telegramChatIDSection: some View {
        SettingsSection(title: "Telegram Chat ID") {
            HStack(spacing: 8) {
                TextField("Chat ID", text: $telegramChatID)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.06)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
                    .disabled(!isChatIDEditable)
                    .onChange(of: telegramChatID) { newValue in
                        if !newValue.isEmpty && newValue.allSatisfy({ $0.isNumber || $0 == "-" }) {
                            UserDefaults.standard.set(newValue, forKey: "telegramChatID")
                        }
                    }
                
                if !isChatIDEditable {
                    Button("Изменить") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isChatIDEditable = true
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.08)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
                }
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    checkBotAndFetchChatID()
                }) {
                    HStack(spacing: 6) {
                        if isCheckingBot {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 12))
                        }
                        Text("Проверить бота и получить Chat ID")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.08)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isCheckingBot)
                
                if !botStatusMessage.isEmpty {
                    Text(botStatusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(botStatusMessage.contains("успешно") ? .green : .red)
                }
            }
            
            Text("Отправьте любое сообщение боту в Telegram, затем нажмите кнопку выше")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .onAppear {
            loadChatID()
        }
    }
    
    private var vkAccessTokenSection: some View {
        SettingsSection(title: "VK Access Token") {
            HStack(spacing: 8) {
                Group {
                    if showVkToken {
                        TextField("Access Token", text: $vkAccessToken)
                            .onChange(of: vkAccessToken) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "vkAccessToken")
                            }
                    } else {
                        SecureField("Access Token", text: $vkAccessToken)
                            .onChange(of: vkAccessToken) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "vkAccessToken")
                            }
                    }
                }
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.06)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showVkToken.toggle()
                    }
                }) {
                    Image(systemName: showVkToken ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
            
            Text("Токен доступа VK API (получите на https://vk.com/dev)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
    
    private var vkPeerIDSection: some View {
        SettingsSection(title: "VK Peer ID") {
            TextField("Peer ID", text: $vkPeerID)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.06)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
                .onChange(of: vkPeerID) { newValue in
                    if !newValue.isEmpty && newValue.allSatisfy({ $0.isNumber || $0 == "-" }) {
                        UserDefaults.standard.set(newValue, forKey: "vkPeerID")
                    }
                }
            
            HStack(spacing: 12) {
                Button(action: {
                    checkVkToken()
                }) {
                    HStack(spacing: 6) {
                        if isCheckingVk {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 12))
                        }
                        Text("Проверить токен VK")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.08)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isCheckingVk)
                
                if !vkStatusMessage.isEmpty {
                    Text(vkStatusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(vkStatusMessage.contains("успешно") ? .green : .red)
                }
            }
            
            Text("ID пользователя или беседы, куда отправлять сообщения. Для личных сообщений используйте ваш user_id")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .onAppear {
            loadVkSettings()
        }
    }
    
    private var watchChannelSection: some View {
        SettingsSection(title: "Номер канала для Apple Watch", subtitle: "Канал, который слушают часы") {
            TextField("Номер канала", text: $watchChannelNumber)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.06)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
                .onChange(of: watchChannelNumber) { newValue in
                    // Оставляем только цифры
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue {
                        watchChannelNumber = filtered
                    } else {
                        UserDefaults.standard.set(filtered.isEmpty ? "1" : filtered, forKey: "watchChannelNumber")
                    }
                }
            
            Text("Этот номер канала будет отправляться на бэкенд вместе с ответами. Убедитесь, что он совпадает с номером канала в настройках Apple Watch.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
    
    private var responsePanelSection: some View {
        SettingsSection(title: "Панель ответов", subtitle: "Маленькое окно для просмотра ответов") {
            // Позиция
            VStack(alignment: .leading, spacing: 8) {
                Text("Позиция на экране")
                    .font(.system(size: 12, weight: .medium))
                
                Picker("", selection: Binding(
                    get: { 
                        let pos = UserDefaults.standard.string(forKey: "responsePanelPosition") ?? "right-top"
                        // Миграция старых значений
                        if pos == "left" { return "left-top" }
                        if pos == "right" { return "right-top" }
                        return pos
                    },
                    set: { 
                        UserDefaults.standard.set($0, forKey: "responsePanelPosition")
                        ResponsePanelManager.shared.updatePanel()
                    }
                )) {
                    Text("Правый верхний угол").tag("right-top")
                    Text("Левый верхний угол").tag("left-top")
                    Text("Правый нижний угол").tag("right-bottom")
                    Text("Левый нижний угол").tag("left-bottom")
                }
                .pickerStyle(.menu)
            }
            
            // Размер
            VStack(alignment: .leading, spacing: 8) {
                Text("Размер панели")
                    .font(.system(size: 12, weight: .medium))
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ширина")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        TextField("Ширина", value: Binding(
                            get: { 
                                let width = UserDefaults.standard.double(forKey: "responsePanelWidth")
                                return width > 0 ? width : 50
                            },
                            set: { 
                                UserDefaults.standard.set($0, forKey: "responsePanelWidth")
                                ResponsePanelManager.shared.updatePanel()
                            }
                        ), format: .number)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.06)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                        .frame(width: 80)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Высота")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        TextField("Высота", value: Binding(
                            get: { 
                                let height = UserDefaults.standard.double(forKey: "responsePanelHeight")
                                return height > 0 ? height : 50
                            },
                            set: { 
                                UserDefaults.standard.set($0, forKey: "responsePanelHeight")
                                ResponsePanelManager.shared.updatePanel()
                            }
                        ), format: .number)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.06)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                        .frame(width: 80)
                    }
                }
            }
            
            // Горячие клавиши
            VStack(alignment: .leading, spacing: 8) {
                Text("Горячие клавиши для показа/скрытия")
                    .font(.system(size: 12, weight: .medium))
                
                HStack(spacing: 8) {
                    // Модификаторы
                    Toggle("⌘", isOn: Binding(
                        get: { 
                            let mods = UserDefaults.standard.stringArray(forKey: "responsePanelHotkeyModifiers") ?? ["cmd", "opt"]
                            return mods.contains("cmd")
                        },
                        set: { 
                            var mods = UserDefaults.standard.stringArray(forKey: "responsePanelHotkeyModifiers") ?? ["opt"]
                            if $0 {
                                if !mods.contains("cmd") { mods.append("cmd") }
                            } else {
                                mods.removeAll { $0 == "cmd" }
                            }
                            UserDefaults.standard.set(mods, forKey: "responsePanelHotkeyModifiers")
                            ResponsePanelManager.shared.updateHotkey()
                        }
                    ))
                    .toggleStyle(.button)
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    
                    Toggle("⌥", isOn: Binding(
                        get: { 
                            let mods = UserDefaults.standard.stringArray(forKey: "responsePanelHotkeyModifiers") ?? ["cmd", "opt"]
                            return mods.contains("opt")
                        },
                        set: { 
                            var mods = UserDefaults.standard.stringArray(forKey: "responsePanelHotkeyModifiers") ?? ["cmd"]
                            if $0 {
                                if !mods.contains("opt") { mods.append("opt") }
                            } else {
                                mods.removeAll { $0 == "opt" }
                            }
                            UserDefaults.standard.set(mods, forKey: "responsePanelHotkeyModifiers")
                            ResponsePanelManager.shared.updateHotkey()
                        }
                    ))
                    .toggleStyle(.button)
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    
                    Toggle("⇧", isOn: Binding(
                        get: { 
                            let mods = UserDefaults.standard.stringArray(forKey: "responsePanelHotkeyModifiers") ?? ["cmd", "opt"]
                            return mods.contains("shift")
                        },
                        set: { 
                            var mods = UserDefaults.standard.stringArray(forKey: "responsePanelHotkeyModifiers") ?? ["cmd", "opt"]
                            if $0 {
                                if !mods.contains("shift") { mods.append("shift") }
                            } else {
                                mods.removeAll { $0 == "shift" }
                            }
                            UserDefaults.standard.set(mods, forKey: "responsePanelHotkeyModifiers")
                            ResponsePanelManager.shared.updateHotkey()
                        }
                    ))
                    .toggleStyle(.button)
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    
                    // Клавиша
                    TextField("R", text: Binding(
                        get: { UserDefaults.standard.string(forKey: "responsePanelHotkeyKey") ?? "r" },
                        set: { newValue in
                            let filtered = String(newValue.prefix(1).lowercased())
                            UserDefaults.standard.set(filtered, forKey: "responsePanelHotkeyKey")
                            ResponsePanelManager.shared.updateHotkey()
                        }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.06)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
                    .frame(width: 50)
                }
            }
            
            // Режим отображения
            VStack(alignment: .leading, spacing: 8) {
                Text("Режим отображения")
                    .font(.system(size: 12, weight: .medium))
                
                Picker("", selection: Binding(
                    get: { UserDefaults.standard.string(forKey: "responsePanelLayoutMode") ?? "horizontal" },
                    set: { 
                        UserDefaults.standard.set($0, forKey: "responsePanelLayoutMode")
                    }
                )) {
                    Text("Горизонтальный (вертикально)").tag("horizontal")
                    Text("Вертикальный (горизонтально)").tag("vertical")
                }
                .pickerStyle(.menu)
            }
            
            // Тип фона для ответов (второй режим)
            VStack(alignment: .leading, spacing: 8) {
                Text("Второй режим (⌘⌥B переключает между прозрачным и этим)")
                    .font(.system(size: 12, weight: .medium))
                
                Picker("", selection: Binding(
                    get: { UserDefaults.standard.string(forKey: "responsePanelBackgroundType") ?? "colored" },
                    set: { UserDefaults.standard.set($0, forKey: "responsePanelBackgroundType") }
                )) {
                    Text("Цветной").tag("colored")
                    Text("Размытый").tag("blurred")
                }
                .pickerStyle(.segmented)
                
                Text("⌘⌥B переключает между прозрачным режимом (полностью прозрачный фон) и выбранным вторым режимом.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            // Горячие клавиши
            VStack(alignment: .leading, spacing: 8) {
                Text("Горячие клавиши")
                    .font(.system(size: 12, weight: .medium))
                
                HStack(spacing: 12) {
                    Text("⌘⌥R")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.08)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                    Text("Показать/скрыть панель")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    Text("⌘⌥L")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.08)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                    Text("Переключить режим (горизонтальный/вертикальный)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    Text("⌘⌥B")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.08)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                    Text("Переключить тип фона (цветной/размытый)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Text("По умолчанию: ⌘⌥R. Панель отображает последние ответы от ChatGPT и DeepSeek, как в Apple Watch приложении. Также можно переключать режим жестом (свайп влево/вправо). ⌘⌥B переключает между цветным и размытым фоном.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
    
    private var hotkeysSection: some View {
        SettingsSection(title: "Горячие клавиши") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("⌘⌥S")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.08)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                    Text("Выбрать область для скриншотов")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    Text("⌘⌥C")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.08)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                    Text("Сделать скриншот и отправить в DeepSeek")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    struct SettingsSection<Content: View>: View {
        let title: String
        var subtitle: String? = nil
        @ViewBuilder let content: () -> Content
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                
                content()
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.06)))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private func loadChatID() {
        if let savedToken = UserDefaults.standard.string(forKey: "telegramBotToken"), !savedToken.isEmpty {
            telegramBotToken = savedToken
        } else {
            telegramBotToken = ""
        }
        
        if let savedID = UserDefaults.standard.string(forKey: "telegramChatID"), !savedID.isEmpty {
            telegramChatID = savedID
            isChatIDEditable = false
        } else {
            telegramChatID = ""
            isChatIDEditable = true
        }
    }
    
    private func loadVkSettings() {
        if let savedToken = UserDefaults.standard.string(forKey: "vkAccessToken"), !savedToken.isEmpty {
            vkAccessToken = savedToken
        } else {
            vkAccessToken = ""
        }
        
        if let savedPeerID = UserDefaults.standard.string(forKey: "vkPeerID"), !savedPeerID.isEmpty {
            vkPeerID = savedPeerID
        } else {
            vkPeerID = ""
        }
    }
    
    private func checkVkToken() {
        isCheckingVk = true
        vkStatusMessage = ""
        
        VKService.shared.checkTokenStatus { result in
            DispatchQueue.main.async {
                self.isCheckingVk = false
                switch result {
                case .success(let ok):
                    if ok {
                        self.vkStatusMessage = "Токен VK валидный"
                    } else {
                        self.vkStatusMessage = "Токен не валидный"
                    }
                case .failure(let error):
                    self.vkStatusMessage = "Ошибка: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func checkBotAndFetchChatID() {
        isCheckingBot = true
        botStatusMessage = ""
        
        // Сначала проверяем, что бот работает
        TelegramBotService.shared.checkBotStatus { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ok):
                    if ok {
                        self.botStatusMessage = "Бот работает. Получаю Chat ID..."
                        // Затем пытаемся получить chat_id
                        TelegramBotService.shared.fetchChatID { chatResult in
                            DispatchQueue.main.async {
                                self.isCheckingBot = false
                                switch chatResult {
                                case .success(let chatID):
                                    self.telegramChatID = chatID
                                    self.botStatusMessage = "Chat ID успешно получен: \(chatID)"
                                    self.isChatIDEditable = false
                                case .failure(let error):
                                    self.botStatusMessage = "Ошибка: \(error.localizedDescription). Отправьте сообщение боту и попробуйте снова."
                                }
                            }
                        }
                    } else {
                        self.isCheckingBot = false
                        self.botStatusMessage = "Бот не отвечает"
                    }
                case .failure(let error):
                    self.isCheckingBot = false
                    self.botStatusMessage = "Ошибка проверки бота: \(error.localizedDescription)"
                }
            }
        }
    }
}


