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
import XCTest
@testable import Atoll

@MainActor
final class VoiceChatTests: XCTestCase {
    private var originalVoiceChatEnabled: Bool!
    private var originalMicrophoneDetection: Bool!

    override func setUp() {
        super.setUp()
        originalVoiceChatEnabled = Defaults[.enableVoiceChatControls]
        originalMicrophoneDetection = Defaults[.enableMicrophoneDetection]
        Defaults[.enableVoiceChatControls] = true
        Defaults[.enableMicrophoneDetection] = true
    }

    override func tearDown() {
        Defaults[.enableVoiceChatControls] = originalVoiceChatEnabled
        Defaults[.enableMicrophoneDetection] = originalMicrophoneDetection
        VoiceChatManager.shared.refreshSession()
        super.tearDown()
    }

    func testSessionOffWhenFeatureDisabled() {
        let microphone = CurrentValueSubject<Bool, Never>(true)
        let manager = makeManager(microphone: microphone)

        XCTAssertTrue(manager.isSessionActive)

        Defaults[.enableVoiceChatControls] = false
        manager.refreshSession()

        XCTAssertFalse(manager.isSessionActive)
        XCTAssertEqual(manager.compactControlRowHeight, 0)
    }

    func testSessionOffWhenMicrophoneDetectionDisabled() {
        let microphone = CurrentValueSubject<Bool, Never>(true)
        let manager = makeManager(microphone: microphone)

        XCTAssertTrue(manager.isSessionActive)

        Defaults[.enableMicrophoneDetection] = false
        manager.refreshSession()

        XCTAssertFalse(manager.isSessionActive)
        XCTAssertEqual(manager.compactControlRowHeight, 0)
    }

    func testSessionOffWhenMicrophoneInactive() {
        let microphone = CurrentValueSubject<Bool, Never>(true)
        let manager = makeManager(microphone: microphone)
        XCTAssertTrue(manager.isSessionActive)
        XCTAssertEqual(manager.compactControlRowHeight, VoiceChatManager.compactControlRowHeight)

        microphone.send(false)

        XCTAssertFalse(manager.isSessionActive)
        XCTAssertEqual(manager.compactControlRowHeight, 0)
    }

    func testSessionTurnsOnWhenMicrophoneBecomesActive() {
        let microphone = CurrentValueSubject<Bool, Never>(false)
        let manager = makeManager(microphone: microphone)
        XCTAssertFalse(manager.isSessionActive)

        microphone.send(true)

        XCTAssertTrue(manager.isSessionActive)
        XCTAssertEqual(manager.compactControlRowHeight, VoiceChatManager.compactControlRowHeight)
    }

    func testShouldShowControlsFollowsLiveMicrophone() {
        XCTAssertTrue(VoiceChatManager.shouldShowControls(microphoneActive: true))
        XCTAssertFalse(VoiceChatManager.shouldShowControls(microphoneActive: false))
    }

    func testMuteToggleUpdatesPublishedState() {
        let input = FakeAudioMuteStore()
        let output = FakeAudioMuteStore()
        let manager = makeManager(input: input, output: output)

        manager.toggleMicrophoneMute()
        XCTAssertTrue(manager.isMicrophoneMuted)
        XCTAssertTrue(input.isMuted)

        manager.toggleMicrophoneMute()
        XCTAssertFalse(manager.isMicrophoneMuted)

        manager.toggleOutputMute()
        XCTAssertTrue(manager.isOutputMuted)
        XCTAssertTrue(output.isMuted)
    }

    func testUnavailableInputMuteDoesNotToggle() {
        let input = FakeAudioMuteStore()
        input.isMuteAvailable = false
        let manager = makeManager(input: input)

        XCTAssertFalse(manager.isMicrophoneMuteAvailable)

        manager.toggleMicrophoneMute()

        XCTAssertFalse(input.isMuted)
        XCTAssertFalse(manager.isMicrophoneMuted)
    }

    private func makeManager(
        microphone: CurrentValueSubject<Bool, Never> = .init(true),
        input: FakeAudioMuteStore = FakeAudioMuteStore(),
        output: FakeAudioMuteStore = FakeAudioMuteStore()
    ) -> VoiceChatManager {
        VoiceChatManager(
            inputMute: input,
            outputMute: output,
            microphoneActivePublisher: microphone.eraseToAnyPublisher(),
            isMicrophoneActive: { microphone.value }
        )
    }
}

private final class FakeAudioMuteStore: AudioMuteControlling {
    var isMuted = false
    var isMuteAvailable = true

    func toggleMute() {
        guard isMuteAvailable else { return }
        isMuted.toggle()
    }
}
