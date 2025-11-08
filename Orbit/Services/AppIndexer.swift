//
//  AppIndexer.swift
//  Orbit
//
//  Created by Tom Tim on 08.11.2025.
//

import Foundation
import AppKit

struct AppItem {
    let name: String
    let lowercasedName: String
    let url: URL
    let bundleIdentifier: String?
    func icon() -> NSImage { NSWorkspace.shared.icon(forFile: url.path) }
}

final class AppIndexer {
    private(set) var apps: [AppItem] = []
    private let queue = DispatchQueue(label: "appindexer", qos: .userInitiated)
    
    func buildIndex(completion: (() -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }
            var found: [AppItem] = []
            let fm = FileManager.default
            let locations = [
                "/Applications",
                "/System/Applications",
                "\(NSHomeDirectory())/Applications"
            ]
            for loc in locations {
                let folder = URL(fileURLWithPath: loc, isDirectory: true)
                if let names = try? fm.contentsOfDirectory(atPath: folder.path) {
                    for name in names {
                        if name.hasSuffix(".app") {
                            let url = folder.appendingPathComponent(name)
                            var bundleId: String? = nil
                            if let bundle = Bundle(url: url) {
                                bundleId = bundle.bundleIdentifier
                            }
                            let displayName = name.replacingOccurrences(of: ".app", with: "")
                            let item = AppItem(name: displayName, lowercasedName: displayName.lowercased(), url: url, bundleIdentifier: bundleId)
                            found.append(item)
                        }
                    }
                }
            }
            let userApps = URL(fileURLWithPath: "\(NSHomeDirectory())/Applications", isDirectory: true)
            if fm.fileExists(atPath: userApps.path) {
                if let names = try? fm.contentsOfDirectory(atPath: userApps.path) {
                    for name in names where name.hasSuffix(".app") {
                        let url = userApps.appendingPathComponent(name)
                        let displayName = name.replacingOccurrences(of: ".app", with: "")
                        let item = AppItem(name: displayName, lowercasedName: displayName.lowercased(), url: url, bundleIdentifier: nil)
                        found.append(item)
                    }
                }
            }
            
            var unique: [String: AppItem] = [:]
            for a in found {
                unique[a.url.path] = a
            }
            let final = Array(unique.values).sorted { $0.name.lowercased() < $1.name.lowercased() }
            
            DispatchQueue.main.async {
                self.apps = final
                completion?()
            }
        }
    }
    
    func search(_ q: String, limit: Int = 50) -> [AppItem] {
        let qq = q.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !qq.isEmpty else { return Array(apps.prefix(limit)) }
        
        func fuzzyScore(name: String, q: String) -> Int {
            if name.hasPrefix(q) { return 100 }
            if name.contains(q) { return 50 }
            // simple subsequence check
            var i = name.startIndex
            var matched = 0
            for ch in q {
                if let idx = name[i...].firstIndex(of: ch) {
                    matched += 1
                    i = name.index(after: idx)
                } else {
                    break
                }
            }
            return matched == q.count ? 10 : 0
        }
        
        var scored: [(AppItem, Int)] = []
        for app in apps {
            let score = fuzzyScore(name: app.lowercasedName, q: qq)
            if score > 0 {
                scored.append((app, score))
            }
        }
        scored.sort {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.0.name < $1.0.name
        }
        return scored.prefix(limit).map { $0.0 }
    }
}
