//
//  ScreenshotService.swift
//  Orbit
//
//  Created by Auto on 2025.
//

import Foundation
import AppKit
import ScreenCaptureKit

@available(macOS 12.3, *)
final class ScreenshotService {
    static let shared = ScreenshotService()
    
    private init() {}
    
    // MARK: - Main capture method using ScreenCaptureKit
    
    /// Захватывает область экрана (как Zoom делает screen share)
    func captureArea(_ rect: CGRect, completion: @escaping (NSImage?) -> Void) {
        // Скрываем Orbit
        DispatchQueue.main.async {
            NSApp.hide(nil)
        }
        
        // Даём время на скрытие
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.captureWithScreenCaptureKit(rect: rect, completion: completion)
        }
    }
    
    /// Синхронная версия (использует семафор - не идеально, но для совместимости)
    func captureArea(_ rect: CGRect) -> NSImage? {
        let semaphore = DispatchSemaphore(value: 0)
        var resultImage: NSImage?
        
        // Скрываем Orbit синхронно
        DispatchQueue.main.async {
            NSApp.hide(nil)
        }
        
        // Ждём
        Thread.sleep(forTimeInterval: 0.3)
        
        captureWithScreenCaptureKit(rect: rect) { image in
            resultImage = image
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 5.0)
        return resultImage
    }
    
    // MARK: - ScreenCaptureKit Implementation
    
    private func captureWithScreenCaptureKit(
        rect: CGRect,
        completion: @escaping (NSImage?) -> Void
    ) {
        _Concurrency.Task {
            do {
                // Получаем доступные экраны для захвата
                let availableContent = try await SCShareableContent.excludingDesktopWindows(
                    false,
                    onScreenWindowsOnly: true
                )
                
                // Находим главный дисплей
                guard let display = availableContent.displays.first(where: { $0.displayID == CGMainDisplayID() })
                      ?? availableContent.displays.first else {
                    print("⚠️ Не найден дисплей для захвата")
                    DispatchQueue.main.async {
                        completion(self.fallbackCapture(rect))
                    }
                    return
                }
                
                print("📺 Найден дисплей: \(display.width)x\(display.height)")
                
                // Исключаем окна Orbit из захвата
                let orbitBundleID = Bundle.main.bundleIdentifier ?? ""
                let excludedWindows = availableContent.windows.filter { window in
                    window.owningApplication?.bundleIdentifier == orbitBundleID
                }
                
                print("🚫 Исключаем \(excludedWindows.count) окон Orbit")
                
                // Создаём фильтр - захватываем дисплей, исключая окна Orbit
                let filter = SCContentFilter(
                    display: display,
                    excludingWindows: excludedWindows
                )
                
                // Настройки захвата
                let config = SCStreamConfiguration()
                config.width = display.width * 2  // Retina
                config.height = display.height * 2
                config.scalesToFit = false
                config.showsCursor = false
                config.captureResolution = .best
                
                // Делаем скриншот
                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )
                
                print("📸 ScreenCaptureKit: получено изображение \(image.width)x\(image.height)")
                
                // Вырезаем нужную область
                let croppedImage = self.cropImage(image, to: rect, displayHeight: CGFloat(display.height))
                
                DispatchQueue.main.async {
                    completion(croppedImage)
                }
                
            } catch {
                print("⚠️ ScreenCaptureKit ошибка: \(error)")
                print("💡 Возможно, нужно разрешение на запись экрана в System Preferences > Privacy > Screen Recording")
                
                DispatchQueue.main.async {
                    completion(self.fallbackCapture(rect))
                }
            }
        }
    }
    
    /// Вырезает область из полного скриншота
    private func cropImage(_ cgImage: CGImage, to rect: CGRect, displayHeight: CGFloat) -> NSImage? {
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        
        // Вычисляем масштаб (Retina)
        let scaleX = imageWidth / displayHeight * (displayHeight / imageHeight) * (imageWidth / displayHeight)
        let scaleY = imageHeight / displayHeight
        
        // Более простой расчёт масштаба
        let scale = imageHeight / displayHeight
        
        print("📐 Image: \(imageWidth)x\(imageHeight), Display height: \(displayHeight), Scale: \(scale)")
        print("📐 Requested rect (macOS coords): \(rect)")
        
        // macOS: origin внизу слева
        // CGImage: origin вверху слева
        let flippedY = displayHeight - rect.origin.y - rect.height
        
        let cropRect = CGRect(
            x: rect.origin.x * scale,
            y: flippedY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        
        print("📐 Crop rect (CG coords): \(cropRect)")
        
        // Проверяем границы
        let safeCropRect = CGRect(
            x: max(0, min(cropRect.origin.x, imageWidth - 1)),
            y: max(0, min(cropRect.origin.y, imageHeight - 1)),
            width: min(cropRect.width, imageWidth - cropRect.origin.x),
            height: min(cropRect.height, imageHeight - cropRect.origin.y)
        )
        
        guard let croppedCGImage = cgImage.cropping(to: safeCropRect) else {
            print("⚠️ Не удалось вырезать область, возвращаем полное изображение")
            return NSImage(cgImage: cgImage, size: NSSize(width: imageWidth, height: imageHeight))
        }
        
        print("✅ Вырезано: \(croppedCGImage.width)x\(croppedCGImage.height)")
        
        return NSImage(cgImage: croppedCGImage, size: rect.size)
    }
    
    // MARK: - Fallback method
    
    /// Fallback на старый метод если ScreenCaptureKit не работает
    private func fallbackCapture(_ rect: CGRect) -> NSImage? {
        print("🔄 Используем fallback метод (CGDisplayCreateImage)")
        
        guard let screen = NSScreen.main else { return nil }
        
        let displayID = CGMainDisplayID()
        guard let fullScreenImage = CGDisplayCreateImage(displayID) else {
            print("⚠️ CGDisplayCreateImage вернул nil")
            return nil
        }
        
        let screenFrame = screen.frame
        let scale = CGFloat(fullScreenImage.height) / screenFrame.height
        let flippedY = screenFrame.height - rect.origin.y - rect.height
        
        let cropRect = CGRect(
            x: rect.origin.x * scale,
            y: flippedY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        
        if let cropped = fullScreenImage.cropping(to: cropRect) {
            return NSImage(cgImage: cropped, size: rect.size)
        }
        
        return NSImage(cgImage: fullScreenImage, size: screenFrame.size)
    }
    
    // MARK: - Image Conversion
    
    func imageToPNGData(_ image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapImage.representation(using: .png, properties: [:])
    }
    
    func imageToJPEGData(_ image: NSImage, compressionQuality: CGFloat = 0.85) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
    
    func imageToBase64(_ image: NSImage) -> String? {
        var processedImage = image
        let maxDimension: CGFloat = 2048
        
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let width = CGFloat(cgImage.width)
            let height = CGFloat(cgImage.height)
            
            if width > maxDimension || height > maxDimension {
                let scale = min(maxDimension / width, maxDimension / height)
                let newSize = NSSize(width: width * scale, height: height * scale)
                
                let resizedImage = NSImage(size: newSize)
                resizedImage.lockFocus()
                image.draw(in: NSRect(origin: .zero, size: newSize),
                          from: NSRect(origin: .zero, size: image.size),
                          operation: .sourceOver,
                          fraction: 1.0)
                resizedImage.unlockFocus()
                processedImage = resizedImage
            }
        }
        
        _ = saveImageForDebugging(processedImage, suffix: "final")
        
        if let jpegData = imageToJPEGData(processedImage, compressionQuality: 0.7) {
            if jpegData.count > 300_000,
               let compressed = imageToJPEGData(processedImage, compressionQuality: 0.5) {
                return "data:image/jpeg;base64,\(compressed.base64EncodedString())"
            }
            return "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
        }
        
        guard let imageData = imageToPNGData(processedImage) else { return nil }
        return "data:image/png;base64,\(imageData.base64EncodedString())"
    }
    
    func saveImageForDebugging(_ image: NSImage, suffix: String = "") -> URL? {
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let screenshotsFolder = desktopURL.appendingPathComponent("OrbitScreenshots", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: screenshotsFolder, withIntermediateDirectories: true)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let timestamp = formatter.string(from: Date())
        let filename = "Screenshot_\(timestamp)\(suffix.isEmpty ? "" : "_\(suffix)").png"
        let fileURL = screenshotsFolder.appendingPathComponent(filename)
        
        guard let imageData = imageToPNGData(image) else { return nil }
        
        do {
            try imageData.write(to: fileURL)
            print("💾 Сохранено: \(fileURL.path)")
            return fileURL
        } catch {
            print("⚠️ Ошибка сохранения: \(error)")
            return nil
        }
    }
}

// MARK: - Fallback для старых версий macOS

final class ScreenshotServiceLegacy {
    static let shared = ScreenshotServiceLegacy()
    
    func captureArea(_ rect: CGRect) -> NSImage? {
        NSApp.hide(nil)
        Thread.sleep(forTimeInterval: 0.3)
        
        guard let screen = NSScreen.main else { return nil }
        let displayID = CGMainDisplayID()
        guard let fullScreenImage = CGDisplayCreateImage(displayID) else { return nil }
        
        let screenFrame = screen.frame
        let scale = CGFloat(fullScreenImage.height) / screenFrame.height
        let flippedY = screenFrame.height - rect.origin.y - rect.height
        
        let cropRect = CGRect(
            x: rect.origin.x * scale,
            y: flippedY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        
        if let cropped = fullScreenImage.cropping(to: cropRect) {
            return NSImage(cgImage: cropped, size: rect.size)
        }
        return nil
    }
}
