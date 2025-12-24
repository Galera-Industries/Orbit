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
            print("⚠️ Не удалось извлечь содержимое страницы")
            return
        }
        
        print("📄 Получено содержимое: \(result.prefix(200))...")
        
        // Проверяем на ошибки
        if result.hasPrefix("ERROR:") {
            print("❌ \(result)")
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
        
        saveToFile(content: cleanText, url: pageURL, title: pageTitle)
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
    
    // MARK: - File Saving
    
    private func saveToFile(content: String, url: String?, title: String?) {
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
        
        // Формируем содержимое файла с метаданными
        var fileContent = ""
        if let url = url {
            fileContent += "URL: \(url)\n"
        }
        if let title = title {
            fileContent += "Title: \(title)\n"
        }
        fileContent += "Extracted: \(formatter.string(from: Date()))\n"
        fileContent += "\n" + String(repeating: "=", count: 80) + "\n\n"
        fileContent += content
        
        do {
            try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Содержимое сохранено: \(fileURL.path)")
            
            // Показываем уведомление или открываем файл
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } catch {
            print("❌ Ошибка сохранения файла: \(error)")
        }
    }
}

