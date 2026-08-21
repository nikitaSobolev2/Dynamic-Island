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

import Foundation
import Sparkle

enum SoftwareUpdateFeed {
    static let appcastURL = URL(
        string: "https://github.com/nikitaSobolev2/Dynamic-Island/releases/latest/download/appcast.xml"
    )!
}

/// Owns Sparkle for the life of the process.
///
/// Atoll is an agent app (`LSUIElement`), so the standard Sparkle windows never
/// come to the front. The custom driver presents floating SwiftUI windows and
/// auto-grants scheduled update checks. The updater itself must start after
/// `applicationDidFinishLaunching` — starting from `App.init` races NSApplication.
@MainActor
final class SoftwareUpdateController {
    static let shared = SoftwareUpdateController()

    let updater: SPUUpdater

    private let userDriver: AtollUserDriver
    private let updaterDelegate: SparkleUpdaterDelegate
    private var didStart = false

    private init() {
        let userDriver = AtollUserDriver()
        let updaterDelegate = SparkleUpdaterDelegate()
        self.userDriver = userDriver
        self.updaterDelegate = updaterDelegate
        updater = SPUUpdater(
            hostBundle: .main,
            applicationBundle: .main,
            userDriver: userDriver,
            delegate: updaterDelegate
        )
        updater.automaticallyChecksForUpdates = true
        updater.automaticallyDownloadsUpdates = true
    }

    func start() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        guard !didStart else { return }
        do {
            try updater.start()
            didStart = true
        } catch {
            NSLog("Sparkle failed to start: \(error.localizedDescription)")
        }
    }
}

final class SparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        SoftwareUpdateFeed.appcastURL.absoluteString
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        NSLog("Sparkle aborted: \(error.localizedDescription)")
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor _: SPUUpdateCheck,
        error: (any Error)?
    ) {
        guard let error else { return }
        NSLog("Sparkle update cycle failed: \(error.localizedDescription)")
    }
}
