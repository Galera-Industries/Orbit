//
//  ZoomMonitorService.swift
//  Orbit
//

import Foundation
import AppKit
internal import os

struct ZoomDetectedFile {
    let url: URL
    let meetingFolder: String
    let detectedAt: Date
}

protocol ZoomMonitorDelegate: AnyObject {
    func zoomMonitor(_ monitor: ZoomMonitorService, didDetectFile file: ZoomDetectedFile)
}

final class ZoomMonitorService {
    static let shared = ZoomMonitorService()

    weak var delegate: ZoomMonitorDelegate?

    private var streamRef: FSEventStreamRef?
    private var knownFiles: Set<URL> = []
    private let queue = DispatchQueue(label: "com.orbit.zoom-monitor", qos: .utility)

    private(set) var isRunning = false

    var watchFolder: URL {
        if let path = UserDefaults.standard.string(forKey: "fileResearchFolder"), !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Zoom")
    }

    private init() {}

    // MARK: - Public

    var isZoomRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "us.zoom.xos"
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        knownFiles.removeAll()
        snapshotKnownFiles()
        startFSEvents()
        L.zoom.info("ZoomMonitorService started, watching: \(self.watchFolder.path)")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        if let stream = streamRef {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            streamRef = nil
        }
        L.zoom.info("ZoomMonitorService stopped")
    }

    func restart() {
        stop()
        start()
    }

    // MARK: - Private

    private func snapshotKnownFiles() {
        guard let enumerator = FileManager.default.enumerator(
            at: watchFolder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for case let url as URL in enumerator {
            if (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
                knownFiles.insert(url)
            }
        }
    }

    private func startFSEvents() {
        guard FileManager.default.fileExists(atPath: watchFolder.path) else {
            L.zoom.info("Watch folder not found: \(self.watchFolder.path)")
            return
        }

        let folder = watchFolder
        let paths = [folder.path] as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        streamRef = FSEventStreamCreate(
            nil,
            { _, clientCallBackInfo, numEvents, eventPaths, _, _ in
                guard let info = clientCallBackInfo else { return }
                let service = Unmanaged<ZoomMonitorService>.fromOpaque(info).takeUnretainedValue()
                guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
                service.handleFSEvents(paths: paths)
            },
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream = streamRef {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
        }
    }

    private func handleFSEvents(paths: [String]) {
        let supportedExtensions: Set<String> = ["pdf", "png", "jpg", "jpeg", "gif", "txt", "docx", "doc", "xlsx", "csv", "pptx"]
        let folder = watchFolder

        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard !knownFiles.contains(url) else { continue }

            let relativeComponents = Array(url.pathComponents.dropFirst(folder.pathComponents.count))
            guard relativeComponents.count >= 1 else { continue }

            let ext = url.pathExtension.lowercased()
            guard supportedExtensions.contains(ext) else { continue }
            guard url.lastPathComponent != "meeting_saved_chat.txt" else { continue }
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }

            knownFiles.insert(url)
            let meetingFolder = relativeComponents.count >= 2 ? relativeComponents[0] : "Files"
            let detected = ZoomDetectedFile(url: url, meetingFolder: meetingFolder, detectedAt: Date())
            L.zoom.info("New file detected: \(url.lastPathComponent) in '\(meetingFolder)'")

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.zoomMonitor(self, didDetectFile: detected)
            }
        }
    }

    func processExistingFile(at url: URL) {
        let folder = watchFolder
        let relativeComponents = Array(url.pathComponents.dropFirst(folder.pathComponents.count))
        guard relativeComponents.count >= 1 else { return }
        guard !knownFiles.contains(url) else { return }
        knownFiles.insert(url)
        let meetingFolder = relativeComponents.count >= 2 ? relativeComponents[0] : "Files"
        let detected = ZoomDetectedFile(url: url, meetingFolder: meetingFolder, detectedAt: Date())
        delegate?.zoomMonitor(self, didDetectFile: detected)
    }
}
