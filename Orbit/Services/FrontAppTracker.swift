//
//  FrontAppTracker.swift
//  Orbit
//
//  Created by Кирилл Исаев on 08.11.2025.
//
import Combine
import AppKit

final class FrontAppTracker {
    private var bag = Set<AnyCancellable>()
    private(set) var previousApp: NSRunningApplication?

    init() {
        previousApp = NSWorkspace.shared.frontmostApplication
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .sink { [weak self] app in
                if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                    self?.previousApp = app
                }
            }
            .store(in: &bag)
    }

    func rememberNow() {
        if let app = NSWorkspace.shared.frontmostApplication,
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = app
        }
    }
}
