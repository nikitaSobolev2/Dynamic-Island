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
import ApplicationServices
import CoreGraphics
import Foundation

struct WindowSnapTarget: Equatable {
    let processID: pid_t
    let windowNumber: CGWindowID
}

protocol WindowFrameMoving {
    func apply(_ frame: CGRect, to target: WindowSnapTarget)
}

protocol WindowSnapWindowLocating {
    func target(at point: NSPoint) -> WindowSnapTarget?
    func currentOrigin(of target: WindowSnapTarget) -> CGPoint?
    func cocoaFrame(of target: WindowSnapTarget) -> CGRect?
}

enum WindowCoordinateSpace {
    static func primaryScreenFrame() -> CGRect {
        NSScreen.screens.first { $0.frame.origin == .zero }?.frame
            ?? NSScreen.main?.frame
            ?? .zero
    }

    static func axPoint(fromCocoaRect rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX, y: primaryScreenFrame().maxY - rect.maxY)
    }

    static func cocoaRect(fromCGWindowBounds bounds: CGRect) -> CGRect {
        let maxY = primaryScreenFrame().maxY - bounds.minY
        return CGRect(
            x: bounds.minX,
            y: maxY - bounds.height,
            width: bounds.width,
            height: bounds.height
        )
    }

    static func cgPoint(fromCocoa point: NSPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryScreenFrame().maxY - point.y)
    }
}

final class AXWindowFrameMover: WindowFrameMoving {
    func apply(_ frame: CGRect, to target: WindowSnapTarget) {
        guard let window = accessibilityWindow(matching: target) else { return }
        let position = WindowCoordinateSpace.axPoint(fromCocoaRect: frame)
        var positionValue = position
        var sizeValue = frame.size
        if let positionRef = AXValueCreate(.cgPoint, &positionValue) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionRef)
        }
        if let sizeRef = AXValueCreate(.cgSize, &sizeValue) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeRef)
        }
        if let positionRef = AXValueCreate(.cgPoint, &positionValue) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionRef)
        }
    }

    private func accessibilityWindow(matching target: WindowSnapTarget) -> AXUIElement? {
        let application = AXUIElementCreateApplication(target.processID)
        var windowsRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            application,
            kAXWindowsAttribute as CFString,
            &windowsRef
        )
        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            return nil
        }

        let expectedOrigin = CGWindowListLocator.origin(of: target)
        return windows.first { window in
            guard let origin = axOrigin(of: window), let expectedOrigin else { return false }
            return hypot(origin.x - expectedOrigin.x, origin.y - expectedOrigin.y) < 8
        } ?? windows.first
    }

    private func axOrigin(of window: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value) == .success,
              let axValue = value
        else {
            return nil
        }
        var point = CGPoint.zero
        guard CFGetTypeID(axValue) == AXValueGetTypeID() else { return nil }
        let axValueRef = unsafeBitCast(axValue, to: AXValue.self)
        guard AXValueGetValue(axValueRef, .cgPoint, &point) else { return nil }
        return point
    }
}

final class CGWindowListLocator: WindowSnapWindowLocating {
    func target(at point: NSPoint) -> WindowSnapTarget? {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        guard let windows = info as? [[String: Any]] else { return nil }
        let excluded = Self.islandWindowNumbers()

        for window in windows {
            guard let parsed = Self.parseWindow(window) else { continue }
            guard !excluded.contains(parsed.windowNumber) else { continue }
            let cocoa = WindowCoordinateSpace.cocoaRect(fromCGWindowBounds: parsed.bounds)
            guard cocoa.insetBy(dx: -2, dy: -2).contains(point) else { continue }
            return WindowSnapTarget(processID: parsed.processID, windowNumber: parsed.windowNumber)
        }
        return nil
    }

    func currentOrigin(of target: WindowSnapTarget) -> CGPoint? {
        Self.window(matching: target)?.bounds.origin
    }

    func cocoaFrame(of target: WindowSnapTarget) -> CGRect? {
        guard let bounds = Self.window(matching: target)?.bounds else { return nil }
        return WindowCoordinateSpace.cocoaRect(fromCGWindowBounds: bounds)
    }

    static func origin(of target: WindowSnapTarget) -> CGPoint? {
        window(matching: target)?.bounds.origin
    }

    private static func window(matching target: WindowSnapTarget) -> (
        processID: pid_t,
        windowNumber: CGWindowID,
        bounds: CGRect
    )? {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        guard let windows = info as? [[String: Any]] else { return nil }
        return windows.compactMap(parseWindow).first { $0.windowNumber == target.windowNumber }
    }

    private static func islandWindowNumbers() -> Set<CGWindowID> {
        guard let windows = AppDelegate.shared?.windows.values else {
            if let window = AppDelegate.shared?.window {
                return [CGWindowID(window.windowNumber)]
            }
            return []
        }
        var numbers = Set(windows.map { CGWindowID($0.windowNumber) })
        if let extra = AppDelegate.shared?.window {
            numbers.insert(CGWindowID(extra.windowNumber))
        }
        return numbers
    }

    private static func parseWindow(_ window: [String: Any]) -> (
        processID: pid_t,
        windowNumber: CGWindowID,
        bounds: CGRect
    )? {
        let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
        guard layer < 20 else { return nil }
        let pid = pid_t((window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0)
        guard pid > 0 else { return nil }
        let number = CGWindowID((window[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0)
        guard number != 0 else { return nil }
        var bounds = CGRect.zero
        guard let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
              CGRectMakeWithDictionaryRepresentation(boundsDict, &bounds),
              bounds.width >= 120,
              bounds.height >= 60
        else {
            return nil
        }
        return (pid, number, bounds)
    }
}
