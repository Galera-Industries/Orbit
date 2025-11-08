//
//  QueryParser.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation

final class QueryParser {
    private let tagRegex: NSRegularExpression
    private let prioRegex: NSRegularExpression
    private let dueRegex: NSRegularExpression

    init?() {
        guard let tag = try? NSRegularExpression(pattern: #"(?:(?<=\s)|^)#([A-Za-z0-9_\-]+)"#),
              let prio = try? NSRegularExpression(pattern: #"(?:(?<=\s)|^)!([A-Za-z0-9]+)"#),
              let due = try? NSRegularExpression(pattern: #"(?:(?<=\s)|^)@([A-Za-z0-9\-]+)"#) else {
            return nil
        }
        
        self.tagRegex = tag
        self.prioRegex = prio
        self.dueRegex = due
    }
    
    private let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    func parse(_ input: String, mode: AppMode) -> ParsedQuery {
        var tags: [String] = []
        var priority: TaskPriority? = nil
        var due: DueToken? = nil
        
        func extract(_ regex: NSRegularExpression, from text: String, handler: ([String]) -> Void) -> String {
            let ns = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            var toRemove: [NSRange] = []
            var captures: [String] = []
            
            for m in matches {
                if m.numberOfRanges > 1 {
                    let cap = ns.substring(with: m.range(at: 1))
                    captures.append(cap)
                    toRemove.append(m.range)
                }
            }
            
            handler(captures)
            
            // Удаляем найденные токены
            var mutable = text
            for r in toRemove.reversed() {
                let from = mutable.index(mutable.startIndex, offsetBy: r.location)
                let to = mutable.index(from, offsetBy: r.length)
                mutable.removeSubrange(from..<to)
            }
            return mutable.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
        }
        
        var text = input
        
        // #tags
        text = extract(tagRegex, from: text) { caps in
            tags.append(contentsOf: caps)
        }
        
        // !priority
        text = extract(prioRegex, from: text) { caps in
            for c in caps {
                switch c.lowercased() {
                case "low", "l", "0": priority = .low
                case "med", "m", "1": priority = .medium
                case "high", "h", "2", "3": priority = .high
                default: break
                }
            }
        }
        
        // @due
        text = extract(dueRegex, from: text) { caps in
            for c in caps {
                switch c.lowercased() {
                case "today": due = .today
                case "tomorrow", "tmrw", "tmr": due = .tomorrow
                case "nextweek", "nw": due = .nextWeek
                default:
                    if let date = isoFormatter.date(from: c) {
                        due = .date(date)
                    }
                }
            }
        }
        
        return ParsedQuery(raw: input, mode: mode, text: text, tags: tags, priority: priority, due: due)
    }
}
