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
import CoreGraphics
import XCTest
@testable import Atoll

final class WindowSnapRegionTests: XCTestCase {
    private let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)

    func testLeftHalfUsesLeadingOriginAndHalfWidth() {
        let frame = WindowSnapRegion.left.frame(in: visible)
        XCTAssertEqual(frame, CGRect(x: 0, y: 0, width: 500, height: 800))
    }

    func testRightHalfStartsAtHorizontalMidpoint() {
        let frame = WindowSnapRegion.right.frame(in: visible)
        XCTAssertEqual(frame, CGRect(x: 500, y: 0, width: 500, height: 800))
    }

    func testTopHalfSitsInUpperCocoaHalf() {
        let frame = WindowSnapRegion.top.frame(in: visible)
        XCTAssertEqual(frame, CGRect(x: 0, y: 400, width: 1000, height: 400))
    }

    func testBottomHalfSitsInLowerCocoaHalf() {
        let frame = WindowSnapRegion.bottom.frame(in: visible)
        XCTAssertEqual(frame, CGRect(x: 0, y: 0, width: 1000, height: 400))
    }

    func testCenterIsSixtyPercentAndCentered() {
        let frame = WindowSnapRegion.center.frame(in: visible)
        XCTAssertEqual(frame.width, 600, accuracy: 0.001)
        XCTAssertEqual(frame.height, 480, accuracy: 0.001)
        XCTAssertEqual(frame.midX, visible.midX, accuracy: 0.001)
        XCTAssertEqual(frame.midY, visible.midY, accuracy: 0.001)
    }

    func testFullMatchesVisibleFrame() {
        XCTAssertEqual(WindowSnapRegion.full.frame(in: visible), visible)
    }

    func testQuartersDoNotOverlap() {
        let frames = [
            WindowSnapRegion.topLeft,
            WindowSnapRegion.topRight,
            WindowSnapRegion.bottomLeft,
            WindowSnapRegion.bottomRight
        ].map { $0.frame(in: visible) }

        for index in frames.indices {
            for other in frames.indices where other > index {
                XCTAssertFalse(frames[index].intersects(frames[other].insetBy(dx: 1, dy: 1)))
            }
        }
        XCTAssertEqual(frames[0], CGRect(x: 0, y: 400, width: 500, height: 400))
        XCTAssertEqual(frames[1], CGRect(x: 500, y: 400, width: 500, height: 400))
        XCTAssertEqual(frames[2], CGRect(x: 0, y: 0, width: 500, height: 400))
        XCTAssertEqual(frames[3], CGRect(x: 500, y: 0, width: 500, height: 400))
    }

    func testPaletteHitTestSelectsLeftTile() throws {
        let site = Self.sampleSite
        let tiles = WindowSnapPaletteLayout.screenTileFrames(for: site)
        let left = try XCTUnwrap(tiles[.left])
        XCTAssertEqual(WindowSnapPaletteLayout.region(at: CGPoint(x: left.midX, y: left.midY), site: site), .left)
    }

    func testPaletteHitTestFollowsMouseAtTitleBar() {
        let site = Self.sampleSite
        let mouse = CGPoint(x: site.screenFrame.midX, y: site.visibleFrame.maxY - 16)
        XCTAssertNotNil(WindowSnapPaletteLayout.region(at: mouse, site: site))
    }

    func testPaletteHitTestMissesOutsideTiles() {
        let site = Self.sampleSite
        XCTAssertNil(WindowSnapPaletteLayout.region(at: CGPoint(x: 0, y: 0), site: site))
    }

    func testHoverUsesPaletteFrameNotIslandWindow() {
        let site = Self.sampleSite
        let palette = CGRect(x: 310, y: 610, width: 380, height: 148)
        let window = CGRect(x: 290, y: 590, width: 420, height: 192)
        let pointOnFullTile = CGPoint(x: palette.midX, y: palette.maxY - 8)

        XCTAssertEqual(
            WindowSnapPaletteLayout.region(at: pointOnFullTile, site: site, paletteFrame: palette),
            .full
        )
        XCTAssertNotEqual(
            WindowSnapPaletteLayout.region(at: pointOnFullTile, site: site, paletteFrame: window),
            WindowSnapPaletteLayout.region(at: pointOnFullTile, site: site, paletteFrame: palette)
        )
    }

    func testSnapAreaPassesClicksThroughToWindows() {
        let island = CGRect(x: 290, y: 620, width: 420, height: 180)
        let closed = CGSize(width: 180, height: 32)
        let inSnapBody = CGPoint(x: island.midX, y: island.minY + 40)
        let inClosedNotch = CGPoint(x: island.midX, y: island.maxY - 8)
        let inHoverHeaderButton = CGPoint(x: island.minX + 12, y: island.maxY - 8)

        XCTAssertTrue(
            WindowSnapPaletteLayout.shouldPassClicksThrough(
                at: inSnapBody,
                islandFrame: island,
                closedNotchSize: closed,
                isIslandClosed: true,
                isSnapActive: false
            )
        )
        XCTAssertFalse(
            WindowSnapPaletteLayout.shouldPassClicksThrough(
                at: inClosedNotch,
                islandFrame: island,
                closedNotchSize: closed,
                isIslandClosed: true,
                isSnapActive: false
            )
        )
        XCTAssertTrue(
            WindowSnapPaletteLayout.shouldPassClicksThrough(
                at: inHoverHeaderButton,
                islandFrame: island,
                closedNotchSize: closed,
                isIslandClosed: true,
                isSnapActive: false
            )
        )
        XCTAssertFalse(
            WindowSnapPaletteLayout.shouldPassClicksThrough(
                at: inHoverHeaderButton,
                islandFrame: island,
                closedNotchSize: closed,
                isIslandClosed: false,
                isSnapActive: false
            )
        )
        XCTAssertFalse(
            WindowSnapPaletteLayout.shouldPassClicksThrough(
                at: inSnapBody,
                islandFrame: island,
                closedNotchSize: closed,
                isIslandClosed: false,
                isSnapActive: false
            )
        )
        XCTAssertTrue(
            WindowSnapPaletteLayout.shouldPassClicksThrough(
                at: inClosedNotch,
                islandFrame: island,
                closedNotchSize: closed,
                isIslandClosed: true,
                isSnapActive: true
            )
        )
    }

    func testActivationIsNotchSizedBoxBelowTheMenuBar() {
        let site = Self.sampleSite
        let dropZone = WindowSnapActivation.rect(for: site)
        XCTAssertEqual(dropZone.width, site.closedNotchSize.width, accuracy: 0.001)
        XCTAssertEqual(dropZone.height, site.closedNotchSize.height, accuracy: 0.001)
        XCTAssertEqual(dropZone.maxY, site.visibleFrame.maxY, accuracy: 0.001)
        XCTAssertEqual(dropZone.midX, site.screenFrame.midX, accuracy: 0.001)

        let inDropZone = CGPoint(x: site.screenFrame.midX, y: site.visibleFrame.maxY - 12)
        XCTAssertTrue(WindowSnapActivation.contains(inDropZone, site: site))
    }

    func testActivationIgnoresCursorInsideTheNotch() {
        let site = Self.sampleSite
        let inNotch = CGPoint(x: site.screenFrame.midX, y: site.screenFrame.maxY - 8)
        XCTAssertFalse(WindowSnapActivation.contains(inNotch, site: site))
    }

    func testActivationIgnoresCursorAwayFromIsland() {
        let site = Self.sampleSite
        XCTAssertFalse(WindowSnapActivation.contains(CGPoint(x: 10, y: 10), site: site))
    }

    func testParkedWindowCoveringNotchBoxActivates() {
        let site = Self.sampleSite
        let window = CGRect(
            x: 100,
            y: site.visibleFrame.maxY - 300,
            width: 800,
            height: 300
        )
        let trafficLights = CGPoint(x: 40, y: site.visibleFrame.maxY - 16)
        XCTAssertFalse(WindowSnapActivation.contains(trafficLights, site: site))
        XCTAssertTrue(WindowSnapActivation.contains(trafficLights, site: site, windowFrame: window))
    }

    func testAxPointUsesTopLeftOriginRelativeToPrimaryScreen() {
        let primary = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main
        guard let primary else {
            XCTFail("Expected a screen for coordinate conversion")
            return
        }
        let rect = CGRect(x: 10, y: 20, width: 100, height: 50)
        let axPoint = WindowCoordinateSpace.axPoint(fromCocoaRect: rect)
        XCTAssertEqual(axPoint.x, 10)
        XCTAssertEqual(axPoint.y, primary.frame.maxY - rect.maxY, accuracy: 0.001)
    }

    private static let sampleSite = NotchSnapSite(
        screenName: "Built-in",
        screenFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
        visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 762),
        closedNotchSize: CGSize(width: 180, height: 32)
    )
}

@MainActor
final class WindowSnapManagerTests: XCTestCase {
    private let target = WindowSnapTarget(processID: 42, windowNumber: 7)
    private let site = NotchSnapSite(
        screenName: "Built-in",
        screenFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
        visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 762),
        closedNotchSize: CGSize(width: 180, height: 32)
    )

    func testPaletteStaysHiddenWhenFeatureDisabled() {
        let mover = FakeWindowFrameMover()
        let manager = makeManager(mover: mover, enabled: false)
        dragFromTitleBar(manager, onto: dropZonePoint)

        XCTAssertFalse(manager.isPaletteVisible)
        XCTAssertFalse(manager.isSessionActive)
    }

    func testDraggingFromWindowInteriorStillShowsPalette() {
        let manager = makeManager()
        manager.handleMouseDown(at: CGPoint(x: 300, y: 500))
        manager.handleMouseDragged(at: dropZonePoint)

        XCTAssertTrue(manager.isPaletteVisible)
    }

    func testDraggingIntoDropZoneBelowNotchShowsPalette() {
        let manager = makeManager()
        dragFromTitleBar(manager, onto: dropZonePoint)

        XCTAssertTrue(manager.isSessionActive)
        XCTAssertTrue(manager.isPaletteVisible)
        XCTAssertTrue(manager.shouldShowPalette(on: "Built-in"))
    }

    func testDraggingIntoTheNotchDoesNotShowPalette() {
        let manager = makeManager()
        dragFromTitleBar(manager, onto: notchPoint)

        XCTAssertFalse(manager.isPaletteVisible)
    }

    func testPaletteStaysHiddenWhenWindowIsNotIdentifiedYet() {
        let manager = makeManager(locatorReturnsTarget: false)
        dragFromTitleBar(manager, onto: dropZonePoint)

        XCTAssertFalse(manager.isPaletteVisible)
    }

    func testMouseDragFromDropZoneWithoutWindowMoveDoesNotShowPalette() {
        let manager = makeManager()
        manager.handleMouseDown(at: dropZonePoint)
        manager.handleMouseDragged(at: CGPoint(x: dropZonePoint.x + 24, y: dropZonePoint.y))

        XCTAssertFalse(manager.isPaletteVisible)
        XCTAssertFalse(manager.isSessionActive)
    }

    func testWindowMoveFromDropZoneShowsPalette() {
        let locator = fakeLocator()
        let manager = makeManager(locator: locator)
        manager.handleMouseDown(at: dropZonePoint)
        locator.origin = CGPoint(x: 140, y: 50)
        manager.handleMouseDragged(at: dropZonePoint)

        XCTAssertTrue(manager.isPaletteVisible)
        XCTAssertTrue(manager.isSessionActive)
    }

    func testHighlightFollowsTileUnderCursor() {
        let manager = makeManager()
        dragFromTitleBar(manager, onto: dropZonePoint)
        manager.handleMouseDragged(at: tilePoint(.left))

        XCTAssertEqual(manager.highlightedRegion, .left)
    }

    func testDraggingOntoIslandKeepsPaletteVisible() {
        let manager = makeManager()
        dragFromTitleBar(manager, onto: dropZonePoint)
        manager.handleMouseDragged(at: tilePoint(.center))

        XCTAssertTrue(manager.isPaletteVisible)
        XCTAssertTrue(manager.isSessionActive)
    }

    func testSpuriousMouseDownDuringDragDoesNotResetSession() {
        let manager = makeManager()
        dragFromTitleBar(manager, onto: dropZonePoint)

        manager.handleMouseDown(at: tilePoint(.center))

        XCTAssertTrue(manager.isPaletteVisible)
        XCTAssertTrue(manager.isSessionActive)
    }

    func testLeavingIslandHidesPaletteButKeepsSession() {
        let manager = makeManager()
        dragFromTitleBar(manager, onto: dropZonePoint)
        manager.handleMouseDragged(at: CGPoint(x: 10, y: 10))

        XCTAssertFalse(manager.isPaletteVisible)
        XCTAssertTrue(manager.isSessionActive)
    }

    func testReenteringDropZoneShowsPaletteAgain() {
        let manager = makeManager()
        dragFromTitleBar(manager, onto: dropZonePoint)
        manager.handleMouseDragged(at: CGPoint(x: 10, y: 10))
        manager.handleMouseDragged(at: dropZonePoint)

        XCTAssertTrue(manager.isPaletteVisible)
        XCTAssertTrue(manager.isSessionActive)
    }

    func testMouseUpOnTileAppliesVisibleFrame() {
        let mover = FakeWindowFrameMover()
        let manager = makeManager(mover: mover)
        dragFromTitleBar(manager, onto: dropZonePoint)
        manager.handleMouseDragged(at: tilePoint(.left))
        manager.handleMouseUp(at: tilePoint(.left))

        XCTAssertEqual(mover.applied.count, 1)
        XCTAssertEqual(mover.applied.first?.0, WindowSnapRegion.left.frame(in: site.visibleFrame))
        XCTAssertEqual(mover.applied.first?.1, target)
        XCTAssertFalse(manager.isPaletteVisible)
        XCTAssertFalse(manager.isSessionActive)
    }

    func testUntrustedAccessibilityDoesNotApplyFrame() {
        let mover = FakeWindowFrameMover()
        var prompted = false
        let manager = makeManager(mover: mover, trusted: false, requestAccessibility: { prompted = true })
        dragFromTitleBar(manager, onto: dropZonePoint)
        manager.handleMouseDragged(at: tilePoint(.left))
        XCTAssertTrue(manager.isPaletteVisible)

        manager.handleMouseUp(at: tilePoint(.left))

        XCTAssertTrue(prompted)
        XCTAssertTrue(mover.applied.isEmpty)
        XCTAssertFalse(manager.isPaletteVisible)
    }

    func testMouseUpOutsideTilesDoesNotApply() {
        let mover = FakeWindowFrameMover()
        let manager = makeManager(mover: mover)
        dragFromTitleBar(manager, onto: dropZonePoint)
        manager.handleMouseUp(at: CGPoint(x: 10, y: 10))

        XCTAssertTrue(mover.applied.isEmpty)
        XCTAssertFalse(manager.isPaletteVisible)
    }

    private var notchPoint: CGPoint {
        CGPoint(x: site.screenFrame.midX, y: site.screenFrame.maxY - 8)
    }

    private var dropZonePoint: CGPoint {
        CGPoint(x: site.screenFrame.midX, y: site.visibleFrame.maxY - 16)
    }

    private func tilePoint(_ region: WindowSnapRegion) -> CGPoint {
        let frame = WindowSnapPaletteLayout.screenTileFrames(for: site)[region]!
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    private func dragFromTitleBar(_ manager: WindowSnapManager, onto point: CGPoint) {
        manager.handleMouseDown(at: CGPoint(x: 300, y: 680))
        manager.handleMouseDragged(at: point)
    }

    private func fakeLocator(returnsTarget: Bool = true) -> FakeWindowLocator {
        let locator = FakeWindowLocator()
        locator.targetToReturn = returnsTarget ? target : nil
        locator.cocoaFrame = CGRect(x: 20, y: 400, width: 80, height: 200)
        locator.origin = CGPoint(x: 100, y: 50)
        return locator
    }

    private func makeManager(
        mover: FakeWindowFrameMover = FakeWindowFrameMover(),
        enabled: Bool = true,
        trusted: Bool = true,
        locatorReturnsTarget: Bool = true,
        locator: FakeWindowLocator? = nil,
        requestAccessibility: @escaping () -> Void = {}
    ) -> WindowSnapManager {
        let locator = locator ?? fakeLocator(returnsTarget: locatorReturnsTarget)
        return WindowSnapManager(
            mover: mover,
            locator: locator,
            resolveNotch: { [site] point, windowFrame in
                WindowSnapActivation.contains(point, site: site, windowFrame: windowFrame) ? site : nil
            },
            isFeatureEnabled: { enabled },
            isAccessibilityTrusted: { trusted },
            requestAccessibility: requestAccessibility
        )
    }
}

private final class FakeWindowFrameMover: WindowFrameMoving {
    var applied: [(CGRect, WindowSnapTarget)] = []

    func apply(_ frame: CGRect, to target: WindowSnapTarget) {
        applied.append((frame, target))
    }
}

private final class FakeWindowLocator: WindowSnapWindowLocating {
    var targetToReturn: WindowSnapTarget?
    var origin = CGPoint.zero
    var cocoaFrame = CGRect.zero

    func target(at point: NSPoint) -> WindowSnapTarget? {
        targetToReturn
    }

    func currentOrigin(of target: WindowSnapTarget) -> CGPoint? {
        origin
    }

    func cocoaFrame(of target: WindowSnapTarget) -> CGRect? {
        cocoaFrame
    }
}
