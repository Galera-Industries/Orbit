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
        guard deepSeekService.hasYandexToken || deepSeekService.hasDeepSeekKey else {
            print("⚠️ Нет доступных API ключей (Yandex или DeepSeek)")
            return
        }
        
        // Отправляем скриншот в оба сервиса (если есть ключи)
        var chatgptResponse: String? = nil
        var deepseekResponse: String? = nil
        var chatgptError: Error? = nil
        var deepseekError: Error? = nil
        
        let group = DispatchGroup()
        
        // Отправляем в Yandex (ChatGPT через GPT-5.2)
        if deepSeekService.hasYandexToken {
            group.enter()
            print("📤 Отправляю скриншот в Yandex (ChatGPT)...")
            deepSeekService.sendToYandex(imageBase64: base64String, prompt: prompt) { result in
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
        
        // Отправляем в DeepSeek (через бэкенд OCR)
        if deepSeekService.hasDeepSeekKey {
            group.enter()
            print("📤 Отправляю скриншот в DeepSeek (через бэкенд OCR)...")
            deepSeekService.sendToDeepSeekViaBackend(imageBase64: base64String, prompt: prompt) { result in
                switch result {
                case .success(let response):
                    deepseekResponse = response
                    print("✅ DeepSeek ответ получен: \(response.prefix(100))...")
                case .failure(let error):
                    deepseekError = error
                    print("❌ DeepSeek ошибка: \(error)")
                }
                group.leave()
            }
        }
        
        // Ждем завершения всех запросов
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Отправляем ответы в Telegram (первое сообщение от ChatGPT, второе от DeepSeek)
            if let chatgpt = chatgptResponse {
                print("📱 Отправляю ответ ChatGPT в Telegram...")
                self.telegramService.sendMessage("🤖 *ChatGPT*\n\n\(chatgpt)") { result in
                    switch result {
                    case .success:
                        print("✅ ChatGPT ответ отправлен в Telegram")
                    case .failure(let error):
                        print("❌ Ошибка отправки ChatGPT в Telegram: \(error)")
                    }
                }
            }
            
            if let deepseek = deepseekResponse {
                // Небольшая задержка между сообщениями, чтобы они шли по порядку
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("📱 Отправляю ответ DeepSeek в Telegram...")
                    self.telegramService.sendMessage("🔵 *DeepSeek*\n\n\(deepseek)") { result in
                        switch result {
                        case .success:
                            print("✅ DeepSeek ответ отправлен в Telegram")
                        case .failure(let error):
                            print("❌ Ошибка отправки DeepSeek в Telegram: \(error)")
                        }
                    }
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
    
    private func saveResponse(_ response: String, type: String = "deepseek") {
        let defaults = UserDefaults(suiteName: "group.com.orbit.app") ?? .standard
        let key = type == "chatgpt" ? "chatgptResponses" : "deepseekResponses"
        var responses = defaults.stringArray(forKey: key) ?? []
        responses.insert(response, at: 0)
        if responses.count > 50 { responses = Array(responses.prefix(50)) }
        defaults.set(responses, forKey: key)
        NotificationCenter.default.post(name: .newDeepSeekResponse, object: response)
    }
    
    private func sendResponsesToBackend(chatgpt: String?, deepseek: String?) {
        guard let url = URL(string: "http://localhost:8000/responses") else {
            print("⚠️ Неверный URL бэкенда")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any?] = [
            "chatgpt": chatgpt,
            "deepseek": deepseek
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
