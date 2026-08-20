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

private let voiceChatMicrophoneOrange = Color(red: 1.000, green: 0.584, blue: 0.010)

struct VoiceChatControlRow: View {
    @ObservedObject var manager = VoiceChatManager.shared
    var iconSize: CGFloat = 28
    var spacing: CGFloat = 8

    var body: some View {
        HStack(spacing: spacing) {
            VoiceChatIconButton(
                systemName: manager.isMicrophoneMuted ? "mic.slash.fill" : "mic.fill",
                color: manager.isMicrophoneMuted ? .secondary : voiceChatMicrophoneOrange,
                isEnabled: manager.isMicrophoneMuteAvailable,
                frameSize: iconSize
            ) {
                manager.toggleMicrophoneMute()
            }

            VoiceChatIconButton(
                systemName: manager.isOutputMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                color: manager.isOutputMuted ? .secondary : .white,
                isEnabled: true,
                frameSize: iconSize
            ) {
                manager.toggleOutputMute()
            }
        }
    }
}

struct VoiceChatHeaderControls: View {
    @ObservedObject var manager = VoiceChatManager.shared

    var body: some View {
        HStack(spacing: 2) {
            VoiceChatGlyph(
                systemName: manager.isMicrophoneMuted ? "mic.slash.fill" : "mic.fill",
                color: manager.isMicrophoneMuted ? Color.white.opacity(0.55) : voiceChatMicrophoneOrange,
                isEnabled: manager.isMicrophoneMuteAvailable
            ) {
                manager.toggleMicrophoneMute()
            }

            VoiceChatGlyph(
                systemName: manager.isOutputMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                color: manager.isOutputMuted ? Color.white.opacity(0.55) : .white,
                isEnabled: true
            ) {
                manager.toggleOutputMute()
            }
        }
        .onAppear {
            manager.refreshSession()
        }
    }
}

struct VoiceChatGlyph: View {
    let systemName: String
    let color: Color
    let isEnabled: Bool
    var frameSize: CGFloat = 24
    let action: () -> Void

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(color)
            .opacity(isEnabled ? 1 : 0.35)
            .frame(width: frameSize, height: frameSize)
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture().onEnded {
                    guard isEnabled else { return }
                    action()
                }
            )
    }
}

struct VoiceChatIconButton: View {
    let systemName: String
    let color: Color
    let isEnabled: Bool
    var frameSize: CGFloat = 28
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: frameSize * 0.48, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: frameSize, height: frameSize)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovering ? Color.white.opacity(0.18) : .clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.18)) {
                isHovering = hovering
            }
        }
    }
}
