//
//  ScreenshotSettingsView.swift
//  Orbit
//
//  Created by Auto on 2025.
//

import SwiftUI

struct ScreenshotSettingsView: View {
    @State private var deepSeekPrompt: String = UserDefaults.standard.string(forKey: "deepseekPrompt") ?? "Что изображено на этом скриншоте?"
    @State private var deepSeekApiKey: String = UserDefaults.standard.string(forKey: "deepseekApiKey") ?? ""
    @State private var telegramChatID: String = UserDefaults.standard.string(forKey: "telegramChatID") ?? ""
    @State private var showApiKey: Bool = false
    @State private var isCheckingBot: Bool = false
    @State private var botStatusMessage: String = ""
    @State private var isChatIDEditable: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Настройки скриншотов")
                    .font(.system(size: 20, weight: .bold))
                
                // Основное поле для Yandex токена (вместо ChatGPT)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("API Token для анализа скриншотов")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Text("(GPT-5.2 через Yandex)")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        SecureField("Введите ваш Yandex OAuth токен (SOY_TOKEN)", text: Binding(
                            get: { UserDefaults.standard.string(forKey: "yandexToken") ?? "" },
                            set: { UserDefaults.standard.set($0, forKey: "yandexToken") }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Этот токен используется для отправки скриншотов в GPT-5.2 через Yandex API")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("Формат: OAuth токен (например, из переменной $SOY_TOKEN)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
                
                Divider()
                
                // Альтернативные API (опционально)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Альтернативные API (опционально)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DeepSeek API Key")
                            .font(.system(size: 14, weight: .medium))
                
                HStack {
                    if showApiKey {
                        TextField("Введите API ключ", text: $deepSeekApiKey)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: deepSeekApiKey) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "deepseekApiKey")
                            }
                    } else {
                        SecureField("Введите API ключ", text: $deepSeekApiKey)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: deepSeekApiKey) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "deepseekApiKey")
                            }
                    }
                    
                    Button(action: {
                        showApiKey.toggle()
                    }) {
                        Image(systemName: showApiKey ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                        Text("Используется для текстовых запросов. Изображения сначала отправляются на бэкенд для OCR.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Промпт для анализа")
                        .font(.system(size: 14, weight: .medium))
                
                TextEditor(text: $deepSeekPrompt)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                    .onChange(of: deepSeekPrompt) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "deepseekPrompt")
                    }
                
                Text("Этот промпт будет использоваться при отправке каждого скриншота")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Telegram Chat ID")
                    .font(.system(size: 14, weight: .medium))
                
                HStack {
                    TextField("Chat ID", text: $telegramChatID)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!isChatIDEditable)
                        .onChange(of: telegramChatID) { newValue in
                            if !newValue.isEmpty && newValue.allSatisfy({ $0.isNumber || $0 == "-" }) {
                                UserDefaults.standard.set(newValue, forKey: "telegramChatID")
                            }
                        }
                    
                    if !isChatIDEditable {
                        Button("Изменить") {
                            isChatIDEditable = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                HStack {
                    Button(action: {
                        checkBotAndFetchChatID()
                    }) {
                        if isCheckingBot {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Проверить бота и получить Chat ID")
                        }
                    }
                    .buttonStyle(.bordered)
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
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Горячие клавиши")
                    .font(.system(size: 14, weight: .medium))
                
                HStack {
                    Text("⌘⌥S")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                    Text("Выбрать область для скриншотов")
                        .font(.system(size: 12))
                }
                
                HStack {
                    Text("⌘⌥C")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                    Text("Сделать скриншот и отправить в DeepSeek")
                        .font(.system(size: 12))
                }
            }
            
            }
            .padding(20)
        }
        .frame(width: 500)
        .frame(minHeight: 600)
    }
    
    private func loadChatID() {
        if let savedID = UserDefaults.standard.string(forKey: "telegramChatID"), !savedID.isEmpty {
            telegramChatID = savedID
            isChatIDEditable = false
        } else {
            telegramChatID = ""
            isChatIDEditable = true
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


