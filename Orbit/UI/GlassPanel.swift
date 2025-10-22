//
//  GlassPanel.swift
//  Orbit
//
//  Created by Tom Tim on 20.10.2025.
//

import SwiftUI

struct GlassPanel<Content: View>: View {
    var corner: CGFloat = 16
    var content: () -> Content
    
    // фиксированный градиент (позже сделаем настраиваемым)
    private let gradient = LinearGradient(
        colors: [
            Color(nsColor: NSColor.systemPink).opacity(0.18),
            Color(nsColor: NSColor.systemPurple).opacity(0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            // Блюр
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow, state: .active)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            
            // Мягкий градиент поверх блюра
            gradient
                .blendMode(.plusLighter)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            
            // Контент
            content()
                .clipShape(RoundedRectangle(cornerRadius: corner - 0.5, style: .continuous))
        }
        // 1px «волосок» и лёгкая тень для объёма
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 12)
    }
}
