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
    
    private var deepSeekApiKey: String? {
        let key = UserDefaults.standard.string(forKey: "deepseekApiKey")
        return (key?.isEmpty == false) ? key : nil
    }
    
    private var chatGPTToken: String? {
        let token = UserDefaults.standard.string(forKey: "chatGPTToken")
        return (token?.isEmpty == false) ? token : nil
    }
    
    // Публичные свойства для проверки наличия ключей
    var hasChatGPTToken: Bool {
        chatGPTToken != nil
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
    private init() {}
    
    /// Отправляет скриншот в API с промптом (пробует ChatGPT через got_proxy)
    func sendScreenshot(_ imageBase64: String, prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Пробуем ChatGPT через got_proxy (если есть токен)
        if let chatGPTToken = chatGPTToken {
            let systemMessage = UserDefaults.standard.string(forKey: "systemMessage")?.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalSystemMessage = (systemMessage?.isEmpty == false) ? systemMessage : nil
            sendToChatGPT(imageBase64: imageBase64, prompt: prompt, systemMessage: finalSystemMessage, token: chatGPTToken, completion: completion)
            return
        }
        
        // Если нет ключей, возвращаем ошибку
        completion(.failure(DeepSeekError.apiKeyNotSet))
    }
    
    /// Отправляет скриншот в ChatGPT через got_proxy (публичный метод)
    func sendToChatGPT(imageBase64: String, prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let token = chatGPTToken else {
            completion(.failure(DeepSeekError.apiKeyNotSet))
            return
        }
        let systemMessage = UserDefaults.standard.string(forKey: "systemMessage")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSystemMessage = (systemMessage?.isEmpty == false) ? systemMessage : nil
        sendToChatGPT(imageBase64: imageBase64, prompt: prompt, systemMessage: finalSystemMessage, token: token, completion: completion)
    }
    
    // Обратная совместимость (deprecated)
    func sendToYandex(imageBase64: String, prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        sendToChatGPT(imageBase64: imageBase64, prompt: prompt, completion: completion)
    }
    
    /// Отправляет изображение в ChatGPT через got_proxy
    private func sendToChatGPT(imageBase64: String, prompt: String, systemMessage: String?, token: String, completion: @escaping (Result<String, Error>) -> Void) {
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
        guard let token = chatGPTToken else {
            completion(.failure(DeepSeekError.apiKeyNotSet))
            return
        }
        let systemMessage = UserDefaults.standard.string(forKey: "systemMessage")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSystemMessage = (systemMessage?.isEmpty == false) ? systemMessage : nil
        sendTextToChatGPT(prompt: prompt, systemMessage: finalSystemMessage, token: token, completion: completion)
    }
    
    // Обратная совместимость (deprecated)
    func sendTextToYandex(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        sendTextToChatGPT(prompt: prompt, completion: completion)
    }
    
    /// Отправляет текстовый запрос в ChatGPT через got_proxy (приватный метод)
    private func sendTextToChatGPT(prompt: String, systemMessage: String?, token: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(chatGPTProxyBaseURL)/api/chat/text") else {
            completion(.failure(DeepSeekError.invalidURL))
            return
        }
        
        var requestBody: [String: Any] = [
            "text": prompt,
            "api_key": token
        ]
        
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


