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

import Combine
import Defaults
import Foundation

@MainActor
final class VoiceChatManager: ObservableObject {
    static let shared = VoiceChatManager()
    static let compactControlRowHeight: CGFloat = 36

    @Published private(set) var isSessionActive = false
    @Published private(set) var isMicrophoneMuted = false
    @Published private(set) var isOutputMuted = false
    @Published private(set) var isMicrophoneMuteAvailable = false

    var compactControlRowHeight: CGFloat {
        isSessionActive ? Self.compactControlRowHeight : 0
    }

    private let inputMute: AudioMuteControlling
    private let outputMute: AudioMuteControlling
    private let isMicrophoneActive: () -> Bool
    private var cancellables = Set<AnyCancellable>()

    init(
        inputMute: AudioMuteControlling = SystemInputMuteController.shared,
        outputMute: AudioMuteControlling = SystemVolumeController.shared,
        microphoneActivePublisher: AnyPublisher<Bool, Never>? = nil,
        isMicrophoneActive: (() -> Bool)? = nil
    ) {
        self.inputMute = inputMute
        self.outputMute = outputMute
        self.isMicrophoneActive = isMicrophoneActive ?? { PrivacyIndicatorManager.shared.microphoneActive }

        let micPublisher = microphoneActivePublisher
            ?? PrivacyIndicatorManager.shared.$microphoneActive.eraseToAnyPublisher()
        bindPublishers(microphoneActivePublisher: micPublisher)
        refreshSession()
    }

    func start() {
        SystemInputMuteController.shared.start()
        SystemVolumeController.shared.start()
        refreshSession()
    }

    func toggleMicrophoneMute() {
        guard isMicrophoneMuteAvailable else { return }
        inputMute.toggleMute()
        refreshMuteState()
    }

    func toggleOutputMute() {
        HUDSuppressionCoordinator.shared.suppressVolumeHUD(for: 1.5)
        outputMute.toggleMute()
        refreshMuteState()
    }

    func refreshSession() {
        applySession(microphoneActive: isMicrophoneActive())
    }

    static func shouldShowControls(microphoneActive: Bool) -> Bool {
        Defaults[.enableVoiceChatControls]
            && Defaults[.enableMicrophoneDetection]
            && microphoneActive
    }

    static func shouldShowHeaderControls() -> Bool {
        Defaults[.enableVoiceChatControls]
    }

    private func applySession(microphoneActive: Bool) {
        isSessionActive = Self.shouldShowControls(microphoneActive: microphoneActive)
        refreshMuteState()
    }

    private func bindPublishers(microphoneActivePublisher: AnyPublisher<Bool, Never>) {
        microphoneActivePublisher
            .sink { [weak self] isActive in
                self?.applySession(microphoneActive: isActive)
            }
            .store(in: &cancellables)

        Defaults.publisher(.enableVoiceChatControls)
            .sink { [weak self] _ in
                self?.refreshSession()
            }
            .store(in: &cancellables)

        Defaults.publisher(.enableMicrophoneDetection)
            .sink { [weak self] _ in
                self?.refreshSession()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .systemVolumeDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMuteState()
            }
            .store(in: &cancellables)

        if let inputController = inputMute as? SystemInputMuteController {
            inputController.onMuteChange = { [weak self] muted in
                Task { @MainActor in
                    guard let self else { return }
                    self.isMicrophoneMuted = muted
                    self.isMicrophoneMuteAvailable = inputController.isMuteAvailable
                }
            }
        }
    }

    private func refreshMuteState() {
        isMicrophoneMuteAvailable = inputMute.isMuteAvailable
        isMicrophoneMuted = inputMute.isMuted
        isOutputMuted = outputMute.isMuted
    }
}
