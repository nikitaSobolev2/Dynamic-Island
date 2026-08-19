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
import SwiftUI
import Combine
import Foundation
import UniformTypeIdentifiers
import Defaults

// Clipboard item data structure
struct ClipboardItem: Identifiable, Codable {
    let id = UUID()
    let type: ClipboardItemType
    let timestamp: Date
    let preview: String
    var isPinned: Bool = false
    
    // Store different types of data - avoid large binary data in UserDefaults
    let stringData: String?
    let imageFileName: String? // Store filename instead of data
    let fileURLs: [String]?
    let rtfData: Data? // RTF is typically small, so we can keep this
    
    init(stringData: String, type: ClipboardItemType) {
        self.stringData = stringData
        self.imageFileName = nil
        self.fileURLs = nil
        self.rtfData = nil
        self.type = type
        self.timestamp = Date()
        self.preview = ClipboardItem.generatePreview(stringData: stringData, type: type)
    }
    
    init(imageData: Data) {
        self.stringData = nil
        self.fileURLs = nil
        self.rtfData = nil
        self.type = .image
        self.timestamp = Date()

        let storedData = Self.pngData(from: imageData) ?? imageData
        let fileName = "clipboard_image_\(UUID().uuidString).png"
        let fileURL = ClipboardManager.clipboardDataDirectory.appendingPathComponent(fileName)

        do {
            try storedData.write(to: fileURL)
            self.imageFileName = fileName
            self.preview = Self.imagePreviewText(from: storedData)
        } catch {
            self.imageFileName = nil
            self.preview = "Image (failed to save)"
        }
    }
    
    init(fileURLs: [String]) {
        self.stringData = nil
        self.imageFileName = nil
        self.fileURLs = fileURLs
        self.rtfData = nil
        self.type = .file
        self.timestamp = Date()
        
        if fileURLs.count == 1, let url = URL(string: fileURLs.first!) {
            self.preview = url.lastPathComponent
        } else {
            self.preview = "\(fileURLs.count) files"
        }
    }
    
    init(rtfData: Data, plainText: String) {
        // RTF data is typically small, so we can keep it in UserDefaults
        self.stringData = plainText
        self.imageFileName = nil
        self.fileURLs = nil
        self.rtfData = rtfData.count > 100000 ? nil : rtfData // Skip very large RTF files
        self.type = .rtf
        self.timestamp = Date()
        self.preview = String(plainText.prefix(50))
    }
    
    func getImageData() -> Data? {
        guard let fileName = imageFileName else { return nil }
        let fileURL = ClipboardManager.clipboardDataDirectory.appendingPathComponent(fileName)
        return try? Data(contentsOf: fileURL)
    }

    func previewImage() -> NSImage? {
        guard type == .image, let data = getImageData() else { return nil }
        return NSImage(data: data)
    }

    func discardStoredImage() {
        guard let fileName = imageFileName else { return }
        let fileURL = ClipboardManager.clipboardDataDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func pngData(from data: Data) -> Data? {
        guard let image = NSImage(data: data),
              image.size.width > 0,
              image.size.height > 0,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func imagePreviewText(from data: Data) -> String {
        let sizeText = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        guard let image = NSImage(data: data),
              let representation = image.representations.first else {
            return "Image (\(sizeText))"
        }
        return "Image \(representation.pixelsWide)×\(representation.pixelsHigh) (\(sizeText))"
    }
    
    // Helper to check if this item has the same content as another
    func isSameContent(as other: ClipboardItem) -> Bool {
        return stringData == other.stringData &&
               imageFileName == other.imageFileName &&
               fileURLs == other.fileURLs &&
               type == other.type
    }
    
    static func generatePreview(stringData: String, type: ClipboardItemType) -> String {
        switch type {
        case .text:
            return String(stringData.prefix(50))
        case .url:
            if let url = URL(string: stringData) {
                return url.lastPathComponent.isEmpty ? url.host ?? stringData : url.lastPathComponent
            }
            return String(stringData.prefix(50))
        case .file:
            if let url = URL(string: stringData) {
                return url.lastPathComponent
            }
            return "File"
        case .image:
            return "Image"
        case .rtf:
            return String(stringData.prefix(50))
        case .unknown:
            return String(stringData.prefix(50))
        }
    }
}

enum ClipboardItemType: String, CaseIterable, Codable {
    case text = "text"
    case url = "url"
    case file = "file"
    case image = "image"
    case rtf = "rtf"
    case unknown = "unknown"
    
    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .url: return "link"
        case .file: return "doc"
        case .image: return "photo"
        case .rtf: return "doc.richtext"
        case .unknown: return "questionmark.circle"
        }
    }
    
    var displayName: String {
        switch self {
        case .text: return String(localized: "Text")
        case .url: return String(localized: "URL")
        case .file: return String(localized: "File")
        case .image: return String(localized: "Image")
        case .rtf: return String(localized: "Rich Text")
        case .unknown: return String(localized: "Unknown")
        }
    }
}

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var clipboardHistory: [ClipboardItem] = []
    @Published var pinnedItems: [ClipboardItem] = []
    @Published var isMonitoring: Bool = false
    @Published private(set) var lastCopiedItemDate: Date?
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    
    // Use configurable history size from settings
    private var maxHistoryItems: Int {
        return Defaults[.clipboardHistorySize]
    }
    
    // Computed properties for filtered lists
    var regularHistory: [ClipboardItem] {
        clipboardHistory.filter { !$0.isPinned }
    }
    
    var pinnedHistory: [ClipboardItem] {
        pinnedItems
    }
    
    // Directory for storing clipboard data files
    static let clipboardDataDirectory: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let clipboardDir = documentsPath.appendingPathComponent("ClipboardData")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: clipboardDir, withIntermediateDirectories: true)
        
        return clipboardDir
    }()
    
    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
        loadHistoryFromDefaults()
        cleanupOldFiles()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text, .url:
            if let stringData = item.stringData {
                pasteboard.setString(stringData, forType: .string)
            }
        case .image:
            guard let imageData = item.getImageData() else { break }
            if let image = NSImage(data: imageData) {
                pasteboard.writeObjects([image])
            }
            pasteboard.setData(ClipboardItem.pngData(from: imageData) ?? imageData, forType: .png)
        case .file:
            if let fileURLs = item.fileURLs {
                let urls = fileURLs.compactMap { URL(string: $0) }
                pasteboard.writeObjects(urls as [NSPasteboardWriting])
            }
        case .rtf:
            if let rtfData = item.rtfData {
                pasteboard.setData(rtfData, forType: .rtf)
            }
            // Also set plain text as fallback
            if let stringData = item.stringData {
                pasteboard.setString(stringData, forType: .string)
            }
        case .unknown:
            if let stringData = item.stringData {
                pasteboard.setString(stringData, forType: .string)
            }
        }

        lastChangeCount = pasteboard.changeCount
    }
    
    func deleteItem(_ item: ClipboardItem) {
        item.discardStoredImage()
        clipboardHistory.removeAll { $0.id == item.id }
        saveHistoryToDefaults()
    }
    
    func clearHistory() {
        clipboardHistory.forEach { $0.discardStoredImage() }
        clipboardHistory.removeAll()
        saveHistoryToDefaults()
    }
    
    func pinItem(_ item: ClipboardItem) {
        // Update the item to be pinned
        var pinnedItem = item
        pinnedItem.isPinned = true
        
        // Remove from regular history if it exists there
        clipboardHistory.removeAll { $0.id == item.id }
        
        // Add to pinned items if not already there
        if !pinnedItems.contains(where: { $0.id == item.id }) {
            pinnedItems.append(pinnedItem)
        }
        
        saveHistoryToDefaults()
        savePinnedItemsToDefaults()
    }
    
    func unpinItem(_ item: ClipboardItem) {
        // Remove from pinned items
        pinnedItems.removeAll { $0.id == item.id }
        
        // Update the item to be unpinned and add back to regular history
        var unpinnedItem = item
        unpinnedItem.isPinned = false
        
        // Add back to regular history at the top
        clipboardHistory.insert(unpinnedItem, at: 0)
        
        // Maintain history size limit
        if clipboardHistory.count > maxHistoryItems {
            let itemsToDelete = Array(clipboardHistory.dropFirst(maxHistoryItems))
            for oldItem in itemsToDelete {
                oldItem.discardStoredImage()
            }
            clipboardHistory = Array(clipboardHistory.prefix(maxHistoryItems))
        }
        
        saveHistoryToDefaults()
        savePinnedItemsToDefaults()
    }
    
    func togglePin(for item: ClipboardItem) {
        if item.isPinned || pinnedItems.contains(where: { $0.id == item.id }) {
            unpinItem(item)
        } else {
            pinItem(item)
        }
    }
    
    // MARK: - Private Methods
    
    private func checkClipboard() {
        let currentChangeCount = NSPasteboard.general.changeCount
        
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount
        
        guard let clipboardItem = getCurrentClipboardItem() else { return }

        let alreadyStored = clipboardHistory.contains { isSameContent($0, clipboardItem) }
            || pinnedItems.contains { isSameContent($0, clipboardItem) }
        if alreadyStored {
            clipboardItem.discardStoredImage()
            return
        }

        addToHistory(clipboardItem)
    }

    private func getCurrentClipboardItem() -> ClipboardItem? {
        let pasteboard = NSPasteboard.general
        let fileURLs = readableFileURLs(from: pasteboard)

        if let imageItem = clipboardImageItem(from: fileURLs) {
            return imageItem
        }

        if !fileURLs.isEmpty {
            return ClipboardItem(fileURLs: fileURLs.map(\.absoluteString))
        }

        // Prefer bitmap over accompanying URL/HTML (browser / screenshot copies).
        if let imageData = imageData(from: pasteboard) {
            return ClipboardItem(imageData: imageData)
        }

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            if string.hasPrefix("http://") || string.hasPrefix("https://") {
                return ClipboardItem(stringData: string, type: .url)
            }
            return ClipboardItem(stringData: string, type: .text)
        }

        if let rtfData = pasteboard.data(forType: .rtf),
           let rtfString = NSAttributedString(rtf: rtfData, documentAttributes: nil)?.string,
           !rtfString.isEmpty {
            return ClipboardItem(rtfData: rtfData, plainText: rtfString)
        }

        if let url = pasteboard.string(forType: .URL) {
            return ClipboardItem(stringData: url, type: .url)
        }

        return nil
    }

    private func readableFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
            return []
        }
        return urls.filter { url in
            url.isFileURL && FileManager.default.fileExists(atPath: url.path)
        }
    }

    private func clipboardImageItem(from fileURLs: [URL]) -> ClipboardItem? {
        let imageURL = fileURLs.first(where: isImageFile)
        guard let imageURL, let imageData = try? Data(contentsOf: imageURL) else {
            return nil
        }
        return ClipboardItem(imageData: imageData)
    }

    private func isImageFile(_ url: URL) -> Bool {
        if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return contentType.conforms(to: .image)
        }
        return UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
    }

    private func imageData(from pasteboard: NSPasteboard) -> Data? {
        let preferredTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.heic"),
            NSPasteboard.PasteboardType("public.heif"),
            NSPasteboard.PasteboardType("com.compuserve.gif"),
            NSPasteboard.PasteboardType("org.webmproject.webp"),
            NSPasteboard.PasteboardType("public.webp")
        ]

        for type in preferredTypes {
            if let data = pasteboard.data(forType: type), NSImage(data: data) != nil {
                return data
            }
        }

        guard let image = NSImage(pasteboard: pasteboard),
              image.size.width > 0,
              image.size.height > 0,
              let tiff = image.tiffRepresentation else {
            return nil
        }
        return tiff
    }
    
    private func addToHistory(_ item: ClipboardItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Remove any existing items with the same data
            let itemsToRemove = self.clipboardHistory.filter { existingItem in
                return self.isSameContent(existingItem, item)
            }
            
            // Clean up files for items being removed
            for oldItem in itemsToRemove {
                oldItem.discardStoredImage()
            }
            
            self.clipboardHistory.removeAll { existingItem in
                return self.isSameContent(existingItem, item)
            }
            
            // Add to beginning of array
            self.clipboardHistory.insert(item, at: 0)
            self.lastCopiedItemDate = item.timestamp
            
            // Keep only the most recent items and clean up old files
            let itemsToDelete = Array(self.clipboardHistory.dropFirst(self.maxHistoryItems))
            for oldItem in itemsToDelete {
                oldItem.discardStoredImage()
            }
            
            if self.clipboardHistory.count > self.maxHistoryItems {
                self.clipboardHistory = Array(self.clipboardHistory.prefix(self.maxHistoryItems))
            }
            
            self.saveHistoryToDefaults()
        }
    }
    
    // Helper to compare clipboard items for duplicates
    private func isSameContent(_ item1: ClipboardItem, _ item2: ClipboardItem) -> Bool {
        if item1.type != item2.type { return false }
        
        switch item1.type {
        case .text, .url, .unknown:
            return item1.stringData == item2.stringData
        case .image:
            // For images, compare the actual data if both are available
            let data1 = item1.getImageData()
            let data2 = item2.getImageData()
            return data1 == data2
        case .file:
            return item1.fileURLs == item2.fileURLs
        case .rtf:
            return item1.stringData == item2.stringData && item1.rtfData == item2.rtfData
        }
    }
    
    // Clean up old image files that are no longer referenced
    private func cleanupOldFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: ClipboardManager.clipboardDataDirectory, includingPropertiesForKeys: nil) else { return }
        
        let referencedFiles = Set(
            clipboardHistory.compactMap(\.imageFileName) + pinnedItems.compactMap(\.imageFileName)
        )
        
        for file in files {
            let fileName = file.lastPathComponent
            if !referencedFiles.contains(fileName) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveHistoryToDefaults() {
        if let encoded = try? JSONEncoder().encode(clipboardHistory) {
            UserDefaults.standard.set(encoded, forKey: "ClipboardHistory")
        }
    }
    
    func savePinnedItemsToDefaults() {
        if let encoded = try? JSONEncoder().encode(pinnedItems) {
            UserDefaults.standard.set(encoded, forKey: "ClipboardPinnedItems")
        }
    }
    
    private func loadHistoryFromDefaults() {
        if let data = UserDefaults.standard.data(forKey: "ClipboardHistory"),
           let history = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            clipboardHistory = history
        }
        
        if let data = UserDefaults.standard.data(forKey: "ClipboardPinnedItems"),
           let pinned = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            pinnedItems = pinned
        }
    }
}
