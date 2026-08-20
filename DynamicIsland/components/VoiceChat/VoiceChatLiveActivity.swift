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

struct VoiceChatLiveActivity: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject private var manager = VoiceChatManager.shared
    @ObservedObject private var privacyManager = PrivacyIndicatorManager.shared
    @ObservedObject private var recordingManager = ScreenRecordingManager.shared
    @State private var isExpanded = false

    private let microphoneOrange = Color(red: 1.000, green: 0.584, blue: 0.010)

    private var showsCamera: Bool {
        privacyManager.cameraActive && Defaults[.enableCameraDetection]
    }

    private var showsRecording: Bool {
        recordingManager.isRecording && Defaults[.enableScreenRecordingDetection]
    }

    private var wingWidth: CGFloat {
        max(0, vm.effectiveClosedNotchHeight - 12 + 20)
    }

    private var wingHeight: CGFloat {
        max(0, vm.effectiveClosedNotchHeight - 12)
    }

    var body: some View {
        HStack(spacing: 0) {
            leftWing
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width)
            rightWing
        }
        .frame(height: vm.effectiveClosedNotchHeight)
        .onAppear {
            withAnimation(.smooth(duration: 0.4)) {
                isExpanded = true
            }
        }
    }

    private var leftWing: some View {
        Color.clear
            .background {
                if isExpanded {
                    leftWingContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
            .frame(width: isExpanded ? wingWidth : 0, height: wingHeight)
    }

    private var rightWing: some View {
        Color.clear
            .background {
                if isExpanded {
                    microphoneIcon
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                }
            }
            .frame(width: isExpanded ? wingWidth : 0, height: wingHeight)
    }

    @ViewBuilder
    private var leftWingContent: some View {
        if showsRecording {
            recordingPulse
        } else if showsCamera {
            PrivacyIcon(type: .camera)
        } else {
            speakerIcon
        }
    }

    private var microphoneIcon: some View {
        VoiceChatGlyph(
            systemName: manager.isMicrophoneMuted ? "mic.slash.fill" : "mic.fill",
            color: manager.isMicrophoneMuted ? .secondary : microphoneOrange,
            isEnabled: manager.isMicrophoneMuteAvailable
        ) {
            manager.toggleMicrophoneMute()
        }
    }

    private var speakerIcon: some View {
        VoiceChatGlyph(
            systemName: manager.isOutputMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
            color: manager.isOutputMuted ? .secondary : .white,
            isEnabled: true
        ) {
            manager.toggleOutputMute()
        }
    }

    private var recordingPulse: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.red.opacity(0.15))
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .modifier(PulsingModifier())
        }
        .frame(width: wingHeight, height: wingHeight)
    }
}
