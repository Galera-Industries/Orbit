//
//  ResponsePanelView.swift
//  Orbit
//
//  Created by Auto on 2025.
//

import SwiftUI
import Combine
import AppKit // Не забудьте импортировать AppKit для работы с NSWindow

struct ResponsePanelView: View {
    @State private var chatgptResponse: String? = nil
    @State private var deepseekResponse: String? = nil
    @State private var timer: Timer?
    
    // Настройки из UserDefaults
    @State private var layoutMode: String = UserDefaults.standard.string(forKey: "responsePanelLayoutMode") ?? "horizontal"
    @AppStorage("responsePanelBackgroundType") private var backgroundType: String = "colored"
    @AppStorage("responsePanelTransparentMode") private var transparentMode: Bool = false
    
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
        // 👇 ДОБАВЛЯЕМ ЭТУ СТРОКУ, ЧТОБЫ СКРЫТЬ ОТ OBS 👇
        .background(OBSHiddenAccessor()) 
        // 👆 КОНЕЦ ИЗМЕНЕНИЙ 👆
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
                content: chatgpt,
                backgroundColor: Color(red: 0.2, green: 0.9, blue: 0.2),
                textColor: (transparentMode || backgroundType != "colored") ? .primary : .black
            )
        }
        
        if let deepseek = deepseekResponse, !deepseek.isEmpty {
            responseCard(
                title: "DeepSeek",
                content: deepseek,
                backgroundColor: .blue,
                textColor: (transparentMode || backgroundType != "colored") ? .primary : .white
            )
        }
        
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
        
        chatgptResponse = chatgptResponses.isEmpty ? nil : chatgptResponses.first
        deepseekResponse = deepseekResponses.isEmpty ? nil : deepseekResponses.first
        
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

// MARK: - Вспомогательная структура для скрытия от OBS

/// Этот компонент находит родительское окно NSWindow и отключает его шаринг (запись экрана)
struct OBSHiddenAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            // .none означает, что окно не будет отдаваться системе записи экрана
            view.window?.sharingType = .none
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // На случай, если окно пересоздалось, пробуем установить флаг снова
        DispatchQueue.main.async {
             nsView.window?.sharingType = .none
        }
    }
}
