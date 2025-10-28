//
//  OrbitApp.swift
//  Orbit
//
//  Created by Tom Tim on 20.10.2025.
//

import SwiftUI
import AppKit

@main
struct OrbitApp: App {
  @StateObject private var shell = ShellModel()
  @StateObject private var windowManager = WindowManager()

  // Держим сильную ссылку на статус-иконку, чтобы её не выгрузило
  private static var statusBarController: StatusBarController?

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(shell)
        .environmentObject(windowManager)
        .background(WindowAccessor { window in
          // Конфигурация «как Raycast»
          window.titleVisibility = .hidden
          window.titlebarAppearsTransparent = true
          window.isOpaque = false
          window.backgroundColor = .clear
          window.isMovableByWindowBackground = true
          window.level = .floating
          window.styleMask.remove([.resizable, .miniaturizable, .closable])
          window.standardWindowButton(.closeButton)?.isHidden = true
          window.standardWindowButton(.miniaturizeButton)?.isHidden = true
          window.standardWindowButton(.zoomButton)?.isHidden = true
          window.collectionBehavior = [.transient, .moveToActiveSpace, .ignoresCycle]

          windowManager.window = window
          windowManager.enableAutoHideOnBlur()
        })
        .onAppear {
          // Глобальные хоткеи (обновлённая сигнатура с shell)
          HotkeyBootstrap.registerDefaults(windowManager: windowManager, shell: shell)

          // AX-права (для эмуляции клавиш при необходимости)
          _ = AccessibilityService.shared.ensureAuthorized(prompt: false)

          // На dev-сборках подстрахуем скрытие из Dock (на проде ставь LSUIElement=YES)
          DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }

          // Создаём статус-иконку один раз и держим сильную ссылку
          if Self.statusBarController == nil {
            Self.statusBarController = StatusBarController(windowManager: windowManager)
          }
        }
    }
    .windowStyle(.hiddenTitleBar)
  }
}
