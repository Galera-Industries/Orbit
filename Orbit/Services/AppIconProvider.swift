//
//  AppIconProvider.swift
//  Orbit
//
//  Created by Tom Tim on 08.11.2025.
//

import Foundation
import AppKit

final class AppIconProvider {
    static let shared = AppIconProvider()
    
    private var cache: [String: NSImage] = [:]
    private let queue = DispatchQueue(label: "appiconprovider", qos: .userInitiated)
    private let lock = NSLock()
    
    private init() {}
    
    func cachedIcon(forPath path: String) -> NSImage? {
        lock.lock(); defer { lock.unlock() }
        return cache[path]
    }
    
    func loadIcon(forPath path: String, completion: @escaping (NSImage?) -> Void) {
        if let img = cachedIcon(forPath: path) {
            DispatchQueue.main.async { completion(img) }
            return
        }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            let icon = NSWorkspace.shared.icon(forFile: path)
            icon.size = NSSize(width: 32, height: 32)
            
            self.lock.lock()
            self.cache[path] = icon
            self.lock.unlock()
            
            DispatchQueue.main.async {
                completion(icon)
            }
        }
    }
    
    func clearCache() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }
}
