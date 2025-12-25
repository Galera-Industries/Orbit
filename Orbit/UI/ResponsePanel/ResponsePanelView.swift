//
//  ResponsePanelView.swift
//  Orbit
//
//  Created by Auto on 2025.
//

import SwiftUI
import Combine

struct ResponsePanelView: View {
    @State private var chatgptResponse: String? = nil
    @State private var deepseekResponse: String? = nil
    @State private var timer: Timer?
    
    // Настройки из UserDefaults
    @State private var layoutMode: String = UserDefaults.standard.string(forKey: "responsePanelLayoutMode") ?? "horizontal"
    @AppStorage("responsePanelBackgroundType") private var backgroundType: String = "colored" // "colored" or "blurred" - второй режим
    @AppStorage("responsePanelTransparentMode") private var transparentMode: Bool = false // true = прозрачный, false = второй режим
    
    var body: some View {
        Group {
            if layoutMode == "horizontal" {
                // Горизонтальное разделение (вертикальная компоновка: ChatGPT сверху, DeepSeek снизу)
                VStack(spacing: 0) {
                    responseContent
                }
            } else {
                // Вертикальное разделение (горизонтальная компоновка: ChatGPT слева, DeepSeek справа)
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
            // Периодически проверяем обновления
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
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    // Свайп влево/вправо переключает режим отображения
                    if abs(value.translation.width) > abs(value.translation.height) {
                        if value.translation.width > 30 {
                            // Свайп вправо - горизонтальный режим (вертикальная компоновка)
                            layoutMode = "horizontal"
                            UserDefaults.standard.set("horizontal", forKey: "responsePanelLayoutMode")
                        } else if value.translation.width < -30 {
                            // Свайп влево - вертикальный режим (горизонтальная компоновка)
                            layoutMode = "vertical"
                            UserDefaults.standard.set("vertical", forKey: "responsePanelLayoutMode")
                        }
                    }
                }
        )
    }
    
    @ViewBuilder
    private var responseContent: some View {
        // ChatGPT ответ (зеленый фон)
        if let chatgpt = chatgptResponse, !chatgpt.isEmpty {
            responseCard(
                title: "ChatGPT",
                content: chatgpt,
                backgroundColor: Color(red: 0.2, green: 0.9, blue: 0.2),
                textColor: (transparentMode || backgroundType != "colored") ? .primary : .black
            )
        }
        
        // DeepSeek ответ (синий фон)
        if let deepseek = deepseekResponse, !deepseek.isEmpty {
            responseCard(
                title: "DeepSeek",
                content: deepseek,
                backgroundColor: .blue,
                textColor: (transparentMode || backgroundType != "colored") ? .primary : .white
            )
        }
        
        // Если нет данных
        if chatgptResponse == nil && deepseekResponse == nil {
            Text("Ожидание ответов...")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private func responseCard(title: String, content: String, backgroundColor: Color, textColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(textColor.opacity(0.9))
            
            ScrollView {
                Text(content)
                    .font(.system(size: 9))
                    .foregroundColor(textColor)
                    .textSelection(.enabled)
            }
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
                    // Прозрачный режим - полностью прозрачный фон
                    Color.clear
                } else if backgroundType == "colored" {
                    // Второй режим - цветной фон
                    backgroundColor
                } else {
                    // Второй режим - размытый фон
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow, state: .active)
                }
            }
        )
    }
    
    private func loadResponses() {
        // Используем стандартный UserDefaults напрямую (как и ScreenshotManager)
        let defaults = UserDefaults.standard
        
        // Получаем последние ответы (первый элемент массива - самый свежий, так как используется insert at: 0)
        let chatgptResponses = defaults.stringArray(forKey: "chatgptResponses") ?? []
        let deepseekResponses = defaults.stringArray(forKey: "deepseekResponses") ?? []
        
        // Всегда обновляем (чтобы отразить изменения)
        chatgptResponse = chatgptResponses.isEmpty ? nil : chatgptResponses.first
        deepseekResponse = deepseekResponses.isEmpty ? nil : deepseekResponses.first
        
        // Также обновляем layoutMode из UserDefaults (на случай изменения в настройках или горячих клавиш)
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
        // Переключаем между прозрачным и вторым режимом
        transparentMode.toggle()
        UserDefaults.standard.set(transparentMode, forKey: "responsePanelTransparentMode")
    }
}

