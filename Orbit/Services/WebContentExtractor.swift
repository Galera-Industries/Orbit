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

    private enum ExtractionFlow {
        case standard
        case datasetQuestions
    }
    
    private struct ExtractedImage {
        let url: String
        let dataURL: String?
    }
    
    private struct ExtractedQuestion {
        let id: String
        let html: String
        let images: [ExtractedImage]
    }

    private struct InformativeSessionContext {
        let informativeQuestionText: String
        let trainPreview: String
        let testPreview: String
    }

    private struct DatasetQuestionGroup {
        let title: String
        let questionText: String
    }

    private struct SavedQuestionPayload: Codable {
        let number: Int
        let text: String
    }

    private struct SavedQuestionsDocument: Codable {
        let questions: [SavedQuestionPayload]
        let mergedText: String
        let savedAt: String
    }
    
    private let deepSeekService = DeepSeekService.shared
    private let telegramService = TelegramBotService.shared
    private let vkService = VKService.shared
    private let screenshotManager = ScreenshotManager.shared
    private var informativeSessionContext: InformativeSessionContext?
    
    private init() {}
    
    /// Извлекает содержимое <div role="main"> из открытой страницы Safari или Chrome
    func extractMainContent() {
        extractContent(flow: .standard)
    }

    /// Извлекает вопросы в сценарии с "информативным" первым вопросом и CSV
    func extractDatasetQuestionContent() {
        extractContent(flow: .datasetQuestions)
    }

    /// Формирует контекст из main.py + questions.json + CSV и отправляет в ChatGPT.
    /// Используется для сценария запуска из PyCharm.
    func sendPyCharmProgressContext() {
        guard deepSeekService.hasChatGPTToken else {
            print("⚠️ Нет токена ChatGPT для отправки PyCharm-контекста")
            return
        }

        let defaults = UserDefaults.standard
        let folderPath = defaults.string(forKey: "datasetQuestionsFolder")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !folderPath.isEmpty else {
            print("⚠️ Папка не выбрана. Укажите папку с train.csv, test.csv и main.py в настройках.")
            return
        }

        let folderURL = URL(fileURLWithPath: folderPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            print("⚠️ Указанная папка недоступна: \(folderPath)")
            return
        }

        let mainPyURL = folderURL.appendingPathComponent("main.py")
        let mainPyText = readTextFile(
            at: mainPyURL,
            notFoundMessage: "Файл main.py не найден в выбранной папке.",
            failedMessage: "Не удалось прочитать main.py."
        )
        guard !mainPyText.hasPrefix("Файл main.py не найден"), !mainPyText.hasPrefix("Не удалось прочитать") else {
            print("⚠️ \(mainPyText)")
            return
        }

        guard let lastTaskNumber = extractLastTaskNumber(from: mainPyText) else {
            print("⚠️ В main.py не найдено комментариев формата '# 1', '# 2' и т.д.")
            return
        }

        let allQuestions = loadSavedQuestionsFromOrbitFolder()
        let questionsByNumber = Dictionary(uniqueKeysWithValues: allQuestions.map { ($0.number, $0.text) })
        let firstNQuestionsText = (1...lastTaskNumber)
            .map { number in
                questionsByNumber[number] ?? "Вопрос с number: \(number) не найден в ~/Orbit/questions.json."
            }
            .joined(separator: "\n")
        let currentQuestionText = questionsByNumber[lastTaskNumber]
            ?? "Вопрос с number: \(lastTaskNumber) не найден в ~/Orbit/questions.json."

        let trainPreview = readCSVPreview(at: folderURL.appendingPathComponent("train.csv"))
        let testPreview = readCSVPreview(at: folderURL.appendingPathComponent("test.csv"))
        let terminalOutputContext = loadLatestOrbitLogsOutput()
        let terminalOutput = terminalOutputContext?.text ?? ""
        let terminalOutputSection: String
        if terminalOutput.isEmpty {
            terminalOutputSection = ""
            print("ℹ️ PyCharm context: файлов в ~/Orbit/logs нет, отправляю без блока run-output")
        } else {
            terminalOutputSection = """

            Вот нынешний результат:
            \(terminalOutput)
            """
        }

        let finalPrompt = """
        Верни только список изменений в формате:
        1) какие строки изменить (диапазон или ориентир по коду),
        2) что именно заменить/добавить,
        3) как починить текущую ошибку.
        Не присылай полный файл целиком и не повторяй исходный код без необходимости.

        Текст первых \(lastTaskNumber) вопросов из файла ~/Orbit/questions.json:
        \(firstNQuestionsText)

        Вот по 10 строк train.csv и test.csv соответственно:

        \(trainPreview)

        \(testPreview)

        Считай, что мы уже сделали все задания кроме последнего: \(currentQuestionText)

        Вот какой код сейчас:
        \(mainPyText)
        \(terminalOutputSection)
        """

        if let terminalOutputContext {
            print("ℹ️ PyCharm context: terminal output source = \(terminalOutputContext.source), chars = \(terminalOutput.count)")
            persistDebugOutput(terminalOutput, in: folderURL, source: terminalOutputContext.source)
        }

        overwriteLatestResponse("Отправляю контекст из PyCharm...", type: "chatgpt")
        deepSeekService.sendTextToChatGPT(prompt: finalPrompt) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let response):
                self.overwriteLatestResponse(response, type: "chatgpt")
                self.sendToMessengers(message: "🤖 ChatGPT\n\n\(response)", serviceName: "ChatGPT")
                self.sendCombinedMessageToVK(chatgpt: response, deepseek: nil)
                self.sendResponsesToBackend(chatgpt: response, deepseek: nil)
            case .failure(let error):
                print("❌ Ошибка отправки PyCharm-контекста в ChatGPT: \(error)")
            }
        }
    }

    private func extractContent(flow: ExtractionFlow) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            print("⚠️ Не удалось определить активное приложение")
            return
        }
        
        let bundleID = frontApp.bundleIdentifier ?? ""
        let appName = frontApp.localizedName ?? "Unknown Browser"
        print("🌐 Активное приложение: \(bundleID)")
        
        if bundleID == "com.apple.Safari" {
            extractFromSafari(flow: flow)
        } else if isChromiumBrowser(bundleID: bundleID) {
            extractFromChromiumBrowser(appName: appName, flow: flow)
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
    
    private func extractFromSafari(flow: ExtractionFlow) {
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
                                function walk(node, hits) {
                                    if (node.nodeType === 1 && node.tagName === 'DIV') {
                                        // ищем main
                                        if (node.getAttribute('role') === 'main') hits.main = node;
                                        // ищем question
                                        if (node.id && node.id.startsWith('question')) hits.questions.push(node);
                                    }
                                    for (const child of node.childNodes) walk(child, hits);
                                }

                                const hits = { main: null, questions: [] };
                                walk(document.body, hits);
                                
                                if (hits.questions.length > 0) {
                                    function captureImageDataURL(img) {
                                        try {
                                            if (!img || !img.complete || img.naturalWidth <= 0 || img.naturalHeight <= 0) return '';
                                            const canvas = document.createElement('canvas');
                                            canvas.width = img.naturalWidth;
                                            canvas.height = img.naturalHeight;
                                            const ctx = canvas.getContext('2d');
                                            if (!ctx) return '';
                                            ctx.drawImage(img, 0, 0);
                                            return canvas.toDataURL('image/png');
                                        } catch (e) {
                                            return '';
                                        }
                                    }
                                    
                                    const questions = hits.questions.map(div => {
                                        const imageElements = Array.from(div.querySelectorAll('.qtext img, .formulation img'));
                                        const images = imageElements
                                            .map(img => {
                                                const url = img.currentSrc || img.getAttribute('src') || '';
                                                const data_url = captureImageDataURL(img);
                                                return { url, data_url };
                                            })
                                            .filter(item => Boolean(item.url) || Boolean(item.data_url));
                                        return {
                                            id: div.id || '',
                                            html: div.outerHTML || '',
                                            images: images
                                        };
                                    });
                                    const questionsHtml = questions.map(item => item.html).join('');
                                    const result = {
                                        type: 'questions',
                                        url: window.location.href,
                                        title: document.title,
                                        html: questionsHtml,
                                        questions: questions
                                    };
                                    return JSON.stringify(result);
                                }
                                
                                // Если question блоков нет, используем main
                                if (hits.main) {
                                    const result = {
                                        type: 'main',
                                        url: window.location.href,
                                        title: document.title,
                                        html: hits.main.outerHTML || ''
                                    };
                                    return JSON.stringify(result);
                                }
                                
                                return null;
                            })();
                        "
                        
                        if jsResult is not null and jsResult is not "" then
                            return jsResult
                        else
                            return "ERROR: Main div and questions not found"
                        end if
                    on error errMsg
                        return "ERROR: " & errMsg
                    end try
                end tell
            end tell
        end tell
        """
        
        executeAppleScript(script) { [weak self] result in
            self?.processExtractedContent(result, isSafari: true, flow: flow)
        }
    }
    
    // MARK: - Chromium Browsers
    
    private func extractFromChromiumBrowser(appName: String, flow: ExtractionFlow) {
        // Сначала делаем простой запрос, чтобы вызвать диалог разрешения если его еще нет
        let testScript = """
        tell application "\(appName)"
            get name
        end tell
        """
        
        let testAppleScript = NSAppleScript(source: testScript)
        var testError: NSDictionary?
        _ = testAppleScript?.executeAndReturnError(&testError)
        
        // Для Chrome используем похожий подход, но синтаксис немного отличается
        let script = """
        tell application "\(appName)"
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
                                function walk(node, hits) {
                                    if (node.nodeType === 1 && node.tagName === 'DIV') {
                                        // ищем main
                                        if (node.getAttribute('role') === 'main') hits.main = node;
                                        // ищем question
                                        if (node.id && node.id.startsWith('question')) hits.questions.push(node);
                                    }
                                    for (const child of node.childNodes) walk(child, hits);
                                }

                                const hits = { main: null, questions: [] };
                                walk(document.body, hits);
                                
                                if (hits.questions.length > 0) {
                                    function captureImageDataURL(img) {
                                        try {
                                            if (!img || !img.complete || img.naturalWidth <= 0 || img.naturalHeight <= 0) return '';
                                            const canvas = document.createElement('canvas');
                                            canvas.width = img.naturalWidth;
                                            canvas.height = img.naturalHeight;
                                            const ctx = canvas.getContext('2d');
                                            if (!ctx) return '';
                                            ctx.drawImage(img, 0, 0);
                                            return canvas.toDataURL('image/png');
                                        } catch (e) {
                                            return '';
                                        }
                                    }
                                    
                                    const questions = hits.questions.map(div => {
                                        const imageElements = Array.from(div.querySelectorAll('.qtext img, .formulation img'));
                                        const images = imageElements
                                            .map(img => {
                                                const url = img.currentSrc || img.getAttribute('src') || '';
                                                const data_url = captureImageDataURL(img);
                                                return { url, data_url };
                                            })
                                            .filter(item => Boolean(item.url) || Boolean(item.data_url));
                                        return {
                                            id: div.id || '',
                                            html: div.outerHTML || '',
                                            images: images
                                        };
                                    });
                                    const questionsHtml = questions.map(item => item.html).join('');
                                    const result = {
                                        type: 'questions',
                                        url: window.location.href,
                                        title: document.title,
                                        html: questionsHtml,
                                        questions: questions
                                    };
                                    return JSON.stringify(result);
                                }
                                
                                // Если question блоков нет, используем main
                                if (hits.main) {
                                    const result = {
                                        type: 'main',
                                        url: window.location.href,
                                        title: document.title,
                                        html: hits.main.outerHTML || ''
                                    };
                                    return JSON.stringify(result);
                                }
                                
                                return null;
                            })();
                        "
                        
                        if jsResult is not null and jsResult is not "" then
                            return jsResult
                        else
                            return "ERROR: Main div and questions not found"
                        end if
                    on error errMsg
                        return "ERROR: " & errMsg
                    end try
                end tell
            end tell
        end tell
        """
        
        executeAppleScript(script) { [weak self] result in
            self?.processExtractedContent(result, isSafari: false, flow: flow)
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
    
    private func isChromiumBrowser(bundleID: String) -> Bool {
        let chromiumBundleIDs: Set<String> = [
            "com.google.Chrome",
            "com.google.Chrome.canary",
            "ru.yandex.desktop.yandex-browser"
        ]
        return chromiumBundleIDs.contains(bundleID)
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
    
    private func processExtractedContent(_ result: String?, isSafari: Bool, flow: ExtractionFlow) {
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
                // Если ошибка не связана с настройками Safari и не найдены ни main, ни questions, делаем fallback на скриншот
                if result.contains("Main div and questions not found") {
                    print("⚠️ Не найдены ни main div, ни question divs, делаем скриншот...")
                    fallbackToScreenshot()
                } else {
                    print("⚠️ Не удалось извлечь текст, делаем скриншот...")
                    fallbackToScreenshot()
                }
            }
            return
        }
        
        // Пытаемся распарсить JSON
        let cleanedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedResult.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentType = json["type"] as? String,
              let html = json["html"] as? String, !html.isEmpty else {
            print("⚠️ Не удалось распарсить JSON, делаем скриншот...")
            fallbackToScreenshot()
            return
        }
        
        let pageURL = json["url"] as? String
        let pageTitle = json["title"] as? String
        
        // Сохраняем HTML в файл (без очистки)
        saveToFile(content: html, url: pageURL, title: pageTitle)
        
        // Обрабатываем в зависимости от типа
        if contentType == "questions" {
            if let questionsJson = json["questions"] as? [[String: Any]], !questionsJson.isEmpty {
                let questions = parseQuestions(from: questionsJson)
                if !questions.isEmpty {
                    if flow == .datasetQuestions {
                        processDatasetQuestions(questions: questions, pageURL: pageURL)
                    } else {
                        sendQuestionsToAI(questions: questions)
                    }
                } else {
                    sendQuestionsToAI(html: html)
                }
            } else {
                // Fallback для старого формата
                sendQuestionsToAI(html: html)
            }
        } else if contentType == "main" {
            // Для main отправляем HTML напрямую в AI (без очистки)
            sendToAI(content: html, isHTML: true)
        } else {
            print("⚠️ Неизвестный тип контента: \(contentType), делаем скриншот...")
            fallbackToScreenshot()
        }
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

    private func processDatasetQuestions(questions: [ExtractedQuestion], pageURL: String?) {
        guard !questions.isEmpty else { return }
        prepareDatasetQuestionsForSaving(questions) { [weak self] preparedQuestions in
            self?.saveDatasetQuestionsToJSON(preparedQuestions)
        }

        if let informativeIndex = questions.firstIndex(where: { isInformativeQuestion($0) }) {
            var remainingQuestions = questions
            let informativeQuestion = remainingQuestions.remove(at: informativeIndex)

            prepareInformativeSessionContext(from: informativeQuestion, pageURL: pageURL) { [weak self] context in
                guard let self = self else { return }
                guard let context else {
                    self.sendQuestionsToAI(questions: questions)
                    return
                }

                self.informativeSessionContext = context
                let groups = self.buildDatasetQuestionGroups(from: remainingQuestions)
                guard !groups.isEmpty else {
                    self.sendQuestionsToAI(questions: remainingQuestions)
                    return
                }

                self.sendDatasetQuestionGroupsToAI(groups: groups, context: context)
            }
            return
        }

        guard let cachedContext = informativeSessionContext else {
            sendQuestionsToAI(questions: questions)
            return
        }
        let groups = buildDatasetQuestionGroups(from: questions)
        guard !groups.isEmpty else {
            sendQuestionsToAI(questions: questions)
            return
        }
        sendDatasetQuestionGroupsToAI(groups: groups, context: cachedContext)
    }

    private func isInformativeQuestion(_ question: ExtractedQuestion) -> Bool {
        let html = question.html.lowercased()
        return html.contains("informationitem") || html.contains("que description")
    }

    private func prepareInformativeSessionContext(
        from question: ExtractedQuestion,
        pageURL: String?,
        completion: @escaping (InformativeSessionContext?) -> Void
    ) {
        _ = pageURL
        let informativeQuestionText = extractTextFromHTML(question.html)
        let (trainPreview, testPreview) = loadDatasetPreviewsFromSelectedFolder()
        completion(
            InformativeSessionContext(
                informativeQuestionText: informativeQuestionText,
                trainPreview: trainPreview,
                testPreview: testPreview
            )
        )
    }

    private func loadDatasetPreviewsFromSelectedFolder() -> (String, String) {
        let defaults = UserDefaults.standard
        let folderPath = defaults.string(forKey: "datasetQuestionsFolder")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !folderPath.isEmpty else {
            let message = "Папка не выбрана. Укажите папку с train.csv и test.csv в настройках."
            return (message, message)
        }

        let folderURL = URL(fileURLWithPath: folderPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            let message = "Указанная папка недоступна: \(folderPath)"
            return (message, message)
        }

        let trainURL = folderURL.appendingPathComponent("train.csv")
        let testURL = folderURL.appendingPathComponent("test.csv")
        let trainPreview = readCSVPreview(at: trainURL)
        let testPreview = readCSVPreview(at: testURL)
        return (trainPreview, testPreview)
    }

    private func readTextFile(at fileURL: URL, notFoundMessage: String, failedMessage: String) -> String {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return notFoundMessage
        }
        guard let data = try? Data(contentsOf: fileURL) else {
            return failedMessage
        }
        return String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }

    private func readCSVPreview(at fileURL: URL) -> String {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return "Файл \(fileURL.lastPathComponent) не найден."
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            return "Не удалось прочитать файл \(fileURL.lastPathComponent)."
        }

        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let preview = lines.prefix(10).joined(separator: "\n")
        return preview.isEmpty ? "Файл \(fileURL.lastPathComponent) пустой." : preview
    }

    private func extractLastTaskNumber(from pythonCode: String) -> Int? {
        let pattern = #"(?m)^\s*#\s*(\d+)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsCode = pythonCode as NSString
        let matches = regex.matches(in: pythonCode, range: NSRange(location: 0, length: nsCode.length))
        guard let last = matches.last, last.numberOfRanges > 1 else { return nil }
        let value = nsCode.substring(with: last.range(at: 1))
        return Int(value)
    }

    private func loadSavedQuestionsFromOrbitFolder() -> [SavedQuestionPayload] {
        let questionsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Orbit", isDirectory: true)
            .appendingPathComponent("questions.json")

        guard let data = try? Data(contentsOf: questionsURL) else { return [] }

        if let document = try? JSONDecoder().decode(SavedQuestionsDocument.self, from: data) {
            return document.questions
        }

        if let flatQuestions = try? JSONDecoder().decode([SavedQuestionPayload].self, from: data) {
            return flatQuestions
        }

        return []
    }

    private func loadLatestOrbitLogsOutput() -> (text: String, source: String)? {
        let logsFolder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Orbit", isDirectory: true)
            .appendingPathComponent("logs", isDirectory: true)

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: logsFolder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }

        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isRegularFileKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: logsFolder,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let files = urls.compactMap { url -> (url: URL, modifiedAt: Date)? in
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { return nil }
            let modifiedAt = values.contentModificationDate ?? .distantPast
            return (url, modifiedAt)
        }

        guard let latestFile = files.max(by: { $0.modifiedAt < $1.modifiedAt })?.url else {
            return nil
        }

        let text = readTextFile(
            at: latestFile,
            notFoundMessage: "",
            failedMessage: "Не удалось прочитать \(latestFile.lastPathComponent)."
        )
        guard !text.isEmpty else { return nil }

        return (text, "~/Orbit/logs/\(latestFile.lastPathComponent)")
    }

    private func persistDebugOutput(_ output: String, in folderURL: URL, source: String) {
        let debugURL = folderURL.appendingPathComponent("output.txt")
        let globalDebugFolder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Orbit", isDirectory: true)
        let globalDebugURL = globalDebugFolder.appendingPathComponent("output.txt")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let payload = """
        # orbit_debug_saved_at: \(timestamp)
        # source: \(source)

        \(output)
        """

        do {
            try payload.write(to: debugURL, atomically: true, encoding: .utf8)
            print("🧪 Debug: сохранен output.txt (\(output.count) chars) в \(debugURL.path)")
        } catch {
            print("❌ Debug: не удалось сохранить output.txt: \(error)")
        }

        do {
            try FileManager.default.createDirectory(at: globalDebugFolder, withIntermediateDirectories: true)
            try payload.write(to: globalDebugURL, atomically: true, encoding: .utf8)
            print("🧪 Debug: сохранен глобальный ~/Orbit/output.txt (\(output.count) chars)")
        } catch {
            print("❌ Debug: не удалось сохранить ~/Orbit/output.txt: \(error)")
        }
    }

    private func buildDatasetQuestionGroups(from questions: [ExtractedQuestion]) -> [DatasetQuestionGroup] {
        guard !questions.isEmpty else { return [] }

        let textQuestions: [(taskNumber: Int, text: String)] = questions.enumerated().compactMap { index, question in
            let text = extractTextFromHTML(question.html)
            guard !text.isEmpty else { return nil }
            return (taskNumber: index + 1, text: text)
        }

        guard !textQuestions.isEmpty else { return [] }

        let body = textQuestions
            .map { "# задание \($0.taskNumber)\n\($0.text)" }
            .joined(separator: "\n\n")
        return [DatasetQuestionGroup(title: "Все задания", questionText: body)]
    }

    private func prepareDatasetQuestionsForSaving(
        _ questions: [ExtractedQuestion],
        completion: @escaping ([SavedQuestionPayload]) -> Void
    ) {
        guard !questions.isEmpty else {
            completion([])
            return
        }

        var prepared: [SavedQuestionPayload] = []
        prepareDatasetQuestionSequentially(
            questions: questions,
            index: 0,
            prepared: prepared,
            completion: completion
        )
    }

    private func prepareDatasetQuestionSequentially(
        questions: [ExtractedQuestion],
        index: Int,
        prepared: [SavedQuestionPayload],
        completion: @escaping ([SavedQuestionPayload]) -> Void
    ) {
        guard index < questions.count else {
            completion(prepared)
            return
        }

        var nextPrepared = prepared
        let question = questions[index]
        let fallbackText = extractTextFromHTML(question.html)

        guard deepSeekService.hasDeepSeekKey else {
            if !fallbackText.isEmpty {
                nextPrepared.append(SavedQuestionPayload(number: index + 1, text: fallbackText))
            }
            prepareDatasetQuestionSequentially(
                questions: questions,
                index: index + 1,
                prepared: nextPrepared,
                completion: completion
            )
            return
        }

        let extractionPrompt = """
        извлеки только чистый текст задания из html ниже.
        Удали служебный UI мусор (например: "Пока нет ответа", "Отметить вопрос", "Проверить", блоки загрузки файлов, кнопки и прочее).
        Сохрани все важные формулировки, числа, ограничения, формулы и требования.
        Верни только текст задания без пояснений.

        html вопроса:
        \(question.html)
        """

        deepSeekService.sendTextToDeepSeek(prompt: extractionPrompt, includeSystemMessage: false) { [weak self] result in
            guard let self = self else { return }

            let cleanedText: String
            switch result {
            case .success(let response):
                let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
                cleanedText = trimmed.isEmpty ? fallbackText : trimmed
            case .failure:
                cleanedText = fallbackText
            }

            if !cleanedText.isEmpty {
                nextPrepared.append(SavedQuestionPayload(number: index + 1, text: cleanedText))
            }

            self.prepareDatasetQuestionSequentially(
                questions: questions,
                index: index + 1,
                prepared: nextPrepared,
                completion: completion
            )
        }
    }

    private func saveDatasetQuestionsToJSON(_ preparedQuestions: [SavedQuestionPayload]) {
        guard !preparedQuestions.isEmpty else { return }

        let mergedText = preparedQuestions
            .map { "# задание \($0.number)\n\($0.text)" }
            .joined(separator: "\n\n")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let document = SavedQuestionsDocument(
            questions: preparedQuestions,
            mergedText: mergedText,
            savedAt: formatter.string(from: Date())
        )

        let orbitFolder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Orbit", isDirectory: true)
        let questionsURL = orbitFolder.appendingPathComponent("questions.json")

        do {
            try FileManager.default.createDirectory(at: orbitFolder, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try encoder.encode(document)
            try data.write(to: questionsURL, options: .atomic)
            print("✅ Вопросы сохранены: \(questionsURL.path)")
        } catch {
            print("❌ Ошибка сохранения questions.json: \(error)")
        }
    }

    private func sendDatasetQuestionGroupsToAI(groups: [DatasetQuestionGroup], context: InformativeSessionContext) {
        guard !groups.isEmpty else { return }
        clearStoredResponses(type: "deepseek")

        if deepSeekService.hasChatGPTToken {
            overwriteLatestResponse("Обрабатываю группы вопросов...", type: "chatgpt")
        }

        processDatasetGroupSequentially(
            groups: groups,
            index: 0,
            context: context,
            aggregatedChatGPT: []
        )
    }

    private func processDatasetGroupSequentially(
        groups: [DatasetQuestionGroup],
        index: Int,
        context: InformativeSessionContext,
        aggregatedChatGPT: [String]
    ) {
        guard index < groups.count else {
            let finalChatGPT = aggregatedChatGPT.joined(separator: "\n\n")

            if !finalChatGPT.isEmpty {
                overwriteLatestResponse(finalChatGPT, type: "chatgpt")
                sendToMessengers(message: "🤖 ChatGPT\n\n\(finalChatGPT)", serviceName: "ChatGPT")
            }
            if !finalChatGPT.isEmpty {
                sendCombinedMessageToVK(chatgpt: finalChatGPT, deepseek: nil)
                sendResponsesToBackend(chatgpt: finalChatGPT, deepseek: nil)
            }
            return
        }

        let userPrompt = UserDefaults.standard.string(forKey: "deepseekPrompt") ?? "Что изображено?"
        let groupItem = groups[index]

        let finalPrompt = """
        \(userPrompt)

        Информативный вопрос:
        \(context.informativeQuestionText)

        Первые 10 строк train.csv:
        \(context.trainPreview)

        Первые 10 строк test.csv:
        \(context.testPreview)

        Задание:
        \(groupItem.questionText)

        Напиши код для решения. Считай, что файлы называются train.csv и test.csv и находятся в одной папке с кодом. Разделяй участки кода между заданиями с пумощью комментариев, например '# Задние 1', '# Задние 2', и т.д. Вс
         решение на python
        """

        var nextChatGPT = aggregatedChatGPT
        let group = DispatchGroup()

        if deepSeekService.hasChatGPTToken {
            group.enter()
            deepSeekService.sendTextToChatGPT(prompt: finalPrompt) { result in
                if case .success(let response) = result {
                    nextChatGPT.append("### \(groupItem.title)\n\(response)")
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            if !nextChatGPT.isEmpty {
                self.overwriteLatestResponse(nextChatGPT.joined(separator: "\n\n"), type: "chatgpt")
            }

            self.processDatasetGroupSequentially(
                groups: groups,
                index: index + 1,
                context: context,
                aggregatedChatGPT: nextChatGPT
            )
        }
    }

    // MARK: - Fallback to Screenshot
    
    /// Fallback: делаем скриншот выбранной области и отправляем в AI
    private func fallbackToScreenshot() {
        print("📸 Fallback: делаем скриншот выбранной области...")
        screenshotManager.captureAndSend()
    }
    
    // MARK: - AI Processing
    
    /// Отправляет извлеченный HTML/текст в AI сервисы
    private func sendToAI(content: String, isHTML: Bool = false) {
        // Промпт из screenshot settings
        let userPrompt = UserDefaults.standard.string(forKey: "deepseekPrompt") ?? "Что изображено?"
        
        // ШАГ 1: Отправляем в DeepSeek с промптом "извлеки отсюда условия заданий и варианты ответов"
        let extractionPrompt = "извлеки отсюда условия заданий и варианты ответов, также не забудь указать какие вопросы имеют множественный, а какие олиночный выбор ответа:\(content)"
        
        // Проверяем, есть ли ключ DeepSeek для извлечения
        guard deepSeekService.hasDeepSeekKey else {
            print("⚠️ Нет ключа DeepSeek для извлечения заданий")
            // Если нет ключа DeepSeek, отправляем сразу в ChatGPT и DeepSeek с исходным текстом
            sendToChatGPTAndDeepSeek(content: content, userPrompt: userPrompt)
            return
        }
        
        print("📤 ШАГ 1: Отправляю текст в DeepSeek (извлечение заданий)...")
        deepSeekService.sendTextToDeepSeek(prompt: extractionPrompt, includeSystemMessage: false) { [weak self] result in
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
    
    /// Отправляет HTML вопросов в DeepSeek для извлечения вопросов и вариантов ответов
    private func sendQuestionsToAI(html: String) {
        clearStoredResponses(type: "deepseek")

        // Промпт из screenshot settings
        let userPrompt = UserDefaults.standard.string(forKey: "deepseekPrompt") ?? "Что изображено?"
        
        // Отправляем HTML в DeepSeek с промптом "извлеки отсюда вопросы и варианты ответов"
        // НЕ убираем HTML мусор, отправляем как есть
        let extractionPrompt = "извлеки отсюда вопросы и варианты ответов\n\n\(html)"
        
        // Проверяем, есть ли ключ DeepSeek для извлечения
        guard deepSeekService.hasDeepSeekKey else {
            print("⚠️ Нет ключа DeepSeek для извлечения вопросов")
            // Если нет ключа DeepSeek, отправляем HTML напрямую только в ChatGPT
            sendToChatGPTOnly(content: html, userPrompt: userPrompt)
            return
        }
        
        print("📤 Отправляю HTML вопросов в DeepSeek (извлечение вопросов и вариантов ответов)...")
        deepSeekService.sendTextToDeepSeek(prompt: extractionPrompt, includeSystemMessage: false) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let extractedText):
                print("✅ DeepSeek (извлечение вопросов) ответ получен: \(extractedText.prefix(100))...")
                
                // Используем извлечённый текст и отправляем его только в ChatGPT
                self.sendToChatGPTOnly(content: extractedText, userPrompt: userPrompt)
                
            case .failure(let error):
                print("❌ DeepSeek (извлечение вопросов) ошибка: \(error)")
                // Если извлечение не удалось, отправляем исходный HTML
                print("⚠️ Использую исходный HTML для отправки в ChatGPT и DeepSeek")
                self.sendToChatGPTOnly(content: html, userPrompt: userPrompt)
            }
        }
    }
    
    /// Отправляет вопросы по одному, накапливая ответ в панели
    private func sendQuestionsToAI(questions: [ExtractedQuestion]) {
        guard !questions.isEmpty else { return }
        clearStoredResponses(type: "deepseek")
        
        let userPrompt = UserDefaults.standard.string(forKey: "deepseekPrompt") ?? "Что изображено?"
        
        // Подготовка "живого" накопления в верхней карточке ответов
        if deepSeekService.hasChatGPTToken {
            overwriteLatestResponse("Обрабатываю вопросы...", type: "chatgpt")
        }
        
        processQuestionSequentially(
            questions: questions,
            index: 0,
            userPrompt: userPrompt,
            aggregatedChatGPT: []
        )
    }
    
    private func processQuestionSequentially(
        questions: [ExtractedQuestion],
        index: Int,
        userPrompt: String,
        aggregatedChatGPT: [String]
    ) {
        guard index < questions.count else {
            let finalChatGPT = aggregatedChatGPT.joined(separator: "\n\n")
            
            if !finalChatGPT.isEmpty {
                overwriteLatestResponse(finalChatGPT, type: "chatgpt")
            }
            
            if !finalChatGPT.isEmpty {
                sendToMessengers(message: "🤖 ChatGPT\n\n\(finalChatGPT)", serviceName: "ChatGPT")
            }
            if !finalChatGPT.isEmpty {
                sendCombinedMessageToVK(chatgpt: finalChatGPT, deepseek: nil)
                sendResponsesToBackend(chatgpt: finalChatGPT, deepseek: nil)
            }
            return
        }
        
        let question = questions[index]
        let questionNumber = index + 1
        let total = questions.count
        
        let imageURLs = question.images.map(\.url).filter { !$0.isEmpty }
        let imageDataURLs = question.images.compactMap { image -> String? in
            guard let dataURL = image.dataURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !dataURL.isEmpty else { return nil }
            return dataURL
        }
        
        let imageList = imageURLs.isEmpty
            ? "Изображений нет."
            : imageURLs.map { "- \($0)" }.joined(separator: "\n")
        
        let extractionPrompt = """
        извлеки отсюда вопрос и варианты ответов, укажи тип выбора (одиночный/множественный), сохрани все важные детали.
        id вопроса: \(question.id)
        изображения в вопросе:
        \(imageList)
        
        html вопроса:
        \(question.html)
        """
        
        let extractionCompletion: (String) -> Void = { [weak self] extractedText in
            guard let self = self else { return }
            
            var contextBlock = """
            [Вопрос \(questionNumber)/\(total), id: \(question.id)]
            """
            if !imageURLs.isEmpty {
                contextBlock += "\nИзображения вопроса (URL):\n\(imageList)\n"
            }
            
            let finalContent = "\(contextBlock)\n\n\(extractedText)"
            let finalPrompt = "\(userPrompt)\n\n\(finalContent)"
            
            var nextChatGPT = aggregatedChatGPT
            
            let group = DispatchGroup()
            
            if self.deepSeekService.hasChatGPTToken {
                group.enter()
                self.deepSeekService.sendTextToChatGPT(prompt: finalPrompt, imageDataURLs: imageDataURLs) { result in
                    if case .success(let response) = result {
                        let chunk = "### Вопрос \(questionNumber)\n\(response)"
                        nextChatGPT.append(chunk)
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                let chatgptResult = nextChatGPT.joined(separator: "\n\n")
                
                if !chatgptResult.isEmpty {
                    self.overwriteLatestResponse(chatgptResult, type: "chatgpt")
                }
                
                self.processQuestionSequentially(
                    questions: questions,
                    index: index + 1,
                    userPrompt: userPrompt,
                    aggregatedChatGPT: nextChatGPT
                )
            }
        }
        
        if deepSeekService.hasDeepSeekKey {
            deepSeekService.sendTextToDeepSeek(prompt: extractionPrompt, includeSystemMessage: false) { result in
                switch result {
                case .success(let extractedText):
                    extractionCompletion(extractedText)
                case .failure:
                    extractionCompletion(question.html)
                }
            }
        } else {
            extractionCompletion(question.html)
        }
    }

    /// Отправляет текст только в ChatGPT (DeepSeek используется только для экстракции вопросов)
    private func sendToChatGPTOnly(content: String, userPrompt: String) {
        guard deepSeekService.hasChatGPTToken else {
            print("⚠️ Нет токена ChatGPT для отправки ответов")
            return
        }

        let finalPrompt = "\(userPrompt)\n\n\(content)"
        print("📤 Отправляю текст только в ChatGPT...")
        deepSeekService.sendTextToChatGPT(prompt: finalPrompt) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let response):
                self.saveResponse(response, type: "chatgpt")
                self.sendToMessengers(message: "🤖 ChatGPT\n\n\(response)", serviceName: "ChatGPT")
                self.sendCombinedMessageToVK(chatgpt: response, deepseek: nil)
                self.sendResponsesToBackend(chatgpt: response, deepseek: nil)
            case .failure(let error):
                print("❌ ChatGPT ошибка: \(error)")
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
        
        // ШАГ 2: Отправляем в ChatGPT через got_proxy если есть токен (с пользовательским промптом)
        if deepSeekService.hasChatGPTToken {
            group.enter()
            print("📤 ШАГ 2: Отправляю текст в ChatGPT (got_proxy) с пользовательским промптом...")
            deepSeekService.sendTextToChatGPT(prompt: finalPrompt) { result in
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
    
    /// Перезаписывает верхний (самый свежий) ответ, чтобы панель показывала накопление в реальном времени.
    private func overwriteLatestResponse(_ response: String, type: String = "deepseek") {
        let defaults = UserDefaults.standard
        let key = type == "chatgpt" ? "chatgptResponses" : "deepseekResponses"
        var responses = defaults.stringArray(forKey: key) ?? []
        
        if responses.isEmpty {
            responses = [response]
        } else {
            responses[0] = response
        }
        
        defaults.set(responses, forKey: key)
        if let groupDefaults = UserDefaults(suiteName: "group.com.orbit.app") {
            groupDefaults.set(responses, forKey: key)
        }
    }

    private func clearStoredResponses(type: String) {
        let defaults = UserDefaults.standard
        let key = type == "chatgpt" ? "chatgptResponses" : "deepseekResponses"
        defaults.set([], forKey: key)
        if let groupDefaults = UserDefaults(suiteName: "group.com.orbit.app") {
            groupDefaults.set([], forKey: key)
        }
    }
    
    private func parseQuestions(from raw: [[String: Any]]) -> [ExtractedQuestion] {
        raw.compactMap { item in
            guard let html = item["html"] as? String, !html.isEmpty else { return nil }
            let id = item["id"] as? String ?? UUID().uuidString
            let images: [ExtractedImage]
            
            if let structuredImages = item["images"] as? [[String: Any]] {
                images = structuredImages.compactMap { image in
                    let url = (image["url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let dataURL = (image["data_url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    if url.isEmpty && (dataURL == nil || dataURL?.isEmpty == true) {
                        return nil
                    }
                    return ExtractedImage(url: url, dataURL: dataURL)
                }
            } else {
                images = (item["images"] as? [String] ?? [])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { ExtractedImage(url: $0, dataURL: nil) }
            }
            
            return ExtractedQuestion(id: id, html: html, images: images)
        }
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

