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

import CoreAudio
import Foundation

protocol AudioMuteControlling: AnyObject {
    var isMuted: Bool { get }
    var isMuteAvailable: Bool { get }
    func toggleMute()
}

/// Mutes the default input device via CoreAudio. System-wide, not Discord/Meet in-app mute.
final class SystemInputMuteController: AudioMuteControlling {
    static let shared = SystemInputMuteController()

    var onMuteChange: ((Bool) -> Void)?

    private let callbackQueue = DispatchQueue(label: "com.dynamicisland.input-mute-listener")
    private var currentDeviceID: AudioDeviceID = 0
    private var listenersInstalled = false
    private var muteElement: AudioObjectPropertyElement?

    private let candidateElements: [AudioObjectPropertyElement] = [
        kAudioObjectPropertyElementMain,
        AudioObjectPropertyElement(1),
        AudioObjectPropertyElement(2)
    ]

    private init() {
        currentDeviceID = resolveDefaultInputDevice()
        refreshMuteElement()
        installDefaultDeviceListener()
        installMuteListener(for: currentDeviceID)
        notifyCurrentState()
    }

    func start() {}

    var isMuted: Bool {
        getMuteState()
    }

    var isMuteAvailable: Bool {
        muteElement != nil || !muteElements().isEmpty
    }

    func toggleMute() {
        guard isMuteAvailable else { return }
        setMuted(!isMuted)
    }

    func setMuted(_ muted: Bool) {
        guard isMuteAvailable else { return }
        var muteFlag: UInt32 = muted ? 1 : 0
        let elements = muteElements()

        if elements.isEmpty {
            _ = setData(data: &muteFlag)
            notifyCurrentState()
            return
        }

        for element in elements {
            var value = muteFlag
            let status = setData(element: element, data: &value)
            if status == noErr {
                muteElement = element
            }
        }
        notifyCurrentState()
    }

    private func resolveDefaultInputDevice() -> AudioDeviceID {
        var deviceID = AudioDeviceID()
        var size = UInt32(MemoryLayout.size(ofValue: deviceID))
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        if status != noErr {
            return 0
        }
        return deviceID
    }

    private func installDefaultDeviceListener() {
        guard !listenersInstalled else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            callbackQueue
        ) { [weak self] _, _ in
            self?.handleDefaultDeviceChanged()
        }
        if status == noErr {
            listenersInstalled = true
        }
    }

    private func installMuteListener(for deviceID: AudioDeviceID) {
        guard deviceID != 0, let element = muteElement ?? resolveMuteElement(deviceID: deviceID) else { return }
        muteElement = element
        var address = makeAddress(element: element)
        AudioObjectAddPropertyListenerBlock(deviceID, &address, callbackQueue) { [weak self] _, _ in
            self?.notifyCurrentState()
        }
    }

    private func handleDefaultDeviceChanged() {
        callbackQueue.async { [weak self] in
            guard let self else { return }
            self.currentDeviceID = self.resolveDefaultInputDevice()
            self.refreshMuteElement()
            self.installMuteListener(for: self.currentDeviceID)
            self.notifyCurrentState()
        }
    }

    private func notifyCurrentState() {
        let muted = getMuteState()
        DispatchQueue.main.async {
            self.onMuteChange?(muted)
        }
    }

    private func getMuteState() -> Bool {
        let elements = muteElements()
        if elements.isEmpty {
            var mute: UInt32 = 0
            let status = getData(data: &mute)
            return status == noErr && mute != 0
        }

        var retrieved = false
        var allMuted = true
        for element in elements {
            var value: UInt32 = 0
            let status = getData(element: element, data: &value)
            if status == noErr {
                retrieved = true
                if value == 0 {
                    allMuted = false
                }
            }
        }
        return retrieved && allMuted
    }

    private func refreshMuteElement() {
        muteElement = resolveMuteElement(deviceID: currentDeviceID)
    }

    private func resolveMuteElement(deviceID: AudioDeviceID) -> AudioObjectPropertyElement? {
        guard deviceID != 0 else { return nil }
        for element in candidateElements {
            var address = makeAddress(element: element)
            if propertyExists(deviceID: deviceID, address: &address) {
                return element
            }
        }
        return nil
    }

    private func muteElements() -> [AudioObjectPropertyElement] {
        guard currentDeviceID != 0 else { return [] }
        return candidateElements.filter { element in
            var address = makeAddress(element: element)
            return propertyExists(deviceID: currentDeviceID, address: &address)
        }
    }

    private func makeAddress(element: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: element
        )
    }

    private func propertyExists(deviceID: AudioDeviceID, address: inout AudioObjectPropertyAddress) -> Bool {
        withUnsafePointer(to: &address) { pointer in
            AudioObjectHasProperty(deviceID, pointer)
        }
    }

    private func getData(data: inout UInt32) -> OSStatus {
        var lastStatus: OSStatus = kAudioHardwareUnspecifiedError
        for element in candidateElements {
            lastStatus = getData(element: element, data: &data)
            if lastStatus == noErr {
                muteElement = element
                return lastStatus
            }
        }
        return lastStatus
    }

    private func setData(data: inout UInt32) -> OSStatus {
        var lastStatus: OSStatus = kAudioHardwareUnspecifiedError
        for element in candidateElements {
            lastStatus = setData(element: element, data: &data)
            if lastStatus == noErr {
                muteElement = element
                return lastStatus
            }
        }
        return lastStatus
    }

    private func getData(element: AudioObjectPropertyElement, data: inout UInt32) -> OSStatus {
        var address = makeAddress(element: element)
        guard currentDeviceID != 0, propertyExists(deviceID: currentDeviceID, address: &address) else {
            return kAudioHardwareUnknownPropertyError
        }
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(currentDeviceID, &address, 0, nil, &size, &data)
    }

    private func setData(element: AudioObjectPropertyElement, data: inout UInt32) -> OSStatus {
        var address = makeAddress(element: element)
        guard currentDeviceID != 0, propertyExists(deviceID: currentDeviceID, address: &address) else {
            return kAudioHardwareUnknownPropertyError
        }
        let size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(currentDeviceID, &address, 0, nil, size, &data)
    }
}

extension SystemVolumeController: AudioMuteControlling {
    var isMuteAvailable: Bool { true }
}
