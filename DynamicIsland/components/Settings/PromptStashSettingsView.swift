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
import SwiftUI

struct PromptStashSettingsView: View {
    @ObservedObject private var manager = PromptStashManager.shared
    @State private var showClearAlert = false

    private func highlightID(_ title: String) -> String {
        "promptStash-\(title)"
    }

    private var savedCountLabel: String {
        let count = manager.items.count
        return count == 1 ? "1 saved prompt" : "\(count) saved prompts"
    }

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enablePromptStash) {
                    Text("Enable Prompt Stash")
                }
                .settingsHighlight(id: highlightID("Enable Prompt Stash"))

                HStack {
                    Text("Saved prompts")
                    Spacer()
                    Text(savedCountLabel)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("General")
            } footer: {
                Text("Saved prompts stay on this Mac after quit and restart.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Clear All") {
                    showClearAlert = true
                }
                .foregroundStyle(.red)
                .disabled(manager.items.isEmpty)
                .settingsHighlight(id: highlightID("Clear All"))
            }
        }
        .alert("Delete All Prompts?", isPresented: $showClearAlert) {
            Button("Delete", role: .destructive) {
                manager.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every saved prompt from this Mac.")
        }
    }
}
