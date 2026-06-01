//
//  DeepSeekService.swift
//  Orbit
//
//  Created by Auto on 2025.
//

import Foundation

final class DeepSeekService {
    static let shared = DeepSeekService()
    
    private let deepSeekBaseURL = "https://api.deepseek.com/v1/chat/completions"
    private let chatGPTProxyBaseURL = "http://5.34.212.145:8000"
    private let elizaBaseURL = "https://api.eliza.yandex.net"
    
    private enum ChatGPTProvider: String {
        case proxy = "proxy"
        case eliza = "eliza"
    }
    
    private var deepSeekApiKey: String? {
        KeychainService.shared.get(forKey: "deepseekApiKey")
    }

    private var chatGPTToken: String? {
        KeychainService.shared.get(forKey: "chatGPTToken")
    }
    
    private var elizaToken: String? {
        KeychainService.shared.get(forKey: "elizaToken")
    }
    
    private var chatGPTProvider: ChatGPTProvider {
        let raw = UserDefaults.standard.string(forKey: "chatGPTProvider") ?? ChatGPTProvider.proxy.rawValue
        return ChatGPTProvider(rawValue: raw) ?? .proxy
    }
    
    private var preferredChatGPTModel: String? {
        let model = UserDefaults.standard.string(forKey: "chatGPTModel")?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let model, !model.isEmpty else { return nil }
        return model
    }
    
    private var defaultElizaModel: String {
        "gpt-5.5"
    }
    
    // Публичные свойства для проверки наличия ключей
    var hasChatGPTToken: Bool {
        switch chatGPTProvider {
        case .proxy:
            return chatGPTToken != nil
        case .eliza:
            return elizaToken != nil
        }
    }
    
    // Обратная совместимость (deprecated)
    var hasYandexToken: Bool {
        hasChatGPTToken
    }
    
    var hasDeepSeekKey: Bool {
        deepSeekApiKey != nil
    }
    
    private let backendURL = "http://158.160.149.37:8000"
//    private let backendURL = "http://localhost:8000"
    private init() {
        KeychainService.shared.migrateFromUserDefaults(key: "chatGPTToken")
        KeychainService.shared.migrateFromUserDefaults(key: "elizaToken")
        KeychainService.shared.migrateFromUserDefaults(key: "deepseekApiKey")
    }
    
    /// Отправляет скриншот в API с промптом (пробует ChatGPT через got_proxy)
    func sendScreenshot(_ imageBase64: String, prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        let systemMessage = UserDefaults.standard.string(forKey: "systemMessage")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSystemMessage = (systemMessage?.isEmpty == false) ? systemMessage : nil
        
        switch chatGPTProvider {
        case .proxy:
            if let chatGPTToken = chatGPTToken {
                sendToChatGPT(
                    imageBase64: imageBase64,
                    prompt: prompt,
                    systemMessage: finalSystemMessage,
                    model: preferredChatGPTModel,
                    token: chatGPTToken,
                    completion: completion
                )
                return
            }
        case .eliza:
            if let elizaToken = elizaToken {
                sendToElizaWithImage(
                    imageBase64: imageBase64,
                    prompt: prompt,
                    systemMessage: finalSystemMessage,
                    model: preferredChatGPTModel ?? defaultElizaModel,
                    token: elizaToken,
                    completion: completion
                )
                return
            }
        }
        
        // Если нет ключей, возвращаем ошибку
        completion(.failure(DeepSeekError.apiKeyNotSet))
    }
    
    /// Отправляет скриншот в ChatGPT через got_proxy (публичный метод)
    func sendToChatGPT(imageBase64: String, prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        let systemMessage = UserDefaults.standard.string(forKey: "systemMessage")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSystemMessage = (systemMessage?.isEmpty == false) ? systemMessage : nil
        
        switch chatGPTProvider {
        case .proxy:
            guard let token = chatGPTToken else {
                completion(.failure(DeepSeekError.apiKeyNotSet))
                return
            }
            sendToChatGPT(
                imageBase64: imageBase64,
                prompt: prompt,
                systemMessage: finalSystemMessage,
                model: preferredChatGPTModel,
                token: token,
                completion: completion
            )
        case .eliza:
            guard let token = elizaToken else {
                completion(.failure(DeepSeekError.apiKeyNotSet))
                return
            }
            sendToElizaWithImage(
                imageBase64: imageBase64,
                prompt: prompt,
                systemMessage: finalSystemMessage,
                model: preferredChatGPTModel ?? defaultElizaModel,
                token: token,
                completion: completion
            )
        }
    }
    
    // Обратная совместимость (deprecated)
    func sendToYandex(imageBase64: String, prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        sendToChatGPT(imageBase64: imageBase64, prompt: prompt, completion: completion)
    }
    
    /// Отправляет изображение в ChatGPT через got_proxy
    private func sendToChatGPT(
        imageBase64: String,
        prompt: String,
        systemMessage: String?,
        model: String?,
        token: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "\(chatGPTProxyBaseURL)/api/chat/image") else {
            completion(.failure(DeepSeekError.invalidURL))
            return
        }
        
        // Декодируем base64 в Data
        let base64String = imageBase64.hasPrefix("data:") ? 
            String(imageBase64.split(separator: ",").last ?? "") : 
            imageBase64
        
        guard let imageData = Data(base64Encoded: base64String) else {
            completion(.failure(DeepSeekError.invalidResponse))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120.0 // 2 минуты для больших запросов
        
        // Создаем multipart/form-data запрос
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Добавляем text
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"text\"\r\n\r\n".data(using: .utf8)!)
        body.append(prompt.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Добавляем image
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Добавляем api_key
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"api_key\"\r\n\r\n".data(using: .utf8)!)
        body.append(token.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Добавляем model если задана в настройках
        if let model, !model.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
            body.append(model.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Добавляем system_message если задан
        if let systemMessage = systemMessage, !systemMessage.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"system_message\"\r\n\r\n".data(using: .utf8)!)
            body.append(systemMessage.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Закрываем boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("📤 ChatGPT (got_proxy) image request: prompt length=\(prompt.count), image size=\(imageData.count) bytes")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ ChatGPT (got_proxy) API error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(DeepSeekError.invalidResponse))
                return
            }
            
            guard let data = data else {
                completion(.failure(DeepSeekError.noData))
                return
            }
            
            // Логируем ответ для отладки
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 ChatGPT (got_proxy) API response (status \(httpResponse.statusCode)): \(responseString.prefix(500))")
            }
            
            // Проверяем статус код
            guard (200...299).contains(httpResponse.statusCode) else {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let detail = json["detail"] as? String {
                        completion(.failure(DeepSeekError.apiError(detail, httpResponse.statusCode)))
                    } else {
                        completion(.failure(DeepSeekError.httpError(httpResponse.statusCode)))
                    }
                } catch {
                    completion(.failure(DeepSeekError.httpError(httpResponse.statusCode)))
                }
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(DeepSeekError.invalidResponse))
                    return
                }
                
                // got_proxy возвращает ответ в формате {"response": "...", "model": "..."}
                if let response = json["response"] as? String {
                    completion(.success(response))
                } else {
                    print("⚠️ ChatGPT (got_proxy) response structure: \(json.keys)")
                    completion(.failure(DeepSeekError.invalidResponse))
                }
            } catch {
                print("❌ ChatGPT (got_proxy) JSON parsing error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    /// Отправляет текстовый запрос в DeepSeek (публичный метод)
    func sendTextToDeepSeek(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        sendTextToDeepSeek(prompt: prompt, includeSystemMessage: true, completion: completion)
    }
    
    /// Отправляет текстовый запрос в DeepSeek (публичный метод с контролем system message)
    func sendTextToDeepSeek(prompt: String, includeSystemMessage: Bool, completion: @escaping (Result<String, Error>) -> Void) {
        let systemMessage: String?
        if includeSystemMessage {
            let systemMsg = UserDefaults.standard.string(forKey: "systemMessage")?.trimmingCharacters(in: .whitespacesAndNewlines)
            systemMessage = (systemMsg?.isEmpty == false) ? systemMsg : nil
        } else {
            systemMessage = nil
        }
        sendToDeepSeekWithoutImage(prompt: prompt, systemMessage: systemMessage, completion: completion)
    }
    
    /// Отправляет текстовый запрос в ChatGPT через got_proxy (публичный метод)
    func sendTextToChatGPT(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        let systemMessage = UserDefaults.standard.string(forKey: "systemMessage")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSystemMessage = (systemMessage?.isEmpty == false) ? systemMessage : nil
        
        switch chatGPTProvider {
        case .proxy:
            guard let token = chatGPTToken else {
                completion(.failure(DeepSeekError.apiKeyNotSet))
                return
            }
            sendTextToChatGPT(
                prompt: prompt,
                systemMessage: finalSystemMessage,
                model: preferredChatGPTModel,
                token: token,
                completion: completion
            )
        case .eliza:
            guard let token = elizaToken else {
                completion(.failure(DeepSeekError.apiKeyNotSet))
                return
            }
            sendTextToEliza(
                prompt: prompt,
                systemMessage: finalSystemMessage,
                model: preferredChatGPTModel ?? defaultElizaModel,
                token: token,
                completion: completion
            )
        }
    }
    
    /// Отправляет текстовый запрос с изображениями.
    /// Для Eliza изображения передаются как image_url (data URI).
    /// Для got_proxy выполняется fallback на текстовый запрос.
    func sendTextToChatGPT(
        prompt: String,
        imageDataURLs: [String],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let systemMessage = UserDefaults.standard.string(forKey: "systemMessage")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSystemMessage = (systemMessage?.isEmpty == false) ? systemMessage : nil
        
        switch chatGPTProvider {
        case .proxy:
            sendTextToChatGPT(prompt: prompt, completion: completion)
        case .eliza:
            guard let token = elizaToken else {
                completion(.failure(DeepSeekError.apiKeyNotSet))
                return
            }
            sendTextToEliza(
                prompt: prompt,
                systemMessage: finalSystemMessage,
                model: preferredChatGPTModel ?? defaultElizaModel,
                imageDataURLs: imageDataURLs,
                token: token,
                completion: completion
            )
        }
    }
    
    // Обратная совместимость (deprecated)
    func sendTextToYandex(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        sendTextToChatGPT(prompt: prompt, completion: completion)
    }
    
    /// Отправляет текстовый запрос в ChatGPT через got_proxy (приватный метод)
    private func sendTextToChatGPT(
        prompt: String,
        systemMessage: String?,
        model: String?,
        token: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "\(chatGPTProxyBaseURL)/api/chat/text") else {
            completion(.failure(DeepSeekError.invalidURL))
            return
        }
        
        var requestBody: [String: Any] = [
            "text": prompt,
            "api_key": token
        ]
        
        // Передаем выбранную модель, если задана
        if let model, !model.isEmpty {
            requestBody["model"] = model
        }
        
        // Добавляем system_message если задан
        if let systemMessage = systemMessage, !systemMessage.isEmpty {
            requestBody["system_message"] = systemMessage
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120.0 // 2 минуты для больших запросов
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        print("📤 ChatGPT (got_proxy) text request: prompt length=\(prompt.count)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ ChatGPT (got_proxy) API error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(DeepSeekError.invalidResponse))
                return
            }
            
            guard let data = data else {
                completion(.failure(DeepSeekError.noData))
                return
            }
            
            // Логируем ответ для отладки
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 ChatGPT (got_proxy) API response (status \(httpResponse.statusCode)): \(responseString.prefix(500))")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let detail = json["detail"] as? String {
                        completion(.failure(DeepSeekError.apiError(detail, httpResponse.statusCode)))
                    } else {
                        completion(.failure(DeepSeekError.httpError(httpResponse.statusCode)))
                    }
                } catch {
                    completion(.failure(DeepSeekError.httpError(httpResponse.statusCode)))
                }
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(DeepSeekError.invalidResponse))
                    return
                }
                
                // got_proxy возвращает ответ в формате {"response": "...", "model": "..."}
                if let response = json["response"] as? String {
                    completion(.success(response))
                } else {
                    print("⚠️ ChatGPT (got_proxy) response structure: \(json.keys)")
                    completion(.failure(DeepSeekError.invalidResponse))
                }
            } catch {
                print("❌ ChatGPT (got_proxy) JSON parsing error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    /// Отправляет в DeepSeek без изображения (так как не поддерживается)
    private func sendToDeepSeekWithoutImage(prompt: String, systemMessage: String?, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = deepSeekApiKey, !apiKey.isEmpty else {
            completion(.failure(DeepSeekError.apiKeyNotSet))
            return
        }
        
        // DeepSeek не поддерживает изображения, отправляем только текстовый промпт
        var messages: [[String: Any]] = []
        
        // Добавляем system message если задан
        if let systemMessage = systemMessage, !systemMessage.isEmpty {
            messages.append([
                "role": "system",
                "content": systemMessage
            ])
        }
        
        // Добавляем user message
        messages.append([
            "role": "user",
            "content": "\(prompt)\n\nПримечание: К сожалению, DeepSeek API не поддерживает анализ изображений. Пожалуйста, опишите содержимое скриншота текстом, или используйте OpenAI API для анализа изображений."
        ])
        
        let requestBody: [String: Any] = [
            "model": "deepseek-chat",
            "messages": messages,
            "max_tokens": 8192
        ]
        
        sendRequest(to: deepSeekBaseURL, apiKey: apiKey, requestBody: requestBody, completion: completion)
    }
    
    private func sendTextToEliza(
        prompt: String,
        systemMessage: String?,
        model: String,
        token: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        var messages: [[String: Any]] = []
        
        if let systemMessage, !systemMessage.isEmpty {
            messages.append([
                "role": "system",
                "content": systemMessage
            ])
        }
        
        messages.append([
            "role": "user",
            "content": prompt
        ])
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages
        ]
        
        sendElizaRequest(
            endpoint: elizaEndpoint(for: model),
            token: token,
            requestBody: requestBody,
            completion: completion
        )
    }
    
    private func sendTextToEliza(
        prompt: String,
        systemMessage: String?,
        model: String,
        imageDataURLs: [String],
        token: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        var messages: [[String: Any]] = []
        
        if let systemMessage, !systemMessage.isEmpty {
            messages.append([
                "role": "system",
                "content": systemMessage
            ])
        }
        
        var contentParts: [[String: Any]] = [
            [
                "type": "text",
                "text": prompt
            ]
        ]
        
        for imagePayload in imageDataURLs {
            if let normalizedImage = normalizedImageDataURL(from: imagePayload) {
                contentParts.append([
                    "type": "image_url",
                    "image_url": [
                        "url": normalizedImage
                    ]
                ])
            }
        }
        
        messages.append([
            "role": "user",
            "content": contentParts
        ])
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages
        ]
        
        sendElizaRequest(
            endpoint: elizaEndpoint(for: model),
            token: token,
            requestBody: requestBody,
            completion: completion
        )
    }
    
    private func sendToElizaWithImage(
        imageBase64: String,
        prompt: String,
        systemMessage: String?,
        model: String,
        token: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let normalizedBase64 = normalizedImageDataURL(from: imageBase64) else {
            completion(.failure(DeepSeekError.invalidResponse))
            return
        }
        
        var messages: [[String: Any]] = []
        
        if let systemMessage, !systemMessage.isEmpty {
            messages.append([
                "role": "system",
                "content": systemMessage
            ])
        }
        
        messages.append([
            "role": "user",
            "content": [
                [
                    "type": "text",
                    "text": prompt
                ],
                [
                    "type": "image_url",
                    "image_url": [
                        "url": normalizedBase64
                    ]
                ]
            ]
        ])
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages
        ]
        
        sendElizaRequest(
            endpoint: elizaEndpoint(for: model),
            token: token,
            requestBody: requestBody,
            completion: completion
        )
    }
    
    private func normalizedImageDataURL(from payload: String) -> String? {
        if payload.hasPrefix("data:image/") {
            return payload
        }
        
        guard let data = Data(base64Encoded: payload) else {
            return nil
        }
        
        let mimeType = Self.detectImageMimeType(from: data)
        return "data:\(mimeType);base64,\(payload)"
    }
    
    private static func detectImageMimeType(from data: Data) -> String {
        if data.count >= 8 {
            let signature = [UInt8](data.prefix(8))
            if signature[0] == 0x89,
               signature[1] == 0x50,
               signature[2] == 0x4E,
               signature[3] == 0x47 {
                return "image/png"
            }
        }
        
        if data.count >= 3 {
            let signature = [UInt8](data.prefix(3))
            if signature[0] == 0xFF, signature[1] == 0xD8, signature[2] == 0xFF {
                return "image/jpeg"
            }
        }
        
        if data.count >= 6, let header = String(data: data.prefix(6), encoding: .ascii) {
            if header == "GIF87a" || header == "GIF89a" {
                return "image/gif"
            }
        }
        
        if data.count >= 12, let riff = String(data: data.prefix(4), encoding: .ascii) {
            let webp = String(data: data.dropFirst(8).prefix(4), encoding: .ascii)
            if riff == "RIFF", webp == "WEBP" {
                return "image/webp"
            }
        }
        
        return "image/png"
    }
    
    private func elizaEndpoint(for model: String) -> String {
        let lowercasedModel = model.lowercased()
        if lowercasedModel.contains("/") {
            return "/openrouter/v1/chat/completions"
        }
        return "/openai/v1/chat/completions"
    }
    
    private func sendElizaRequest(
        endpoint: String,
        token: String,
        requestBody: [String: Any],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "\(elizaBaseURL)\(endpoint)") else {
            completion(.failure(DeepSeekError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(DeepSeekError.invalidResponse))
                return
            }
            
            guard let data = data else {
                completion(.failure(DeepSeekError.noData))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let message = Self.extractErrorMessage(from: json) {
                            completion(.failure(DeepSeekError.apiError(message, httpResponse.statusCode)))
                        } else {
                            completion(.failure(DeepSeekError.httpError(httpResponse.statusCode)))
                        }
                    } else {
                        completion(.failure(DeepSeekError.httpError(httpResponse.statusCode)))
                    }
                } catch {
                    completion(.failure(DeepSeekError.httpError(httpResponse.statusCode)))
                }
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(DeepSeekError.invalidResponse))
                    return
                }
                
                if let responseText = json["response"] as? String, !responseText.isEmpty {
                    completion(.success(responseText))
                    return
                }
                
                if let wrappedResponse = json["response"] as? [String: Any],
                   let content = Self.extractAssistantContent(from: wrappedResponse) {
                    completion(.success(content))
                    return
                }
                
                if let content = Self.extractAssistantContent(from: json) {
                    completion(.success(content))
                    return
                }
                
                completion(.failure(DeepSeekError.invalidResponse))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private static func extractErrorMessage(from json: [String: Any]) -> String? {
        if let errorText = json["error"] as? String, !errorText.isEmpty {
            return errorText
        }
        if let detail = json["detail"] as? String, !detail.isEmpty {
            return detail
        }
        if let errorObject = json["error"] as? [String: Any],
           let message = errorObject["message"] as? String,
           !message.isEmpty {
            return message
        }
        if let detailObject = json["detail"] as? [String: Any],
           let message = detailObject["message"] as? String,
           !message.isEmpty {
            return message
        }
        return nil
    }
    
    private static func extractAssistantContent(from responseJSON: [String: Any]) -> String? {
        if let choices = responseJSON["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = extractContentText(from: message["content"]) {
            return content
        }
        
        if let message = responseJSON["message"] as? [String: Any],
           let content = extractContentText(from: message["content"]) {
            return content
        }
        
        if let content = extractContentText(from: responseJSON["content"]) {
            return content
        }
        
        return nil
    }
    
    private static func extractContentText(from rawContent: Any?) -> String? {
        if let content = rawContent as? String, !content.isEmpty {
            return content
        }
        
        if let arrayContent = rawContent as? [[String: Any]] {
            let parts = arrayContent.compactMap { item -> String? in
                if let text = item["text"] as? String, !text.isEmpty {
                    return text
                }
                if let type = item["type"] as? String,
                   type == "text",
                   let text = item["value"] as? String,
                   !text.isEmpty {
                    return text
                }
                return nil
            }
            
            if !parts.isEmpty {
                return parts.joined(separator: "\n")
            }
        }
        
        return nil
    }
    
    /// Общий метод для отправки запроса
    private func sendRequest(to urlString: String, apiKey: String, requestBody: [String: Any], completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(DeepSeekError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Увеличиваем таймаут для больших запросов (DeepSeek может долго обрабатывать большие тексты)
        request.timeoutInterval = 180.0 // 3 минуты вместо стандартных 60 секунд
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Логируем запрос для отладки (без изображения в base64)
        if let jsonData = try? JSONSerialization.data(withJSONObject: requestBody),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let logString = jsonString.replacingOccurrences(of: #"data:image/png;base64,[^"]+"#, with: "[IMAGE_DATA]", options: .regularExpression)
            print("API request to \(urlString): \(logString.prefix(500))")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("API error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(DeepSeekError.invalidResponse))
                return
            }
            
            guard let data = data else {
                completion(.failure(DeepSeekError.noData))
                return
            }
            
            // Логируем ответ для отладки
            if let responseString = String(data: data, encoding: .utf8) {
                print("API response from \(urlString) (status \(httpResponse.statusCode)): \(responseString.prefix(500))")
            }
            
            // Проверяем статус код
            guard (200...299).contains(httpResponse.statusCode) else {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        completion(.failure(DeepSeekError.apiError(message, httpResponse.statusCode)))
                    } else {
                        completion(.failure(DeepSeekError.httpError(httpResponse.statusCode)))
                    }
                } catch {
                    completion(.failure(DeepSeekError.httpError(httpResponse.statusCode)))
                }
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(DeepSeekError.invalidResponse))
                    return
                }
                
                // Проверяем наличие ошибки в ответе
                if let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    completion(.failure(DeepSeekError.apiError(message, httpResponse.statusCode)))
                    return
                }
                
                // Парсим успешный ответ
                if let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content))
                } else {
                    // Пробуем альтернативный формат ответа
                    if let content = json["content"] as? String {
                        completion(.success(content))
                    } else {
                        print("DeepSeek response structure: \(json.keys)")
                        completion(.failure(DeepSeekError.invalidResponse))
                    }
                }
            } catch {
                print("DeepSeek JSON parsing error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
}

enum DeepSeekError: LocalizedError {
    case apiKeyNotSet
    case invalidURL
    case noData
    case invalidResponse
    case httpError(Int)
    case apiError(String, Int)
    
    var errorDescription: String? {
        switch self {
        case .apiKeyNotSet:
            return "DeepSeek API key не установлен"
        case .invalidURL:
            return "Неверный URL"
        case .noData:
            return "Нет данных в ответе"
        case .invalidResponse:
            return "Неверный формат ответа"
        case .httpError(let code):
            return "HTTP ошибка: \(code)"
        case .apiError(let message, let code):
            return "API ошибка (\(code)): \(message)"
        }
    }
}


