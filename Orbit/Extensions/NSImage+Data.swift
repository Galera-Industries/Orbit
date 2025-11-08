//
//  NSImage+Data.swift
//  Orbit
//
//  Created by Кирилл Исаев on 08.11.2025.
//

import AppKit

extension NSImage {
    func pngData() -> Data? {
        guard let tiff = self.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    func jpegData(compression: CGFloat = 0.9) -> Data? {
        guard let tiff = self.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: compression])
    }
}
