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

final class PromptStashManager: ObservableObject {
    static let shared = PromptStashManager()

    @Published private(set) var items: [PromptStashItem] = []

    private init() {
        reloadFromStore()
    }

    func reloadFromStore() {
        items = Defaults[.savedPromptStash]
    }

    @discardableResult
    func add(title: String, content: String) -> PromptStashItem? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedContent.isEmpty else { return nil }

        let item = PromptStashItem(
            id: UUID(),
            title: trimmedTitle,
            content: trimmedContent,
            createdAt: Date()
        )
        items.insert(item, at: 0)
        persist()
        return item
    }

    func delete(_ item: PromptStashItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clearAll() {
        items = []
        persist()
    }

    func copyToPasteboard(_ item: PromptStashItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
    }

    private func persist() {
        Defaults[.savedPromptStash] = items
    }
}
