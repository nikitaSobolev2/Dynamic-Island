/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import AppKit
import Combine
import Defaults
import Foundation
import Observation
import UniformTypeIdentifiers

@Observable
@MainActor
final class ScreenshotCaptureManager {
    static let shared = ScreenshotCaptureManager()

    private(set) var originalRevealURL: URL?

    private let coordinator = DynamicIslandViewCoordinator.shared
    private let fileQueue = DispatchQueue(label: "com.atoll.screenshot.monitor", qos: .utility)
    private var directorySource: DispatchSourceFileSystemObject?
    private var watchedDirectoryPath: String?
    private var knownFileNames: Set<String> = []
    private var ingestedPaths: Set<String> = []
    private var hasCompletedInitialScan = false
    private var keyMonitor: Any?
    private var clipboardExpectationTask: Task<Void, Never>?
    private var lastFileIngestDate: Date?
    private var lastPasteboardChangeCount = NSPasteboard.general.changeCount
    private var cancellables = Set<AnyCancellable>()

    private init() {
        startMonitoringIfNeeded()
        Defaults.publisher(.enableScreenshotNotifications)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.startMonitoringIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    func revealInFinder() {
        guard let originalRevealURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([originalRevealURL])
    }

    private func startMonitoringIfNeeded() {
        if Defaults[.enableScreenshotNotifications] {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    private func startMonitoring() {
        startDirectoryMonitor()
        startClipboardMonitor()
    }

    private func stopMonitoring() {
        stopDirectoryMonitor()
        stopClipboardMonitor()
        originalRevealURL = nil
    }

    private func startDirectoryMonitor() {
        stopDirectoryMonitor()
        guard let directory = screenshotDirectory else { return }

        knownFileNames.removeAll()
        ingestedPaths.removeAll()
        hasCompletedInitialScan = false
        watchedDirectoryPath = directory.path

        let fileDescriptor = open(directory.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .attrib],
            queue: fileQueue
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.scanScreenshotDirectory()
            }
        }
        source.setCancelHandler {
            close(fileDescriptor)
        }
        directorySource = source
        source.resume()
        scanScreenshotDirectory()
    }

    private func stopDirectoryMonitor() {
        directorySource?.cancel()
        directorySource = nil
        watchedDirectoryPath = nil
        knownFileNames.removeAll()
        hasCompletedInitialScan = false
    }

    private func scanScreenshotDirectory() {
        guard let directory = screenshotDirectory else { return }

        if directory.path != watchedDirectoryPath {
            startDirectoryMonitor()
            return
        }

        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return
        }

        let names = Set(contents.map(\.lastPathComponent))
        if !hasCompletedInitialScan {
            hasCompletedInitialScan = true
            knownFileNames = names
            return
        }

        let newNames = names.subtracting(knownFileNames)
        knownFileNames = names
        for name in newNames {
            let url = directory.appendingPathComponent(name)
            Task { await ingestFileScreenshotIfNeeded(url) }
        }
    }

    private func ingestFileScreenshotIfNeeded(_ url: URL) async {
        guard !ScreenshotSnippingTool.shared.isSnipping else { return }
        guard await waitUntilFileIsStable(url) else { return }
        guard isScreenshotImage(url) else { return }

        let path = url.standardizedFileURL.path
        guard ingestedPaths.insert(path).inserted else { return }

        lastFileIngestDate = Date()
        await addCopyToShelf(from: url)
        presentNotification(revealURL: url)
    }

    private func addCopyToShelf(from originalURL: URL) async {
        guard let data = try? Data(contentsOf: originalURL) else { return }
        guard let tempURL = await TemporaryFileStorageService.shared.createTempFile(
            for: .data(data, suggestedName: originalURL.lastPathComponent)
        ) else { return }
        guard let bookmark = try? Bookmark(url: tempURL) else { return }
        ShelfStateViewModel.shared.add([
            ShelfItem(kind: .file(bookmark: bookmark.data), isTemporary: true)
        ])
    }

    private func presentNotification(revealURL: URL?) {
        originalRevealURL = revealURL
        coordinator.toggleExpandingView(status: true, type: .screenshot)
    }

    private func startClipboardMonitor() {
        guard keyMonitor == nil else { return }
        lastPasteboardChangeCount = NSPasteboard.general.changeCount
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard Self.isClipboardScreenshotShortcut(event) else { return }
            Task { @MainActor in
                self?.beginClipboardExpectation()
            }
        }
    }

    private func stopClipboardMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        clipboardExpectationTask?.cancel()
        clipboardExpectationTask = nil
    }

    private func beginClipboardExpectation() {
        clipboardExpectationTask?.cancel()
        lastPasteboardChangeCount = NSPasteboard.general.changeCount
        clipboardExpectationTask = Task { [weak self] in
            let deadline = Date().addingTimeInterval(2)
            while Date() < deadline {
                guard !Task.isCancelled else { return }
                if self?.consumeClipboardScreenshotIfNeeded() == true {
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func consumeClipboardScreenshotIfNeeded() -> Bool {
        guard Defaults[.enableScreenshotNotifications] else { return false }
        guard !ScreenshotSnippingTool.shared.isSnipping else { return false }
        if let lastFileIngestDate, Date().timeIntervalSince(lastFileIngestDate) < 2 {
            return false
        }

        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastPasteboardChangeCount else { return false }
        lastPasteboardChangeCount = pasteboard.changeCount
        guard pasteboardContainsImageWithoutFileURL(pasteboard) else { return false }

        presentNotification(revealURL: nil)
        return true
    }

    private var screenshotDirectory: URL? {
        let defaults = UserDefaults(suiteName: "com.apple.screencapture")
        if let location = defaults?.string(forKey: "location"), !location.isEmpty {
            return URL(fileURLWithPath: (location as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    }
}

private extension ScreenshotCaptureManager {
    static let screenshotDigitKeyCodes: Set<UInt16> = [20, 21]

    static func isClipboardScreenshotShortcut(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .shift, .control, .option])
        return modifiers == [.command, .shift, .control]
            && screenshotDigitKeyCodes.contains(event.keyCode)
    }

    func waitUntilFileIsStable(_ url: URL) async -> Bool {
        var previousSize: Int?
        for _ in 0..<10 {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if size > 0, size == previousSize { return true }
            previousSize = size
            try? await Task.sleep(for: .milliseconds(150))
        }
        return (previousSize ?? 0) > 0
    }

    func isScreenshotImage(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.contentTypeKey, .isRegularFileKey])
        guard values?.isRegularFile == true else { return false }
        guard let contentType = values?.contentType, contentType.conforms(to: .image) else { return false }
        if let isScreenCapture = NSMetadataItem(url: url)?
            .value(forAttribute: "kMDItemIsScreenCapture") as? Bool {
            return isScreenCapture
        }
        return true
    }

    func pasteboardContainsImageWithoutFileURL(_ pasteboard: NSPasteboard) -> Bool {
        let types = Set(pasteboard.types ?? [])
        if types.contains(.fileURL) { return false }
        return types.contains(.png)
            || types.contains(.tiff)
            || pasteboard.canReadItem(withDataConformingToTypes: [UTType.image.identifier])
    }
}
