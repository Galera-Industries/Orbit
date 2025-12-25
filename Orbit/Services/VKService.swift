//
//  VKService.swift
//  Orbit
//
//  Created by Auto on 2025.
//

import Foundation

final class VKService {
    static let shared = VKService()
    
    private let baseURL = "https://api.vk.com/method"
    private let apiVersion = "5.131"
    
    private var accessToken: String? {
        UserDefaults.standard.string(forKey: "vkAccessToken")
    }
    
    private var peerID: String? {
        UserDefaults.standard.string(forKey: "vkPeerID")
    }
    
    private init() {}
    
    /// Отправляет сообщение в VK
    func sendMessage(_ text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let accessToken = accessToken, !accessToken.isEmpty else {
            completion(.failure(VKError.tokenNotSet))
            return
        }
        
        guard let peerID = peerID, !peerID.isEmpty else {
            completion(.failure(VKError.peerIDNotSet))
            return
        }
        
        let urlString = "\(baseURL)/messages.send"
        guard let url = URL(string: urlString) else {
            completion(.failure(VKError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // random_id - обязательный параметр для предотвращения повторной отправки
        let randomID = Int.random(in: 0...Int.max)
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "peer_id", value: peerID),
            URLQueryItem(name: "message", value: text),
            URLQueryItem(name: "random_id", value: String(randomID)),
            URLQueryItem(name: "access_token", value: accessToken),
            URLQueryItem(name: "v", value: apiVersion)
        ]
        
        guard let bodyString = components.query else {
            completion(.failure(VKError.invalidURL))
            return
        }
        
        request.httpBody = bodyString.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(VKError.noData))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errorDict = json["error"] as? [String: Any] {
                        let errorMsg = errorDict["error_msg"] as? String ?? "Unknown VK API error"
                        let errorCode = errorDict["error_code"] as? Int ?? -1
                        completion(.failure(VKError.apiError(code: errorCode, message: errorMsg)))
                        return
                    }
                    
                    if let _ = json["response"] {
                        completion(.success(()))
                    } else {
                        completion(.failure(VKError.invalidResponse))
                    }
                } else {
                    completion(.failure(VKError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    /// Проверяет, что токен валидный
    func checkTokenStatus(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let accessToken = accessToken, !accessToken.isEmpty else {
            completion(.failure(VKError.tokenNotSet))
            return
        }
        
        let urlString = "\(baseURL)/users.get"
        guard let url = URL(string: urlString) else {
            completion(.failure(VKError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "access_token", value: accessToken),
            URLQueryItem(name: "v", value: apiVersion)
        ]
        
        guard let bodyString = components.query else {
            completion(.failure(VKError.invalidURL))
            return
        }
        
        request.httpBody = bodyString.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(VKError.noData))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errorDict = json["error"] as? [String: Any] {
                        let errorMsg = errorDict["error_msg"] as? String ?? "Unknown VK API error"
                        let errorCode = errorDict["error_code"] as? Int ?? -1
                        completion(.failure(VKError.apiError(code: errorCode, message: errorMsg)))
                        return
                    }
                    
                    if let _ = json["response"] as? [[String: Any]] {
                        completion(.success(true))
                    } else {
                        completion(.failure(VKError.invalidResponse))
                    }
                } else {
                    completion(.failure(VKError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

enum VKError: LocalizedError {
    case invalidURL
    case noData
    case invalidResponse
    case tokenNotSet
    case peerIDNotSet
    case apiError(code: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный URL"
        case .noData:
            return "Нет данных в ответе"
        case .invalidResponse:
            return "Неверный формат ответа"
        case .tokenNotSet:
            return "VK Access Token не установлен. Укажите токен в настройках скриншотов"
        case .peerIDNotSet:
            return "VK Peer ID не установлен. Укажите ID пользователя или беседы в настройках"
        case .apiError(let code, let message):
            return "Ошибка VK API (\(code)): \(message)"
        }
    }
}

