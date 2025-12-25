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
    private let yandexBaseURL = "https://api.eliza.yandex.net/openai/v1/chat/completions"
    
    private var deepSeekApiKey: String? {
        let key = UserDefaults.standard.string(forKey: "deepseekApiKey")
        return (key?.isEmpty == false) ? key : nil
    }
    
    private var yandexToken: String? {
        let token = UserDefaults.standard.string(forKey: "yandexToken")
        return (token?.isEmpty == false) ? token : nil
    }
    
    // Публичные свойства для проверки наличия ключей
    var hasYandexToken: Bool {
        yandexToken != nil
    }
    
    var hasDeepSeekKey: Bool {
        deepSeekApiKey != nil
    }
    
    private let backendURL = "http://158.160.149.37:8000"
//    private let backendURL = "http://localhost:8000"
    private init() {}
    
    /// Отправляет скриншот в API с промптом (пробует Yandex)
    func sendScreenshot(_ imageBase64: String, prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Пробуем Yandex API (если есть токен)
        if let yandexToken = yandexToken {
            sendToYandex(imageBase64: imageBase64, prompt: prompt, token: yandexToken, completion: completion)
            return
        }
        
        // Если нет ключей, возвращаем ошибку
        completion(.failure(DeepSeekError.apiKeyNotSet))
    }
    
    /// Отправляет скриншот в Yandex API (публичный метод)
    func sendToYandex(imageBase64: String, prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let token = yandexToken else {
            completion(.failure(DeepSeekError.apiKeyNotSet))
            return
        }
        sendToYandex(imageBase64: imageBase64, prompt: prompt, token: token, completion: completion)
    }
    
    /// Отправляет в Yandex API (GPT-5.2)
    private func sendToYandex(imageBase64: String, prompt: String, token: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Yandex API поддерживает только: text, image_url, input_audio, refusal, audio, file
        // Используем image_url (стандартный формат OpenAI)
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": prompt
                    ],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": imageBase64.hasPrefix("data:") ? imageBase64 : "data:image/png;base64,\(imageBase64)"
                        ]
                    ]
                ]
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-5.2-chat-latest",
            "messages": messages,
            "max_completion_tokens": 20000  // Yandex API использует max_completion_tokens вместо max_tokens
        ]
        
        guard let url = URL(string: yandexBaseURL) else {
            completion(.failure(DeepSeekError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120.0 // 2 минуты для больших запросов
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            
            // Логируем размер тела запроса для отладки
            if let bodySize = request.httpBody?.count {
                print("Размер тела запроса: \(bodySize) bytes")
            }
        } catch {
            print("Ошибка сериализации JSON: \(error)")
            completion(.failure(error))
            return
        }
        
        // Логируем запрос для отладки
        if let jsonData = try? JSONSerialization.data(withJSONObject: requestBody),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let logString = jsonString.replacingOccurrences(of: #"data:image/[^;]+;base64,[^"]+"#, with: "[IMAGE_DATA]", options: .regularExpression)
            print("Yandex API request: \(logString.prefix(500))")
            print("Image base64 length: \(imageBase64.count) characters")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Yandex API error: \(error.localizedDescription)")
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
                print("Yandex API response (status \(httpResponse.statusCode)): \(responseString.prefix(500))")
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
                
                // Yandex API возвращает ответ в формате {"response": {...}}
                if let response = json["response"] as? [String: Any],
                   let choices = response["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    // Проверяем, не говорит ли API, что изображение не было передано
                    if content.lowercased().contains("без вопросов") || 
                       content.lowercased().contains("пришли") ||
                       content.lowercased().contains("фото") {
                        print("⚠️ Yandex API не получил изображение. Пробуем альтернативный формат...")
                        // Пробуем альтернативный формат с image вместо image_url
                        self.sendToYandexAlternativeFormat(imageBase64: imageBase64, prompt: prompt, token: token, completion: completion)
                        return
                    }
                    completion(.success(content))
                } else if let response = json["response"] as? [String: Any],
                          let error = response["error"] as? [String: Any],
                          let message = error["message"] as? String {
                    completion(.failure(DeepSeekError.apiError(message, httpResponse.statusCode)))
                } else {
                    print("Yandex response structure: \(json.keys)")
                    completion(.failure(DeepSeekError.invalidResponse))
                }
            } catch {
                print("Yandex JSON parsing error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    /// Альтернативный формат для Yandex API (пробуем другой формат image_url)
    private func sendToYandexAlternativeFormat(imageBase64: String, prompt: String, token: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Пробуем формат с image_url, но с другим форматом URL
        // Может быть нужно без data: префикса или другой формат
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": prompt
                    ],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": imageBase64.hasPrefix("data:") ? imageBase64 : "data:image/png;base64,\(imageBase64)",
                            "detail": "high"  // Добавляем detail для лучшего качества
                        ]
                    ]
                ]
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-5.2-chat-latest",
            "messages": messages,
            "max_completion_tokens": 20000
        ]
        
        guard let url = URL(string: yandexBaseURL) else {
            completion(.failure(DeepSeekError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("Yandex API alternative format request (with image base64 directly)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Yandex API alternative format error: \(error.localizedDescription)")
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
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("Yandex API alternative format response (status \(httpResponse.statusCode)): \(responseString.prefix(500))")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let response = json["response"] as? [String: Any],
                       let error = response["error"] as? [String: Any],
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
                
                if let response = json["response"] as? [String: Any],
                   let choices = response["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content))
                } else {
                    completion(.failure(DeepSeekError.invalidResponse))
                }
            } catch {
                print("Yandex JSON parsing error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    /// Отправляет текстовый запрос в DeepSeek (публичный метод)
    func sendTextToDeepSeek(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        sendToDeepSeekWithoutImage(prompt: prompt, completion: completion)
    }
    
    /// Отправляет текстовый запрос в Yandex GPT-5.2-chat-latest (публичный метод)
    func sendTextToYandex(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let token = yandexToken else {
            completion(.failure(DeepSeekError.apiKeyNotSet))
            return
        }
        sendTextToYandex(prompt: prompt, token: token, completion: completion)
    }
    
    /// Отправляет текстовый запрос в Yandex GPT-5.2-chat-latest (приватный метод)
    private func sendTextToYandex(prompt: String, token: String, completion: @escaping (Result<String, Error>) -> Void) {
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": prompt
                    ]
                ]
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-5.2-chat-latest",
            "messages": messages,
            "max_completion_tokens": 20000
        ]
        
        guard let url = URL(string: yandexBaseURL) else {
            completion(.failure(DeepSeekError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120.0 // 2 минуты для больших запросов
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
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
                
                if let response = json["response"] as? [String: Any],
                   let choices = response["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content))
                } else {
                    completion(.failure(DeepSeekError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    /// Отправляет в DeepSeek без изображения (так как не поддерживается)
    private func sendToDeepSeekWithoutImage(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = deepSeekApiKey, !apiKey.isEmpty else {
            completion(.failure(DeepSeekError.apiKeyNotSet))
            return
        }
        
        // DeepSeek не поддерживает изображения, отправляем только текстовый промпт
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": "\(prompt)\n\nПримечание: К сожалению, DeepSeek API не поддерживает анализ изображений. Пожалуйста, опишите содержимое скриншота текстом, или используйте OpenAI API для анализа изображений."
            ]
        ]
        
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


