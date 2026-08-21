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

import AppKit
import Defaults
import XCTest
@testable import Atoll

final class SettingsPortTests: XCTestCase {
    private var originalLowBatteryStyle: BatteryNotificationStyle!
    private var originalTimerInputStyle: TimerInputStyle!
    private var originalEnableThirdPartyCalendar: Bool!
    private var originalSelectedCalendarApp: ThirdPartyCalendarApp!
    private var originalEnableLLMUsage: Bool!
    private var originalEnableClaude: Bool!
    private var originalEnableCodex: Bool!
    private var originalEnableCursor: Bool!
    private var originalEnableAntigravity: Bool!

    override func setUp() {
        super.setUp()
        originalLowBatteryStyle = Defaults[.lowBatteryHUDStyle]
        originalTimerInputStyle = Defaults[.timerInputStyle]
        originalEnableThirdPartyCalendar = Defaults[.enableThirdPartyCalendarApp]
        originalSelectedCalendarApp = Defaults[.selectedCalendarApp]
        originalEnableLLMUsage = Defaults[.enableLLMUsageFeature]
        originalEnableClaude = Defaults[.enableClaudeProvider]
        originalEnableCodex = Defaults[.enableCodexProvider]
        originalEnableCursor = Defaults[.enableCursorProvider]
        originalEnableAntigravity = Defaults[.enableAntigravityProvider]
    }

    override func tearDown() {
        Defaults[.lowBatteryHUDStyle] = originalLowBatteryStyle
        Defaults[.timerInputStyle] = originalTimerInputStyle
        Defaults[.enableThirdPartyCalendarApp] = originalEnableThirdPartyCalendar
        Defaults[.selectedCalendarApp] = originalSelectedCalendarApp
        Defaults[.enableLLMUsageFeature] = originalEnableLLMUsage
        Defaults[.enableClaudeProvider] = originalEnableClaude
        Defaults[.enableCodexProvider] = originalEnableCodex
        Defaults[.enableCursorProvider] = originalEnableCursor
        Defaults[.enableAntigravityProvider] = originalEnableAntigravity
        super.tearDown()
    }

    func testBatteryNotificationStyleRoundTrip() {
        Defaults[.lowBatteryHUDStyle] = .compact
        XCTAssertEqual(Defaults[.lowBatteryHUDStyle], .compact)

        Defaults[.lowBatteryHUDStyle] = .standard
        XCTAssertEqual(Defaults[.lowBatteryHUDStyle], .standard)
    }

    func testTimerInputStyleRoundTrip() {
        Defaults[.timerInputStyle] = .ruler
        XCTAssertEqual(Defaults[.timerInputStyle], .ruler)

        Defaults[.timerInputStyle] = .manual
        XCTAssertEqual(Defaults[.timerInputStyle], .manual)
    }

    func testCalendarAppURLUsesAppleCalendarWhenThirdPartyDisabled() {
        Defaults[.enableThirdPartyCalendarApp] = false
        let url = makeEvent().calendarAppURL()

        XCTAssertEqual(url?.scheme, "ical")
    }

    func testCalendarAppURLUsesFantasticalWhenSelected() {
        Defaults[.enableThirdPartyCalendarApp] = true
        Defaults[.selectedCalendarApp] = .fantastical
        let url = makeEvent().calendarAppURL()

        XCTAssertEqual(url?.scheme, "x-fantastical3")
    }

    func testCalendarAppURLUsesNotionCalendarWhenSelected() {
        Defaults[.enableThirdPartyCalendarApp] = true
        Defaults[.selectedCalendarApp] = .notionCalendar
        let url = makeEvent().calendarAppURL()

        XCTAssertEqual(url?.scheme, "cron")
        XCTAssertEqual(url?.host, "showEvent")
    }

    func testLLMUsageProviderFlagsRoundTripWithoutNetwork() {
        Defaults[.enableLLMUsageFeature] = true
        Defaults[.enableClaudeProvider] = false
        Defaults[.enableCodexProvider] = false
        Defaults[.enableCursorProvider] = true
        Defaults[.enableAntigravityProvider] = true

        XCTAssertTrue(Defaults[.enableLLMUsageFeature])
        XCTAssertFalse(Defaults[.enableClaudeProvider])
        XCTAssertFalse(Defaults[.enableCodexProvider])
        XCTAssertTrue(Defaults[.enableCursorProvider])
        XCTAssertTrue(Defaults[.enableAntigravityProvider])
    }

    func testGroqProviderExposesSupportedModels() {
        XCTAssertTrue(AIModelProvider.allCases.contains(.groq))
        XCTAssertFalse(AIModelProvider.groq.supportedModels.isEmpty)
        XCTAssertTrue(
            AIModelProvider.groq.supportedModels.contains(where: { $0.id == "llama-3.3-70b-versatile" })
        )
    }

    func testSparkleFeedURLUsesLatestGitHubRelease() {
        let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        XCTAssertEqual(feedURL, SoftwareUpdateFeed.appcastURL.absoluteString)
    }

    private func makeEvent() -> EventModel {
        EventModel(
            id: "event-id",
            start: Date(timeIntervalSince1970: 1_700_000_000),
            end: Date(timeIntervalSince1970: 1_700_003_600),
            title: "Standup",
            location: nil,
            notes: nil,
            url: nil,
            isAllDay: false,
            type: .event(.accepted),
            calendar: CalendarModel(
                accountName: "user@example.com",
                id: "calendar-id",
                title: "Work",
                color: .red,
                isSubscribed: false,
                isReminder: false
            ),
            participants: [],
            timeZone: TimeZone(secondsFromGMT: 0),
            hasRecurrenceRules: false,
            priority: nil,
            conferenceURL: nil
        )
    }
}
