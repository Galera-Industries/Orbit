//
//  ScreenshotManager.swift
//  Orbit
//
//  Created by Auto on 2025.
//

import Foundation
import AppKit

final class ScreenshotManager {
    static let shared = ScreenshotManager()
    
    private let areaSelector = ScreenshotAreaSelector.shared
    private let screenshotService = ScreenshotService.shared
    private let deepSeekService = DeepSeekService.shared
    private let telegramService = TelegramBotService.shared
    private let vkService = VKService.shared
    
    private init() {}
    
    func selectArea() {
        print("🎯 ScreenshotManager.selectArea() called")
        areaSelector.selectArea { [weak self] rect in
            if let rect = rect {
                print("✅ Area selected: \(rect)")
            } else {
                print("❌ Area selection cancelled or failed")
            }
        }
    }

    
    func captureAndSend() {
        guard let screenshotArea = areaSelector.savedArea else {
            print("⚠️ Область не выбрана")
            return
        }
        
        print("📸 Начинаю захват области: \(screenshotArea.rect) на экране \(screenshotArea.displayID)")
        
        // Скрываем ВСЁ приложение Orbit
        NSApp.hide(nil)
        
        // Ждём пока система перерисует экран без Orbit
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.performCapture(area: screenshotArea)
        }
    }
    
    private func performCapture(area: ScreenshotAreaSelector.ScreenshotArea) {
        // Используем правильный displayID для захвата
        let displayID = area.displayID
        
        guard let fullScreenImage = CGDisplayCreateImage(displayID) else {
            print("⚠️ Не удалось создать скриншот экрана \(displayID)")
            return
        }
        
        // Находим экран по displayID для получения его frame
        guard let screen = NSScreen.screens.first(where: { screen in
            let screenDisplayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            return screenDisplayID == displayID
        }) else {
            print("⚠️ Не удалось найти экран с displayID \(displayID)")
            return
        }
        
        let screenFrame = screen.frame
        let scaleX = CGFloat(fullScreenImage.width) / screenFrame.width
        let scaleY = CGFloat(fullScreenImage.height) / screenFrame.height
        
        // Координаты area.rect уже в глобальной системе координат macOS
        // Нужно преобразовать их в координаты относительно экрана
        let areaRelativeToScreen = CGRect(
            x: area.rect.origin.x - screenFrame.origin.x,
            y: area.rect.origin.y - screenFrame.origin.y,
            width: area.rect.width,
            height: area.rect.height
        )
        
        // Переворачиваем Y (macOS: origin внизу, CGImage: origin вверху)
        let flippedY = screenFrame.height - areaRelativeToScreen.origin.y - areaRelativeToScreen.height
        
        let cropRect = CGRect(
            x: areaRelativeToScreen.origin.x * scaleX,
            y: flippedY * scaleY,
            width: areaRelativeToScreen.width * scaleX,
            height: areaRelativeToScreen.height * scaleY
        )
        
        print("📐 Screen: \(screenFrame), Scale: \(scaleX)x\(scaleY)")
        print("📐 Area (global macOS): \(area.rect)")
        print("📐 Area (relative to screen): \(areaRelativeToScreen)")
        print("📐 Crop rect: \(cropRect)")
        
        let finalImage: NSImage
        if let croppedCGImage = fullScreenImage.cropping(to: cropRect) {
            finalImage = NSImage(cgImage: croppedCGImage, size: area.rect.size)
            print("📸 Вырезано: \(croppedCGImage.width)x\(croppedCGImage.height)")
        } else {
            finalImage = NSImage(cgImage: fullScreenImage, size: screenFrame.size)
            print("⚠️ Не удалось вырезать, используем полный экран")
        }
        
        // Сохраняем для отладки
        _ = screenshotService.saveImageForDebugging(finalImage, suffix: "captured")
        
        guard let base64String = screenshotService.imageToBase64(finalImage) else {
            print("⚠️ Не удалось конвертировать")
            return
        }
        
        print("✅ Base64 размер: \(base64String.count) символов")
        
        let enableAISending = UserDefaults.standard.bool(forKey: "enableAISending")
//        guard enableAISending else {
//            print("⏸️ AI отключен, скриншот сохранён")
//            return
//        }
        
        let prompt = UserDefaults.standard.string(forKey: "deepseekPrompt") ?? "Что изображено?"
        
        // Проверяем наличие хотя бы одного ключа
        guard deepSeekService.hasChatGPTToken || deepSeekService.hasDeepSeekKey else {
            print("⚠️ Нет доступных API ключей (ChatGPT или DeepSeek)")
            return
        }
        
        // Отправляем скриншот в оба сервиса (если есть ключи)
        var chatgptResponse: String? = nil
        var deepseekResponse: String? = nil
        var chatgptError: Error? = nil
        var deepseekError: Error? = nil
        
        let group = DispatchGroup()
        
        // Отправляем в ChatGPT через got_proxy
        if deepSeekService.hasChatGPTToken {
            group.enter()
            print("📤 Отправляю скриншот в ChatGPT (got_proxy)...")
            deepSeekService.sendToChatGPT(imageBase64: base64String, prompt: prompt) { result in
                switch result {
                case .success(let response):
                    chatgptResponse = response
                    print("✅ ChatGPT ответ получен: \(response.prefix(100))...")
                case .failure(let error):
                    chatgptError = error
                    print("❌ ChatGPT ошибка: \(error)")
                }
                group.leave()
            }
        }
        
        
        // Ждем завершения всех запросов
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Отправляем отдельные ответы в Telegram и VK
            if let chatgpt = chatgptResponse {
                self.sendToMessengers(message: "🤖 *ChatGPT*\n\n\(chatgpt)", serviceName: "ChatGPT")
            }
            
            if let deepseek = deepseekResponse {
                // Небольшая задержка между сообщениями, чтобы они шли по порядку
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.sendToMessengers(message: "🔵 *DeepSeek*\n\n\(deepseek)", serviceName: "DeepSeek")
                }
            }
            
            // Отправляем комбинированное сообщение в VK после небольшой задержки
            if chatgptResponse != nil || deepseekResponse != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.sendCombinedMessageToVK(chatgpt: chatgptResponse, deepseek: deepseekResponse)
                }
            }
            
            // Отправляем ответы на бэкенд для Apple Watch
            if chatgptResponse != nil || deepseekResponse != nil {
                self.sendResponsesToBackend(chatgpt: chatgptResponse, deepseek: deepseekResponse)
            }
            
            // Сохраняем ответы
            if let chatgpt = chatgptResponse {
                self.saveResponse(chatgpt, type: "chatgpt")
            }
            if let deepseek = deepseekResponse {
                self.saveResponse(deepseek, type: "deepseek")
            }
            
            // Если оба запроса завершились с ошибкой
            if chatgptResponse == nil && deepseekResponse == nil {
                let errorMessage = "Ошибки при получении ответов:\n"
                var errors: [String] = []
                if let chatgptErr = chatgptError {
                    errors.append("ChatGPT: \(chatgptErr.localizedDescription)")
                }
                if let deepseekErr = deepseekError {
                    errors.append("DeepSeek: \(deepseekErr.localizedDescription)")
                }
                if errors.isEmpty {
                    errors.append("Нет доступных API ключей")
                }
                print("❌ \(errorMessage)\(errors.joined(separator: "\n"))")
            }
        }
    }
    
    // Используем typealias для удобства
    typealias ScreenshotArea = ScreenshotAreaSelector.ScreenshotArea
    
    /// Отправляет сообщение в Telegram и VK (если настроены)
    private func sendToMessengers(message: String, serviceName: String) {
        // Отправляем в Telegram
        print("📱 Отправляю ответ \(serviceName) в Telegram...")
        telegramService.sendMessage(message) { result in
            switch result {
            case .success:
                print("✅ \(serviceName) ответ отправлен в Telegram")
            case .failure(let error):
                print("❌ Ошибка отправки \(serviceName) в Telegram: \(error)")
            }
        }
        
        // Отправляем в VK (отдельное сообщение)
        print("📱 Отправляю ответ \(serviceName) в VK...")
        vkService.sendMessage(message.replacingOccurrences(of: "*", with: "")) { result in
            switch result {
            case .success:
                print("✅ \(serviceName) ответ отправлен в VK")
            case .failure(let error):
                print("❌ Ошибка отправки \(serviceName) в VK: \(error)")
            }
        }
    }
    
    /// Отправляет комбинированное сообщение с двумя столбцами в VK
    private func sendCombinedMessageToVK(chatgpt: String?, deepseek: String?) {
        // Формируем сообщение с двумя столбцами
        var combinedMessage = ""
        
        if let chatgpt = chatgpt, let deepseek = deepseek {
            // Оба ответа есть - формируем столбцы построчно
            let chatgptLines = chatgpt.components(separatedBy: .newlines).filter { !$0.isEmpty }
            let deepseekLines = deepseek.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            let maxLines = max(chatgptLines.count, deepseekLines.count)
            var lines: [String] = []
            
            for i in 0..<maxLines {
                let chatgptLine = i < chatgptLines.count ? chatgptLines[i] : ""
                let deepseekLine = i < deepseekLines.count ? deepseekLines[i] : ""
                
                if !chatgptLine.isEmpty && !deepseekLine.isEmpty {
                    lines.append("\(chatgptLine) | \(deepseekLine)")
                } else if !chatgptLine.isEmpty {
                    lines.append(chatgptLine)
                } else if !deepseekLine.isEmpty {
                    lines.append(deepseekLine)
                }
            }
            
            combinedMessage = lines.joined(separator: "\n")
        } else if let chatgpt = chatgpt {
            combinedMessage = chatgpt
        } else if let deepseek = deepseek {
            combinedMessage = deepseek
        } else {
            return // Нет данных для отправки
        }
        
        print("📱 Отправляю комбинированное сообщение (столбцы) в VK...")
        vkService.sendMessage(combinedMessage) { result in
            switch result {
            case .success:
                print("✅ Комбинированное сообщение отправлено в VK")
            case .failure(let error):
                print("❌ Ошибка отправки комбинированного сообщения в VK: \(error)")
            }
        }
    }
    
    private func saveResponse(_ response: String, type: String = "deepseek") {
        // Сохраняем в стандартный UserDefaults (так панель сможет их прочитать напрямую)
        let defaults = UserDefaults.standard
        let key = type == "chatgpt" ? "chatgptResponses" : "deepseekResponses"
        var responses = defaults.stringArray(forKey: key) ?? []
        responses.insert(response, at: 0) // Вставляем в начало (самый свежий ответ)
        if responses.count > 50 { responses = Array(responses.prefix(50)) }
        defaults.set(responses, forKey: key)
        
        // Также сохраняем в App Group для совместимости с Apple Watch (если есть)
        if let groupDefaults = UserDefaults(suiteName: "group.com.orbit.app") {
            groupDefaults.set(responses, forKey: key)
        }
        
        print("✅ Ответ сохранен в UserDefaults: \(type), длина: \(response.count) символов")
        NotificationCenter.default.post(name: .newDeepSeekResponse, object: response)
    }
    
    private func sendResponsesToBackend(chatgpt: String?, deepseek: String?) {
        guard let url = URL(string: "http://158.160.149.37:8000/responses") else {
            print("⚠️ Неверный URL бэкенда")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let channelNumber = UserDefaults.standard.string(forKey: "watchChannelNumber") ?? "1"
        
        let body: [String: Any?] = [
            "chatgpt": chatgpt,
            "deepseek": deepseek,
            "channel": channelNumber
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Ошибка отправки ответов на бэкенд: \(error)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        print("✅ Ответы успешно отправлены на бэкенд")
                    } else {
                        print("⚠️ Бэкенд вернул статус: \(httpResponse.statusCode)")
                    }
                }
            }.resume()
        } catch {
            print("❌ Ошибка сериализации JSON: \(error)")
        }
    }
}

extension Notification.Name {
    static let newDeepSeekResponse = Notification.Name("newDeepSeekResponse")
}

