//
//  SpotlightSercher.swift
//  Orbit
//
//  Created by Tom Tim on 08.11.2025.
//

import Foundation

final class SpotlightSearcher: NSObject {
    private var query: NSMetadataQuery?
    private var onResults: (([URL]) -> Void)?
    private var lastLimit: Int = 100
    
    func search(_ pattern: String, limit: Int = 100, completion: @escaping ([URL]) -> Void) {
        stop() // остановить предыдущий запрос, если есть
        lastLimit = limit
        onResults = { urls in
            DispatchQueue.main.async {
                completion(Array(urls.prefix(limit)))
            }
        }
        
        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryUserHomeScope]
        
        let safePattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safePattern.isEmpty else {
            completion([])
            return
        }
        q.predicate = NSPredicate(format: "%K CONTAINS[cd] %@", NSMetadataItemFSNameKey, safePattern)
        
        NotificationCenter.default.addObserver(self, selector: #selector(queryDidFinishGathering(_:)), name: .NSMetadataQueryDidFinishGathering, object: q)
        NotificationCenter.default.addObserver(self, selector: #selector(queryDidUpdate(_:)), name: .NSMetadataQueryDidUpdate, object: q)
        
        query = q
        q.start()
    }
    
    @objc private func queryDidFinishGathering(_ n: Notification) {
        processResults()
    }
    
    @objc private func queryDidUpdate(_ n: Notification) {
        processResults()
    }
    
    private func processResults() {
        guard let q = query else { return }
        q.disableUpdates()
        var results: [URL] = []
        for item in q.results {
            if results.count >= lastLimit { break }
            if let md = item as? NSMetadataItem,
               let path = md.value(forAttribute: NSMetadataItemPathKey) as? String {
                results.append(URL(fileURLWithPath: path))
            }
        }
        onResults?(results)
        q.enableUpdates()
    }
    
    func stop() {
        if let q = query {
            NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: q)
            NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: q)
            q.stop()
            query = nil
            onResults = nil
        }
    }
    
    deinit {
        stop()
    }
}

