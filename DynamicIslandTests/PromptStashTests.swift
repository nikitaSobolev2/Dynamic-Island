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

import Defaults
import XCTest
@testable import Atoll

final class PromptStashTests: XCTestCase {
    private var originalItems: [PromptStashItem] = []
    private var manager: PromptStashManager { PromptStashManager.shared }

    override func setUp() {
        super.setUp()
        originalItems = Defaults[.savedPromptStash]
        Defaults[.savedPromptStash] = []
        manager.reloadFromStore()
    }

    override func tearDown() {
        Defaults[.savedPromptStash] = originalItems
        manager.reloadFromStore()
        super.tearDown()
    }

    func testAddThenReloadKeepsItem() {
        let added = manager.add(title: "Deploy", content: "Write a production deploy checklist.")
        XCTAssertNotNil(added)
        XCTAssertEqual(manager.items.count, 1)

        manager.reloadFromStore()

        XCTAssertEqual(manager.items.count, 1)
        XCTAssertEqual(manager.items.first?.title, "Deploy")
        XCTAssertEqual(manager.items.first?.content, "Write a production deploy checklist.")
        XCTAssertEqual(Defaults[.savedPromptStash].count, 1)
    }

    func testDeleteRemovesItem() {
        guard let added = manager.add(title: "Review", content: "Review this pull request.") else {
            return XCTFail("Expected add to succeed")
        }

        manager.delete(added)
        manager.reloadFromStore()

        XCTAssertTrue(manager.items.isEmpty)
        XCTAssertTrue(Defaults[.savedPromptStash].isEmpty)
    }

    func testEmptyTitleIsRejected() {
        XCTAssertNil(manager.add(title: "   ", content: "Body text"))
        XCTAssertTrue(manager.items.isEmpty)
        XCTAssertTrue(Defaults[.savedPromptStash].isEmpty)
    }

    func testEmptyContentIsRejected() {
        XCTAssertNil(manager.add(title: "Title", content: "\n\t"))
        XCTAssertTrue(manager.items.isEmpty)
        XCTAssertTrue(Defaults[.savedPromptStash].isEmpty)
    }
}
