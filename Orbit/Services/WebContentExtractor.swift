//
//  WebContentExtractor.swift
//  Orbit
//
//  Created by Auto on 2025.
//

import Foundation
import AppKit

final class WebContentExtractor {
    static let shared = WebContentExtractor()
    
    private let deepSeekService = DeepSeekService.shared
    private let telegramService = TelegramBotService.shared
    private let vkService = VKService.shared
    private let screenshotManager = ScreenshotManager.shared
    
    private init() {}
    
    /// Извлекает содержимое <div role="main"> из открытой страницы Safari или Chrome
    func extractMainContent() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            print("⚠️ Не удалось определить активное приложение")
            return
        }
        
        let bundleID = frontApp.bundleIdentifier ?? ""
        print("🌐 Активное приложение: \(bundleID)")
        
        if bundleID == "com.apple.Safari" {
            extractFromSafari()
        } else if bundleID == "com.google.Chrome" || bundleID == "com.google.Chrome.canary" {
            extractFromChrome()
        } else {
            print("⚠️ Активное приложение не является Safari или Chrome")
            // Можно попробовать извлечь из любого другого браузера через Accessibility
            extractFromAnyBrowser(bundleID: bundleID)
        }
    }
    
    // MARK: - Permission Handling
    
    /// Показывает алерт об ошибке разрешений после неудачной попытки
    private func showPermissionAlertAfterError() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Недостаточно разрешений"
            alert.informativeText = """
            Orbit не может получить доступ к браузеру из-за отсутствия разрешения на автоматизацию.
            
            ⚠️ Если Orbit не появляется в списке автоматизации, выполните следующие шаги:
            
            ШАГ 1: Сбросьте разрешения автоматизации
            Откройте Терминал и выполните команду:
            
              tccutil reset AppleEvents
            
            (Эта команда сбросит все разрешения автоматизации - безопасно)
            
            ШАГ 2: Перезапустите Orbit
            
            ШАГ 3: Попробуйте снова нажать ⌘⌥M
            macOS должна показать диалог запроса разрешения.
            Нажмите "Разрешить" в диалоге.
            
            ШАГ 4: Если диалог не появился, откройте настройки вручную:
            System Settings → Privacy & Security → Automation
            Найдите Orbit и включите разрешение для Safari/Chrome.
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Открыть настройки")
            alert.addButton(withTitle: "ОК")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.openAutomationSettings()
            }
        }
    }
    
    /// Показывает алерт о необходимости включить JavaScript в Safari
    private func showSafariJavaScriptAlert() {
        let alert = NSAlert()
        alert.messageText = "Требуется включить JavaScript в Safari"
        alert.informativeText = """
        Для работы функции необходимо включить опцию "Allow JavaScript from Apple Events" в настройках Safari.
        
        Инструкция:
        
        1. Откройте Safari
        2. Перейдите в меню Safari → Настройки (Settings) → Дополнения (Advanced)
        3. Внизу включите чекбокс "Показывать меню "Разработка" в строке меню"
        4. Перейдите в меню Разработка (Develop) → Разрешить JavaScript из Apple Events
        
        Или через настройки:
        Safari → Settings → Advanced → Show Develop menu
        Develop → Allow JavaScript from Apple Events
        
        После включения попробуйте снова (⌘⌥M).
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Открыть настройки Safari")
        alert.addButton(withTitle: "ОК")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Пытаемся открыть настройки Safari через AppleScript
            openSafariPreferences()
        }
    }
    
    /// Открывает настройки Safari
    private func openSafariPreferences() {
        let script = """
        tell application "Safari"
            activate
            tell application "System Events"
                tell process "Safari"
                    click menu item "Settings…" of menu "Safari" of menu bar 1
                end tell
            end tell
        end tell
        """
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        _ = appleScript?.executeAndReturnError(&error)
        if error != nil {
            // Fallback: просто активируем Safari
            NSWorkspace.shared.launchApplication("Safari")
        }
    }
    
    /// Открывает настройки автоматизации в System Settings
    private func openAutomationSettings() {
        // Пытаемся открыть настройки автоматизации
        // В macOS Ventura (13.0+) используется System Settings
        // В macOS Monterey (12.0) и ниже - System Preferences
        
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if version.majorVersion >= 13 {
            // macOS Ventura+
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                NSWorkspace.shared.open(url)
                return
            }
        } else {
            // macOS Monterey и ниже
            // Пытаемся открыть через AppleScript
            let script = """
            tell application "System Preferences"
                activate
                set current pane to pane "com.apple.preference.security"
                reveal anchor "Privacy_Automation" of pane "com.apple.preference.security"
            end tell
            """
            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?
            _ = appleScript?.executeAndReturnError(&error)
            if error == nil {
                return
            }
        }
        
        // Fallback: открываем общие настройки приватности
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        } else {
            // Последний fallback: открываем системные настройки
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
        }
    }
    
    // MARK: - Safari
    
    private func extractFromSafari() {
        // Сначала делаем простой запрос, чтобы вызвать диалог разрешения если его еще нет
        // Это помогает macOS показать приложение в списке автоматизации
        let testScript = """
        tell application "Safari"
            get name
        end tell
        """
        
        let testAppleScript = NSAppleScript(source: testScript)
        var testError: NSDictionary?
        _ = testAppleScript?.executeAndReturnError(&testError)
        
        // Теперь выполняем основной скрипт
        let script = """
        tell application "Safari"
            if not (exists window 1) then
                return "ERROR: No window"
            end if
            
            tell window 1
                if not (exists current tab) then
                    return "ERROR: No tab"
                end if
                
                tell current tab
                    set pageURL to URL
                    set pageTitle to name
                    
                    try
                        set jsResult to do JavaScript "
                            (function() {
                                const mainDiv = document.querySelector('div[role=\\\"main\\\"]');
                                if (mainDiv) {
                                    const result = {
                                        url: window.location.href,
                                        title: document.title,
                                        content: mainDiv.innerText || mainDiv.textContent || '',
                                        html: mainDiv.innerHTML || ''
                                    };
                                    return JSON.stringify(result);
                                }
                                return null;
                            })();
                        "
                        
                        if jsResult is not null and jsResult is not "" then
                            return jsResult
                        else
                            return "ERROR: Main div not found"
                        end if
                    on error errMsg
                        return "ERROR: " & errMsg
                    end try
                end tell
            end tell
        end tell
        """
        
        executeAppleScript(script) { [weak self] result in
            self?.processExtractedContent(result, isSafari: true)
        }
    }
    
    // MARK: - Chrome
    
    private func extractFromChrome() {
        // Сначала делаем простой запрос, чтобы вызвать диалог разрешения если его еще нет
        let testScript = """
        tell application "Google Chrome"
            get name
        end tell
        """
        
        let testAppleScript = NSAppleScript(source: testScript)
        var testError: NSDictionary?
        _ = testAppleScript?.executeAndReturnError(&testError)
        
        // Для Chrome используем похожий подход, но синтаксис немного отличается
        let script = """
        tell application "Google Chrome"
            if not (exists window 1) then
                return "ERROR: No window"
            end if
            
            tell window 1
                if not (exists active tab) then
                    return "ERROR: No tab"
                end if
                
                tell active tab
                    set pageURL to URL
                    set pageTitle to title
                    
                    try
                        set jsResult to execute javascript "
                            (function() {
                                const mainDiv = document.querySelector('div[role=\\\"main\\\"]');
                                if (mainDiv) {
                                    const result = {
                                        url: window.location.href,
                                        title: document.title,
                                        content: mainDiv.innerText || mainDiv.textContent || '',
                                        html: mainDiv.innerHTML || ''
                                    };
                                    return JSON.stringify(result);
                                }
                                return null;
                            })();
                        "
                        
                        if jsResult is not null and jsResult is not "" then
                            return jsResult
                        else
                            return "ERROR: Main div not found"
                        end if
                    on error errMsg
                        return "ERROR: " & errMsg
                    end try
                end tell
            end tell
        end tell
        """
        
        executeAppleScript(script) { [weak self] result in
            self?.processExtractedContent(result, isSafari: false)
        }
    }
    
    // MARK: - Generic Browser (fallback)
    
    private func extractFromAnyBrowser(bundleID: String) {
        // Пытаемся использовать универсальный подход через Accessibility
        // Но сначала попробуем через AppleScript с универсальным именем
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            print("⚠️ Не удалось определить активное приложение")
            return
        }
        
        let appName = frontAppName(for: bundleID)
        
        // Пока просто сообщаем, что поддержка еще не реализована
        print("⚠️ Универсальный метод для \(appName) (\(bundleID)) еще не реализован")
        print("💡 Поддерживаются только Safari и Google Chrome")
    }
    
    private func frontAppName(for bundleID: String) -> String {
        if bundleID.contains("Safari") {
            return "Safari"
        } else if bundleID.contains("Chrome") {
            return "Google Chrome"
        } else if bundleID.contains("Firefox") {
            return "Firefox"
        } else if bundleID.contains("Edge") {
            return "Microsoft Edge"
        }
        return NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
    }
    
    // MARK: - AppleScript Execution
    
    private func executeAppleScript(_ script: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?
            let result = appleScript?.executeAndReturnError(&error)
            
            if let error = error {
                print("❌ Ошибка выполнения AppleScript: \(error)")
                if let errorMessage = error[NSAppleScript.errorMessage] as? String {
                    print("   Сообщение: \(errorMessage)")
                }
                if let errorNumber = error[NSAppleScript.errorNumber] as? Int {
                    print("   Номер ошибки: \(errorNumber)")
                    
                    // Если ошибка связана с разрешениями, показываем алерт
                    if errorNumber == -1743 {
                        DispatchQueue.main.async {
                            self.showPermissionAlertAfterError()
                        }
                    }
                }
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let resultString: String?
            if let result = result {
                // Результат может быть строкой или другим типом
                if let stringValue = result.stringValue {
                    resultString = stringValue
                } else if let descriptor = result.coerce(toDescriptorType: typeUnicodeText) {
                    resultString = String(describing: descriptor)
                } else {
                    resultString = String(describing: result)
                }
            } else {
                resultString = nil
            }
            
            DispatchQueue.main.async {
                completion(resultString)
            }
        }
    }
    
    // MARK: - Content Processing
    
    private func processExtractedContent(_ result: String?, isSafari: Bool) {
        guard let result = result, !result.isEmpty else {
            print("⚠️ Не удалось извлечь содержимое страницы, делаем скриншот...")
            fallbackToScreenshot()
            return
        }
        
        print("📄 Получено содержимое: \(result.prefix(200))...")
        
        // Проверяем на ошибки
        if result.hasPrefix("ERROR:") {
            print("❌ \(result)")
            
            // Проверяем, не связана ли ошибка с настройками Safari
            if result.contains("Allow JavaScript from Apple Events") || result.contains("Developer section") {
                DispatchQueue.main.async { [weak self] in
                    self?.showSafariJavaScriptAlert()
                }
            } else {
                // Если ошибка не связана с настройками Safari, делаем fallback на скриншот
                print("⚠️ Не удалось извлечь текст, делаем скриншот...")
                fallbackToScreenshot()
            }
            return
        }
        
        // Пытаемся распарсить JSON, если результат был возвращен как JSON
        var pageURL: String?
        var pageTitle: String?
        var content: String?
        var html: String?
        
        // Убираем возможные лишние кавычки и пробелы
        let cleanedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let data = cleanedResult.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            pageURL = json["url"] as? String
            pageTitle = json["title"] as? String
            content = json["content"] as? String
            html = json["html"] as? String
        } else {
            // Если это не JSON, попробуем обработать как обычный текст
            // Возможно, это уже извлеченный текст
            content = cleanedResult
        }
        
        // Используем извлеченный текст (предпочтительно) или HTML
        let textToSave = content ?? html ?? cleanedResult
        
        // Если это HTML, извлекаем только текст
        let cleanText: String
        if let html = html, !html.isEmpty {
            cleanText = extractTextFromHTML(html)
        } else {
            cleanText = textToSave
        }
        
        // Сохраняем в файл и отправляем в AI
        saveToFile(content: cleanText, url: pageURL, title: pageTitle)
        sendToAI(content: cleanText)
    }
    
    private func extractTextFromHTML(_ html: String) -> String {
        // Простое извлечение текста из HTML (удаляем теги)
        // Для более продвинутой обработки можно использовать парсер HTML
        var text = html
        
        // Удаляем HTML теги (простой regex заменяет большинство случаев)
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        
        // Декодируем HTML entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&apos;", with: "'")
        
        // Убираем множественные пробелы и переносы строк
        text = text.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "\\n\\s*\\n",
            with: "\n\n",
            options: .regularExpression
        )
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Fallback to Screenshot
    
    /// Fallback: делаем скриншот выбранной области и отправляем в AI
    private func fallbackToScreenshot() {
        print("📸 Fallback: делаем скриншот выбранной области...")
        screenshotManager.captureAndSend()
    }
    
    // MARK: - AI Processing
    
    /// Отправляет извлеченный текст в AI сервисы
    private func sendToAI(content: String) {
        // Промпт из screenshot settings
        let userPrompt = UserDefaults.standard.string(forKey: "deepseekPrompt") ?? "Что изображено?"
        
        // ШАГ 1: Отправляем в DeepSeek с промптом "извлеки отсюда условия заданий и варианты ответов"
        let extractionPrompt = "извлеки отсюда условия заданий и варианты ответов \(content)"
        
        // Проверяем, есть ли ключ DeepSeek для извлечения
        guard deepSeekService.hasDeepSeekKey else {
            print("⚠️ Нет ключа DeepSeek для извлечения заданий")
            // Если нет ключа DeepSeek, отправляем сразу в ChatGPT и DeepSeek с исходным текстом
            sendToChatGPTAndDeepSeek(content: content, userPrompt: userPrompt)
            return
        }
        
        print("📤 ШАГ 1: Отправляю текст в DeepSeek (извлечение заданий)...")
        deepSeekService.sendTextToDeepSeek(prompt: extractionPrompt) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let extractedText):
                print("✅ DeepSeek (извлечение) ответ получен: \(extractedText.prefix(100))...")
                
                // ШАГ 2 и 3: Используем извлечённый текст для отправки в ChatGPT и DeepSeek с пользовательским промптом
                self.sendToChatGPTAndDeepSeek(content: extractedText, userPrompt: userPrompt)
                
            case .failure(let error):
                print("❌ DeepSeek (извлечение) ошибка: \(error)")
                // Если извлечение не удалось, отправляем исходный текст
                print("⚠️ Использую исходный текст для отправки в ChatGPT и DeepSeek")
                self.sendToChatGPTAndDeepSeek(content: content, userPrompt: userPrompt)
            }
        }
    }
    
    /// Отправляет текст в ChatGPT и DeepSeek с пользовательским промптом
    private func sendToChatGPTAndDeepSeek(content: String, userPrompt: String) {
        // Промпт для Yandex и DeepSeek (используем пользовательский промпт из screenshot settings)
        let finalPrompt = "\(userPrompt)\n\n\(content)"
        
        var chatgptResponse: String? = nil
        var deepseekResponse: String? = nil
        var chatgptError: Error? = nil
        var deepseekError: Error? = nil
        
        let group = DispatchGroup()
        
        // ШАГ 2: Отправляем в Yandex (GPT-5.2-chat-latest) если есть токен (с пользовательским промптом)
        if deepSeekService.hasYandexToken {
            group.enter()
            print("📤 ШАГ 2: Отправляю текст в Yandex (GPT-5.2-chat-latest) с пользовательским промптом...")
            deepSeekService.sendTextToYandex(prompt: finalPrompt) { result in
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
        
        // ШАГ 3: Отправляем в DeepSeek (с промптом из screenshot settings) если есть ключ
        if deepSeekService.hasDeepSeekKey {
            group.enter()
            print("📤 ШАГ 3: Отправляю текст в DeepSeek (с пользовательским промптом)...")
            deepSeekService.sendTextToDeepSeek(prompt: finalPrompt) { result in
                switch result {
                case .success(let response):
                    deepseekResponse = response
                    print("✅ DeepSeek (пользовательский промпт) ответ получен: \(response.prefix(100))...")
                case .failure(let error):
                    deepseekError = error
                    print("❌ DeepSeek (пользовательский промпт) ошибка: \(error)")
                }
                group.leave()
            }
        }
        
        // Ждем завершения всех запросов
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Отправляем отдельные ответы в Telegram и VK
            if let chatgpt = chatgptResponse {
                let message = "🤖 ChatGPT\n\n\(chatgpt)"
                self.sendToMessengers(message: message, serviceName: "ChatGPT")
            }
            
            if let deepseek = deepseekResponse {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let message = "🔵 DeepSeek\n\n\(deepseek)"
                    self.sendToMessengers(message: message, serviceName: "DeepSeek")
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
            
            // Сохраняем ответы в UserDefaults для панели
            if let chatgpt = chatgptResponse {
                self.saveResponse(chatgpt, type: "chatgpt")
            }
            if let deepseek = deepseekResponse {
                self.saveResponse(deepseek, type: "deepseek")
            }
        }
    }
    
    /// Сохраняет ответ в UserDefaults
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
    }
    
    /// Отправляет сообщение в Telegram и VK (если настроены)
    private func sendToMessengers(message: String, serviceName: String) {
        // Отправляем в Telegram
        print("📱 Отправляю ответ \(serviceName) в Telegram...")
        telegramService.sendMessage(message) { result in
            switch result {
            case .success:
                print("✅ \(serviceName) ответ отправлен в Telegram")
            case .failure(let error):
                print("❌ Ошибка отправки \(serviceName) в Telegram: \(error.localizedDescription)")
            }
        }
        
        // Отправляем в VK (отдельное сообщение)
        print("📱 Отправляю ответ \(serviceName) в VK...")
        vkService.sendMessage(message.replacingOccurrences(of: "*", with: "")) { result in
            switch result {
            case .success:
                print("✅ \(serviceName) ответ отправлен в VK")
            case .failure(let error):
                print("❌ Ошибка отправки \(serviceName) в VK: \(error.localizedDescription)")
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
                print("❌ Ошибка отправки комбинированного сообщения в VK: \(error.localizedDescription)")
            }
        }
    }
    
    /// Отправляет ответы на бэкенд для Apple Watch
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
                } else {
                    // Connection refused или другая ошибка - это нормально, если бэкенд не запущен
                    print("⚠️ Не удалось подключиться к бэкенду (возможно, он не запущен)")
                }
            }.resume()
        } catch {
            print("❌ Ошибка сериализации JSON: \(error)")
        }
    }
    
    // MARK: - File Saving
    
    private func saveToFile(content: String, url: String?, title: String?) {
        // Сохраняем только текст, без метаданных
        guard let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            print("⚠️ Не удалось найти папку Desktop")
            return
        }
        
        let screenshotsFolder = desktopURL.appendingPathComponent("orbitscreenshots", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: screenshotsFolder, withIntermediateDirectories: true)
        } catch {
            print("⚠️ Ошибка создания папки: \(error)")
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        // Создаем безопасное имя файла из заголовка
        var filename = "main_content_\(timestamp).txt"
        if let title = title, !title.isEmpty {
            let safeTitle = title
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: "\\", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(100) // Ограничиваем длину
            filename = "\(safeTitle)_\(timestamp).txt"
        }
        
        let fileURL = screenshotsFolder.appendingPathComponent(filename)
        
        // Сохраняем только текст без метаданных
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Содержимое сохранено: \(fileURL.path)")
            
            // Возвращаем фокус в Safari, чтобы пользователь остался там
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let safari = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.Safari" }) {
                    safari.activate(options: [])
                }
            }
        } catch {
            print("❌ Ошибка сохранения файла: \(error)")
        }
    }
}

