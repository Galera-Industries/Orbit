//
//  Shell.swift
//  Orbit
//
//  Created by Ulyana Eskova on 03.11.2025.
//


import Foundation

enum Shell {
    @discardableResult
    static func run(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe
        process.arguments = ["-c", command]
        process.launchPath = "/bin/zsh" // используем zsh, чтобы работали алиасы и переменные окружения

        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}