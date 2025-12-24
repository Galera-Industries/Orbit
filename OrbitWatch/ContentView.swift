//
//  ContentView.swift
//  OrbitWatch
//
//  Created by Auto on 2025.
//

import SwiftUI

struct ContentView: View {
    @State private var responses: [String] = []
    @State private var currentIndex: Int = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack {
            if responses.isEmpty {
                Text("Нет ответов")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(responses[currentIndex])
                            .font(.body)
                            .padding()
                    }
                }
                
                HStack {
                    Button(action: {
                        if currentIndex > 0 {
                            currentIndex -= 1
                        }
                    }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentIndex == 0)
                    
                    Spacer()
                    
                    Text("\(currentIndex + 1)/\(responses.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        if currentIndex < responses.count - 1 {
                            currentIndex += 1
                        }
                    }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentIndex == responses.count - 1)
                }
                .padding()
            }
        }
        .onAppear {
            loadResponses()
            // Периодически проверяем обновления (так как NotificationCenter не работает между macOS и watchOS)
            timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                loadResponses()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 50 {
                        // Свайп вправо - предыдущий ответ
                        if currentIndex > 0 {
                            currentIndex -= 1
                        }
                    } else if value.translation.width < -50 {
                        // Свайп влево - следующий ответ
                        if currentIndex < responses.count - 1 {
                            currentIndex += 1
                        }
                    }
                }
        )
    }
    
    private func loadResponses() {
        // Используем App Group для обмена данными с macOS приложением
        // Если App Group не настроен, используем стандартный UserDefaults
        let defaults: UserDefaults
        if let groupDefaults = UserDefaults(suiteName: "group.com.orbit.app") {
            defaults = groupDefaults
        } else {
            defaults = UserDefaults.standard
        }
        
        responses = defaults.stringArray(forKey: "deepseekResponses") ?? []
        if currentIndex >= responses.count {
            currentIndex = max(0, responses.count - 1)
        }
    }
}

