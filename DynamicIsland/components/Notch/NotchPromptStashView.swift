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

import SwiftUI

struct NotchPromptStashView: View {
    @ObservedObject private var manager = PromptStashManager.shared
    @State private var isComposing = false
    @State private var draftTitle = ""
    @State private var draftContent = ""

    var body: some View {
        Group {
            if isComposing {
                PromptStashComposerView(
                    title: $draftTitle,
                    content: $draftContent,
                    onSave: saveDraft,
                    onCancel: dismissComposer
                )
            } else {
                PromptStashListView(
                    items: manager.items,
                    onAdd: presentComposer,
                    onCopy: copyItem,
                    onDelete: manager.delete,
                    onClearAll: manager.clearAll
                )
            }
        }
    }

    private func presentComposer() {
        draftTitle = ""
        draftContent = ""
        isComposing = true
    }

    private func dismissComposer() {
        draftTitle = ""
        draftContent = ""
        isComposing = false
    }

    private func saveDraft() {
        guard manager.add(title: draftTitle, content: draftContent) != nil else { return }
        dismissComposer()
    }

    private func copyItem(_ item: PromptStashItem) {
        manager.copyToPasteboard(item)
    }
}

private struct PromptStashListView: View {
    @EnvironmentObject var vm: DynamicIslandViewModel

    let items: [PromptStashItem]
    let onAdd: () -> Void
    let onCopy: (PromptStashItem) -> Void
    let onDelete: (PromptStashItem) -> Void
    let onClearAll: () -> Void

    @State private var hoveredItemId: UUID?
    @State private var justCopiedId: UUID?
    @State private var suppressionToken = UUID()
    @State private var isSuppressing = false
    @State private var showClearAlert = false
    @State private var autoCloseToken = UUID()

    var body: some View {
        VStack(spacing: 0) {
            header
            if items.isEmpty {
                emptyState
            } else {
                promptList
            }
        }
        .frame(maxHeight: .infinity)
        .onHover { hovering in
            updateSuppression(for: hovering)
        }
        .onDisappear {
            updateSuppression(for: false)
        }
        .alert("Delete All Prompts?", isPresented: $showClearAlert) {
            Button("Delete", role: .destructive, action: onClearAll)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every saved prompt from this Mac.")
        }
        .onChange(of: showClearAlert) { _, isShowing in
            vm.setAutoCloseSuppression(isShowing, token: autoCloseToken)
        }
    }

    private var header: some View {
        HStack {
            Text("Prompts")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            if !items.isEmpty {
                Button(action: { showClearAlert = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .padding(6)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.quote")
                .font(.system(size: 32))
                .foregroundStyle(.secondary.opacity(0.3))
            Text("No prompts yet")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 30)
    }

    private var promptList: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(items) { item in
                        PromptStashItemRow(
                            item: item,
                            isHovered: hoveredItemId == item.id,
                            justCopied: justCopiedId == item.id,
                            onDelete: { onDelete(item) }
                        )
                        .contentShape(Rectangle())
                        .onHover { isHovered in
                            hoveredItemId = isHovered ? item.id : nil
                        }
                        .onTapGesture {
                            copyItem(item)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }

            LinearGradient(colors: [Color.black.opacity(0.65), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 16)
                .allowsHitTesting(false)
                .frame(maxHeight: .infinity, alignment: .top)

            LinearGradient(colors: [.clear, Color.black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                .frame(height: 16)
                .allowsHitTesting(false)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func copyItem(_ item: PromptStashItem) {
        onCopy(item)
        withAnimation {
            justCopiedId = item.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if justCopiedId == item.id {
                withAnimation {
                    justCopiedId = nil
                }
            }
        }
    }

    private func updateSuppression(for hovering: Bool) {
        guard hovering != isSuppressing else { return }
        isSuppressing = hovering
        vm.setScrollGestureSuppression(hovering, token: suppressionToken)
    }
}

private struct PromptStashItemRow: View {
    let item: PromptStashItem
    let isHovered: Bool
    let justCopied: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: justCopied ? "checkmark.circle.fill" : "text.quote")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(justCopied ? .green : .blue)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(item.content)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .padding(6)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(isHovered ? 0.3 : 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PromptStashComposerView: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @Binding var title: String
    @Binding var content: String
    let onSave: () -> Void
    let onCancel: () -> Void

    @FocusState private var focusedField: Field?
    @State private var autoCloseToken = UUID()

    private enum Field {
        case title
        case content
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            composerHeader
            Divider()
                .background(Color.white.opacity(0.1))
            titleField
            Divider()
                .background(Color.white.opacity(0.1))
            bodyEditor
        }
        .onAppear {
            vm.setAutoCloseSuppression(true, token: autoCloseToken)
            focusedField = .title
        }
        .onDisappear {
            vm.setAutoCloseSuppression(false, token: autoCloseToken)
        }
    }

    private var composerHeader: some View {
        HStack {
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            Text("New Prompt")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Button(action: onSave) {
                Text("Save")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(canSave ? .white : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canSave)
        }
        .padding(16)
    }

    private var titleField: some View {
        TextField("Title", text: $title)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .textFieldStyle(.plain)
            .focused($focusedField, equals: .title)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }

    private var bodyEditor: some View {
        ZStack(alignment: .topLeading) {
            if content.isEmpty {
                Text("Prompt text")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .padding(.top, 10)
                    .padding(.leading, 12)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $content)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white)
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: .content)
                .padding(8)
        }
    }
}
