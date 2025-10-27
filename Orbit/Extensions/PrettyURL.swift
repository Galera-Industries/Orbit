//
//  PrettyURL.swift
//  Orbit
//
//  Created by Кирилл Исаев on 27.10.2025.
//

import Foundation

extension URL {
    var prettyPathWithTilde: String {
        precondition(isFileURL, "Expected file URL")
        let fullPath = path
        let home = NSHomeDirectory()
        if fullPath.hasPrefix(home) {
            let rel = String(fullPath.dropFirst(home.count))
            return "~" + (rel.isEmpty ? "" : rel)
        } else {
            return fullPath
        }
    }
}
