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

import XCTest
@testable import Atoll

final class SoftwareUpdateTests: XCTestCase {
    func testAppcastURLPointsAtLatestGitHubReleaseAsset() {
        XCTAssertEqual(
            SoftwareUpdateFeed.appcastURL.absoluteString,
            "https://github.com/nikitaSobolev2/Dynamic-Island/releases/latest/download/appcast.xml"
        )
    }

    func testInfoPlistFeedURLMatchesSoftwareUpdateFeed() {
        let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        XCTAssertEqual(feedURL, SoftwareUpdateFeed.appcastURL.absoluteString)
    }

    func testAutomaticUpdateChecksAreEnabledInInfoPlist() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "SUEnableAutomaticChecks") as? Bool, true)
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "SUAutomaticallyUpdate") as? Bool, true)
    }

    func testSparkleXPCServicesAreDisabledBecauseAppIsNotSandboxed() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "SUEnableDownloaderService") as? Bool, false)
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "SUEnableInstallerLauncherService") as? Bool, false)
    }

    func testPublicEdDSAKeyIsPresent() {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        XCTAssertEqual(key?.isEmpty, false)
    }
}
