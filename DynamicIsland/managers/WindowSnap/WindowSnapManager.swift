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
import Combine
import Defaults
import Foundation

@MainActor
final class WindowSnapManager: ObservableObject {
    static let shared = WindowSnapManager()
    static let dragThreshold: CGFloat = 8

    @Published private(set) var isSessionActive = false
    @Published private(set) var isPaletteVisible = false
    @Published private(set) var highlightedRegion: WindowSnapRegion?
    @Published private(set) var activeSite: NotchSnapSite?

    private var paletteScreenFrame: CGRect?

    private let mover: WindowFrameMoving
    private let locator: WindowSnapWindowLocating
    private let resolveNotch: (NSPoint, CGRect?) -> NotchSnapSite?
    private let isFeatureEnabled: () -> Bool
    private let isAccessibilityTrusted: () -> Bool
    private let requestAccessibility: () -> Void

    private var cancellables = Set<AnyCancellable>()
    private var pendingTarget: WindowSnapTarget?
    private var downPoint: NSPoint = .zero
    private var downFrame: CGRect?
    private var initialOrigin: CGPoint?
    private var confirmedMove = false
    private var didPromptForAccessibility = false
    private var buttonWasPressed = false
    private var buttonPollTimer: Timer?
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var keyMonitor: Any?
    private var localKeyMonitor: Any?
    private var didTraceThisDrag = false
    private var startedFromDropZone = false

    init(
        mover: WindowFrameMoving = AXWindowFrameMover(),
        locator: WindowSnapWindowLocating = CGWindowListLocator(),
        resolveNotch: ((NSPoint, CGRect?) -> NotchSnapSite?)? = nil,
        isFeatureEnabled: @escaping () -> Bool = { Defaults[.enableWindowSnap] },
        isAccessibilityTrusted: (() -> Bool)? = nil,
        requestAccessibility: (() -> Void)? = nil
    ) {
        self.mover = mover
        self.locator = locator
        self.resolveNotch = resolveNotch ?? Self.defaultNotchSite
        self.isFeatureEnabled = isFeatureEnabled
        self.isAccessibilityTrusted = isAccessibilityTrusted ?? {
            AccessibilityPermissionStore.shared.isAuthorized
        }
        self.requestAccessibility = requestAccessibility ?? {
            AccessibilityPermissionStore.shared.requestAuthorizationPrompt()
        }

        Defaults.publisher(.enableWindowSnap, options: [])
            .sink { [weak self] _ in
                self?.syncMonitoring()
            }
            .store(in: &cancellables)
    }

    func start() {
        syncMonitoring()
        WindowSnapTrace.write(
            "start enabled=\(isFeatureEnabled()) screens=\(NSScreen.screens.count) delegate=\(AppDelegate.shared != nil) visibleTop=\(NSScreen.main?.visibleFrame.maxY ?? -1) screenTop=\(NSScreen.main?.frame.maxY ?? -1)"
        )
    }

    func stop() {
        stopButtonPolling()
        removeMonitors()
        dismissSession()
        AppDelegate.shared?.window?.ignoresMouseEvents = false
        AppDelegate.shared?.windows.values.forEach { window in
            window.ignoresMouseEvents = false
        }
    }

    func shouldShowPalette(on screenName: String?) -> Bool {
        isPaletteVisible && activeSite?.screenName == screenName
    }

    var isHoldingIsland: Bool {
        isSessionActive || isPaletteVisible
    }

    func shouldReceiveIslandHits(at viewPoint: NSPoint, in view: NSView) -> Bool {
        if isHoldingIsland { return false }
        guard let window = view.window else { return true }
        if isIslandWindowClosed(window) {
            return isPointInClosedNotch(viewPoint, in: view, window: window)
        }
        return true
    }

    func updatePaletteScreenFrame(_ frame: CGRect) {
        guard frame.width > 1, frame.height > 1 else {
            paletteScreenFrame = nil
            return
        }
        paletteScreenFrame = frame
    }

    func handleMouseDown(at point: NSPoint) {
        guard isFeatureEnabled() else { return }
        guard !buttonWasPressed else { return }
        resetDragState()
        buttonWasPressed = true
        downPoint = point
        acquireTarget(at: point)
        startedFromDropZone = resolveNotch(point, estimatedWindowFrame(at: point)) != nil
        updateIslandClickThrough()
        WindowSnapTrace.write("down point=\(point) target=\(String(describing: pendingTarget)) dropZone=\(startedFromDropZone)")
    }

    func handleMouseDragged(at point: NSPoint) {
        guard isFeatureEnabled() else { return }
        if pendingTarget == nil {
            acquireTarget(at: point)
        }
        confirmMoveIfNeeded(to: point)
        guard confirmedMove else { return }
        if !didTraceThisDrag {
            didTraceThisDrag = true
            let site = resolveNotch(point, estimatedWindowFrame(at: point))
            WindowSnapTrace.write(
                "drag point=\(point) inZone=\(site != nil) target=\(pendingTarget != nil) visibleTop=\(NSScreen.main?.visibleFrame.maxY ?? -1)"
            )
        }
        updatePalette(at: point)
        if isPaletteVisible {
            isSessionActive = true
        }
        updateIslandClickThrough()
    }

    func handleMouseUp(at point: NSPoint) {
        defer {
            buttonWasPressed = false
            dismissSession()
        }
        guard confirmedMove else { return }
        if pendingTarget == nil {
            acquireTarget(at: point)
        }
        updatePalette(at: point)
        guard let region = highlightedRegion,
              let site = activeSite,
              let target = pendingTarget
        else { return }
        guard isAccessibilityTrusted() else {
            requestAccessibility()
            return
        }
        mover.apply(region.frame(in: site.visibleFrame), to: target)
    }

    func handleEscape() {
        guard isSessionActive else { return }
        dismissSession()
    }

    private func acquireTarget(at point: NSPoint) {
        guard let target = locator.target(at: point) else { return }
        pendingTarget = target
        if downPoint == .zero {
            downPoint = point
        }
        initialOrigin = locator.currentOrigin(of: target)
        downFrame = locator.cocoaFrame(of: target)
    }

    private func confirmMoveIfNeeded(to point: NSPoint) {
        guard !confirmedMove else { return }
        if hasWindowMoved() {
            confirmedMove = true
            return
        }
        guard !startedFromDropZone, pendingTarget != nil else { return }
        let translation = hypot(point.x - downPoint.x, point.y - downPoint.y)
        confirmedMove = translation >= Self.dragThreshold
    }

    private func hasWindowMoved() -> Bool {
        guard let target = pendingTarget,
              let initialOrigin,
              let current = locator.currentOrigin(of: target)
        else { return false }
        return hypot(current.x - initialOrigin.x, current.y - initialOrigin.y) >= 1
    }

    private func updatePalette(at point: NSPoint) {
        guard pendingTarget != nil else {
            hidePalette()
            return
        }
        let site = siteForPalette(at: point)
        guard let site else {
            hidePalette()
            return
        }

        if !isAccessibilityTrusted(), !didPromptForAccessibility {
            didPromptForAccessibility = true
            requestAccessibility()
        }

        activeSite = site
        if !isPaletteVisible {
            WindowSnapTrace.write("show palette at \(point) on \(site.screenName)")
        }
        isPaletteVisible = true

        let region = WindowSnapPaletteLayout.region(
            at: point,
            site: site,
            paletteFrame: paletteScreenFrame
        )
        if region != highlightedRegion, region != nil {
            performHighlightHaptic()
        }
        highlightedRegion = region
    }

    private func siteForPalette(at point: NSPoint) -> NotchSnapSite? {
        let windowFrame = estimatedWindowFrame(at: point)
        if let site = resolveNotch(point, windowFrame) {
            return site
        }
        guard isPaletteVisible, let activeSite else { return nil }
        guard WindowSnapPaletteLayout.containsCursor(point, site: activeSite, paletteFrame: paletteScreenFrame) else { return nil }
        return activeSite
    }

    private func estimatedWindowFrame(at point: NSPoint) -> CGRect? {
        guard let downFrame else {
            return pendingTarget.flatMap { locator.cocoaFrame(of: $0) }
        }
        let visibleTop = NSScreen.screens.first { screen in
            point.x >= screen.frame.minX && point.x <= screen.frame.maxX
        }?.visibleFrame.maxY
            ?? NSScreen.main?.visibleFrame.maxY
            ?? downFrame.maxY
        return WindowSnapActivation.frameAfterDrag(
            starting: downFrame,
            from: downPoint,
            to: point,
            visibleTop: visibleTop
        )
    }

    private func hidePalette() {
        isPaletteVisible = false
        highlightedRegion = nil
        activeSite = nil
        paletteScreenFrame = nil
    }

    private func dismissSession() {
        pendingTarget = nil
        downPoint = .zero
        downFrame = nil
        initialOrigin = nil
        confirmedMove = false
        didPromptForAccessibility = false
        didTraceThisDrag = false
        isSessionActive = false
        startedFromDropZone = false
        hidePalette()
        updateIslandClickThrough()
    }

    private func resetDragState() {
        pendingTarget = nil
        downPoint = .zero
        downFrame = nil
        initialOrigin = nil
        confirmedMove = false
        didPromptForAccessibility = false
        didTraceThisDrag = false
        isSessionActive = false
        startedFromDropZone = false
        hidePalette()
    }

    private func syncMonitoring() {
        if isFeatureEnabled() {
            installMonitors()
            startButtonPolling()
        } else {
            stop()
        }
    }

    private func startButtonPolling() {
        guard buttonPollTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollMouseButton()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        buttonPollTimer = timer
    }

    private func stopButtonPolling() {
        buttonPollTimer?.invalidate()
        buttonPollTimer = nil
        buttonWasPressed = false
    }

    private func pollMouseButton() {
        guard isFeatureEnabled() else { return }
        let pressed = NSEvent.pressedMouseButtons & 1 != 0
        let point = NSEvent.mouseLocation
        if pressed, !buttonWasPressed {
            handleMouseDown(at: point)
        } else if pressed, buttonWasPressed {
            handleMouseDragged(at: point)
        } else if !pressed, buttonWasPressed {
            handleMouseUp(at: point)
        }
        buttonWasPressed = pressed
        updateIslandClickThrough()
    }

    private func updateIslandClickThrough() {
        let point = NSEvent.mouseLocation
        for window in islandWindows() {
            window.ignoresMouseEvents = shouldIgnoreMouseEvents(for: window, at: point)
        }
    }

    private func shouldIgnoreMouseEvents(for window: NSWindow, at point: NSPoint) -> Bool {
        guard isFeatureEnabled() else { return false }
        if isPaletteVisible || isSessionActive { return true }
        if buttonWasPressed, pendingTarget != nil { return true }
        return WindowSnapPaletteLayout.shouldPassClicksThrough(
            at: point,
            islandFrame: window.frame,
            closedNotchSize: closedNotchSize(for: window),
            isIslandClosed: isIslandWindowClosed(window),
            isSnapActive: false
        )
    }

    private func isPointInClosedNotch(_ viewPoint: NSPoint, in view: NSView, window: NSWindow) -> Bool {
        let size = closedNotchSize(for: window)
        let notchY = view.isFlipped ? 0 : view.bounds.height - size.height
        let notch = CGRect(
            x: (view.bounds.width - size.width) / 2,
            y: notchY,
            width: size.width,
            height: size.height
        )
        return viewPoint.x >= notch.minX
            && viewPoint.x <= notch.maxX
            && viewPoint.y >= notch.minY
            && viewPoint.y <= notch.maxY
    }

    private func islandWindows() -> [NSWindow] {
        guard let appDelegate = AppDelegate.shared else { return [] }
        var windows = Array(appDelegate.windows.values)
        if let extra = appDelegate.window, !windows.contains(where: { $0 === extra }) {
            windows.append(extra)
        }
        return windows
    }

    private func isIslandWindowClosed(_ window: NSWindow) -> Bool {
        guard let viewModel = islandViewModel(for: window) else { return true }
        if viewModel.notchState == .open { return false }
        return !viewModel.coordinator.isHoverPreviewActive
    }

    private func islandViewModel(for window: NSWindow) -> DynamicIslandViewModel? {
        guard let appDelegate = AppDelegate.shared else { return nil }
        if let screen = appDelegate.windows.first(where: { $0.value === window })?.key {
            return appDelegate.viewModels[screen]
        }
        if appDelegate.window === window {
            return appDelegate.vm
        }
        return nil
    }

    private func closedNotchSize(for window: NSWindow) -> CGSize {
        guard let appDelegate = AppDelegate.shared else {
            return CGSize(width: 180, height: 32)
        }
        if let screen = appDelegate.windows.first(where: { $0.value === window })?.key {
            return appDelegate.viewModels[screen]?.closedNotchSize ?? appDelegate.vm.closedNotchSize
        }
        return appDelegate.vm.closedNotchSize
    }

    private func installMonitors() {
        guard mouseMonitor == nil else { return }
        let mouseMask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseMask) { [weak self] event in
            let point = NSEvent.mouseLocation
            let type = event.type
            Task { @MainActor in
                self?.handleMonitorEvent(type, at: point)
            }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseMask) { [weak self] event in
            let point = NSEvent.mouseLocation
            let type = event.type
            Task { @MainActor in
                self?.handleMonitorEvent(type, at: point)
            }
            return event
        }
        let handleEscapeKey: (NSEvent) -> Void = { [weak self] event in
            guard event.keyCode == 53 else { return }
            Task { @MainActor in
                self?.handleEscape()
            }
        }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown], handler: handleEscapeKey)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            handleEscapeKey(event)
            return event
        }
    }

    private func handleMonitorEvent(_ type: NSEvent.EventType, at point: NSPoint) {
        switch type {
        case .leftMouseDown:
            handleMouseDown(at: point)
        case .leftMouseDragged:
            handleMouseDragged(at: point)
        case .leftMouseUp:
            handleMouseUp(at: point)
        default:
            break
        }
    }

    private func removeMonitors() {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        mouseMonitor = nil
        localMouseMonitor = nil
        keyMonitor = nil
        localKeyMonitor = nil
    }

    private func performHighlightHaptic() {
        guard Defaults[.enableHaptics] else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    static func defaultNotchSite(at point: NSPoint, windowFrame: CGRect?) -> NotchSnapSite? {
        notchSites().first { site in
            WindowSnapActivation.contains(point, site: site, windowFrame: windowFrame)
        }
    }

    private static func notchSites() -> [NotchSnapSite] {
        if let appDelegate = AppDelegate.shared {
            return islandScreens(from: appDelegate).map { viewModel, screen in
                NotchSnapSite(
                    screenName: viewModel.screen ?? screen.localizedName,
                    screenFrame: screen.frame,
                    visibleFrame: screen.visibleFrame,
                    closedNotchSize: viewModel.closedNotchSize
                )
            }
        }
        return NSScreen.screens.map { screen in
            NotchSnapSite(
                screenName: screen.localizedName,
                screenFrame: screen.frame,
                visibleFrame: screen.visibleFrame,
                closedNotchSize: getClosedNotchSize(screen: screen.localizedName)
            )
        }
    }

    private static func islandScreens(from appDelegate: AppDelegate) -> [(DynamicIslandViewModel, NSScreen)] {
        if Defaults[.showOnAllDisplays] {
            return appDelegate.viewModels.map { screen, viewModel in
                (viewModel, screen)
            }
        }
        let screen = NSScreen.screens.first { $0.localizedName == appDelegate.vm.screen }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return [] }
        return [(appDelegate.vm, screen)]
    }
}

private enum WindowSnapTrace {
    static let path = "/tmp/atoll-window-snap.log"

    static func write(_ message: String) {
        Logger.log(message, category: .debug)
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        let url = URL(fileURLWithPath: path)
        do {
            if FileManager.default.fileExists(atPath: path) {
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: url)
            }
        } catch {
            Logger.log("window snap trace write failed: \(error.localizedDescription)", category: .error)
        }
    }
}
