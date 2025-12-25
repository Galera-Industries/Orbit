//
//  TelegramBotService.swift
//  Orbit
//
//  Created by Auto on 2025.
//

import Foundation

final class TelegramBotService {
    static let shared = TelegramBotService()
    
    private let baseURL = "https://api.telegram.org/bot"
    
    private var token: String? {
        UserDefaults.standard.string(forKey: "telegramBotToken")
    }
    
    private var chatID: String? {
        UserDefaults.standard.string(forKey: "telegramChatID")
    }
    
    private init() {}
    
    /// Отправляет сообщение в Telegram
    func sendMessage(_ text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let token = token, !token.isEmpty else {
            completion(.failure(TelegramError.tokenNotSet))
            return
        }
        
        guard let chatID = chatID, !chatID.isEmpty else {
            // Если chatID не установлен, попробуем получить его из обновлений
            fetchChatID { [weak self] result in
                switch result {
                case .success:
                    self?.sendMessage(text, completion: completion)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            return
        }
        
        let urlString = "\(baseURL)\(token)/sendMessage"
        guard let url = URL(string: urlString) else {
            completion(.failure(TelegramError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "chat_id": chatID,
            "text": text
            // Убираем parse_mode для избежания ошибок парсинга Markdown
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(TelegramError.httpError))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
    
    /// Проверяет, что бот работает
    func checkBotStatus(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let token = token, !token.isEmpty else {
            completion(.failure(TelegramError.tokenNotSet))
            return
        }
        
        let urlString = "\(baseURL)\(token)/getMe"
        guard let url = URL(string: urlString) else {
            completion(.failure(TelegramError.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(TelegramError.noData))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let ok = json["ok"] as? Bool {
                    completion(.success(ok))
                } else {
                    completion(.failure(TelegramError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    /// Получает обновления от бота (для определения chat_id)
    func getUpdates(completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        guard let token = token, !token.isEmpty else {
            completion(.failure(TelegramError.tokenNotSet))
            return
        }
        
        let urlString = "\(baseURL)\(token)/getUpdates?offset=-10"
        guard let url = URL(string: urlString) else {
            completion(.failure(TelegramError.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(TelegramError.noData))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let ok = json["ok"] as? Bool, !ok {
                        if let description = json["description"] as? String {
                            completion(.failure(TelegramError.botError(description)))
                        } else {
                            completion(.failure(TelegramError.invalidResponse))
                        }
                        return
                    }
                    
                    if let result = json["result"] as? [[String: Any]] {
                        completion(.success(result))
                    } else {
                        completion(.failure(TelegramError.invalidResponse))
                    }
                } else {
                    completion(.failure(TelegramError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    /// Пытается получить chat_id из обновлений
    func fetchChatID(completion: @escaping (Result<String, Error>) -> Void) {
        getUpdates { result in
            switch result {
            case .success(let updates):
                // Ищем chat_id в последних обновлениях
                for update in updates.reversed() {
                    if let message = update["message"] as? [String: Any],
                       let chat = message["chat"] as? [String: Any],
                       let id = chat["id"] as? Int {
                        let chatIDString = String(id)
                        UserDefaults.standard.set(chatIDString, forKey: "telegramChatID")
                        completion(.success(chatIDString))
                        return
                    }
                }
                completion(.failure(TelegramError.chatIDNotSet))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

enum TelegramError: LocalizedError {
    case invalidURL
    case noData
    case invalidResponse
    case httpError
    case tokenNotSet
    case chatIDNotSet
    case botError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный URL"
        case .noData:
            return "Нет данных в ответе"
        case .invalidResponse:
            return "Неверный формат ответа"
        case .httpError:
            return "Ошибка HTTP запроса"
        case .tokenNotSet:
            return "Telegram Bot Token не установлен. Укажите токен в настройках скриншотов"
        case .chatIDNotSet:
            return "Chat ID не установлен. Отправьте любое сообщение боту в Telegram"
        case .botError(let message):
            return "Ошибка бота: \(message)"
        }
    }
}


