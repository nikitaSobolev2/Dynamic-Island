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

import CoreGraphics
import Foundation

enum WindowSnapRegion: String, CaseIterable, Hashable {
    case full
    case topLeft
    case top
    case topRight
    case left
    case center
    case right
    case bottomLeft
    case bottom
    case bottomRight

    static let centerScale: CGFloat = 0.6

    var title: String {
        switch self {
        case .full: return "Full Screen"
        case .topLeft: return "Top Left"
        case .top: return "Top Half"
        case .topRight: return "Top Right"
        case .left: return "Left Half"
        case .center: return "Center"
        case .right: return "Right Half"
        case .bottomLeft: return "Bottom Left"
        case .bottom: return "Bottom Half"
        case .bottomRight: return "Bottom Right"
        }
    }

    /// Fill rect inside a 1×1 mini-screen used by `WindowSnapGlyph`.
    var glyphFillNormalized: CGRect {
        switch self {
        case .full:
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        case .left:
            return CGRect(x: 0, y: 0, width: 0.5, height: 1)
        case .right:
            return CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        case .top:
            return CGRect(x: 0, y: 0, width: 1, height: 0.5)
        case .bottom:
            return CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
        case .topLeft:
            return CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        case .topRight:
            return CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        case .bottomLeft:
            return CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)
        case .bottomRight:
            return CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        case .center:
            let inset = (1 - Self.centerScale) / 2
            return CGRect(x: inset, y: inset, width: Self.centerScale, height: Self.centerScale)
        }
    }

    func frame(in visibleFrame: CGRect) -> CGRect {
        let midX = visibleFrame.midX
        let midY = visibleFrame.midY
        let halfWidth = visibleFrame.width / 2
        let halfHeight = visibleFrame.height / 2

        switch self {
        case .full:
            return visibleFrame
        case .left:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: halfWidth,
                height: visibleFrame.height
            )
        case .right:
            return CGRect(
                x: midX,
                y: visibleFrame.minY,
                width: halfWidth,
                height: visibleFrame.height
            )
        case .top:
            return CGRect(
                x: visibleFrame.minX,
                y: midY,
                width: visibleFrame.width,
                height: halfHeight
            )
        case .bottom:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width,
                height: halfHeight
            )
        case .topLeft:
            return CGRect(x: visibleFrame.minX, y: midY, width: halfWidth, height: halfHeight)
        case .topRight:
            return CGRect(x: midX, y: midY, width: halfWidth, height: halfHeight)
        case .bottomLeft:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: halfWidth, height: halfHeight)
        case .bottomRight:
            return CGRect(x: midX, y: visibleFrame.minY, width: halfWidth, height: halfHeight)
        case .center:
            let width = visibleFrame.width * Self.centerScale
            let height = visibleFrame.height * Self.centerScale
            return CGRect(
                x: visibleFrame.midX - width / 2,
                y: visibleFrame.midY - height / 2,
                width: width,
                height: height
            )
        }
    }
}

struct NotchSnapSite: Equatable {
    let screenName: String
    let screenFrame: CGRect
    let visibleFrame: CGRect
    let closedNotchSize: CGSize
}

enum WindowSnapActivation {
    static func rect(for site: NotchSnapSite) -> CGRect {
        let width = max(site.closedNotchSize.width, 1)
        let height = max(site.closedNotchSize.height, 14)
        return CGRect(
            x: site.screenFrame.midX - width / 2,
            y: site.visibleFrame.maxY - height,
            width: width,
            height: height
        )
    }

    static func contains(_ point: CGPoint, site: NotchSnapSite, windowFrame: CGRect? = nil) -> Bool {
        let dropZone = rect(for: site)
        if containsInclusive(dropZone, point) {
            return true
        }
        guard let windowFrame else { return false }
        return windowFrame.intersects(dropZone)
    }

    static func frameAfterDrag(
        starting start: CGRect,
        from downPoint: CGPoint,
        to point: CGPoint,
        visibleTop: CGFloat
    ) -> CGRect {
        var frame = start.offsetBy(dx: point.x - downPoint.x, dy: point.y - downPoint.y)
        if frame.maxY > visibleTop {
            frame.origin.y -= frame.maxY - visibleTop
        }
        return frame
    }

    private static func containsInclusive(_ rect: CGRect, _ point: CGPoint) -> Bool {
        point.x >= rect.minX
            && point.x <= rect.maxX
            && point.y >= rect.minY
            && point.y <= rect.maxY
    }
}

enum WindowSnapPaletteLayout {
    static let islandSize = CGSize(width: 420, height: 180)
    static let gap: CGFloat = 6
    static let fullRowHeight: CGFloat = 28
    static let cellHeight: CGFloat = 34
    static let tileCornerRadius: CGFloat = 10

    static var paletteSize: CGSize { islandSize }

    static func frames(in bounds: CGRect) -> [WindowSnapRegion: CGRect] {
        let columnWidth = (bounds.width - gap * 2) / 3
        let full = CGRect(x: bounds.minX, y: bounds.maxY - fullRowHeight, width: bounds.width, height: fullRowHeight)
        let topY = full.minY - gap - cellHeight
        let middleY = topY - gap - cellHeight
        let bottomY = middleY - gap - cellHeight

        func cell(column: CGFloat, y: CGFloat) -> CGRect {
            CGRect(
                x: bounds.minX + column * (columnWidth + gap),
                y: y,
                width: columnWidth,
                height: cellHeight
            )
        }

        return [
            .full: full,
            .topLeft: cell(column: 0, y: topY),
            .top: cell(column: 1, y: topY),
            .topRight: cell(column: 2, y: topY),
            .left: cell(column: 0, y: middleY),
            .center: cell(column: 1, y: middleY),
            .right: cell(column: 2, y: middleY),
            .bottomLeft: cell(column: 0, y: bottomY),
            .bottom: cell(column: 1, y: bottomY),
            .bottomRight: cell(column: 2, y: bottomY)
        ]
    }

    static func trackingBounds(for site: NotchSnapSite) -> CGRect {
        CGRect(
            x: site.screenFrame.midX - islandSize.width / 2,
            y: site.screenFrame.maxY - islandSize.height,
            width: islandSize.width,
            height: islandSize.height
        )
    }

    static func screenTileFrames(for site: NotchSnapSite, paletteFrame: CGRect? = nil) -> [WindowSnapRegion: CGRect] {
        let bounds = paletteFrame ?? trackingBounds(for: site)
        return frames(in: bounds)
    }

    static func closedNotchHitRect(in islandFrame: CGRect, closedNotchSize: CGSize) -> CGRect {
        let width = max(closedNotchSize.width, 1)
        let height = max(closedNotchSize.height, 1)
        return CGRect(
            x: islandFrame.midX - width / 2,
            y: islandFrame.maxY - height,
            width: width,
            height: height
        )
    }

    static func shouldPassClicksThrough(
        at point: CGPoint,
        islandFrame: CGRect,
        closedNotchSize: CGSize,
        isIslandClosed: Bool,
        isSnapActive: Bool
    ) -> Bool {
        if isSnapActive { return true }
        guard containsInclusive(islandFrame, point) else { return false }
        if closedNotchContains(point, islandFrame: islandFrame, closedNotchSize: closedNotchSize) {
            return false
        }
        return isIslandClosed
    }

    static func closedNotchContains(
        _ point: CGPoint,
        islandFrame: CGRect,
        closedNotchSize: CGSize
    ) -> Bool {
        containsInclusive(closedNotchHitRect(in: islandFrame, closedNotchSize: closedNotchSize), point)
    }

    static func containsCursor(_ point: CGPoint, site: NotchSnapSite, paletteFrame: CGRect? = nil) -> Bool {
        if let paletteFrame, containsInclusive(paletteFrame, point) {
            return true
        }
        return containsInclusive(trackingBounds(for: site), point)
    }

    static func region(at point: CGPoint, site: NotchSnapSite, paletteFrame: CGRect? = nil) -> WindowSnapRegion? {
        let bounds = paletteFrame ?? trackingBounds(for: site)
        guard containsInclusive(bounds, point) else { return nil }
        let local = CGPoint(x: point.x - bounds.minX, y: point.y - bounds.minY)
        let tiles = frames(in: CGRect(origin: .zero, size: bounds.size))
        if let exact = WindowSnapRegion.allCases.first(where: { tiles[$0]?.contains(local) == true }) {
            return exact
        }
        return nearestRegion(to: local, in: tiles)
    }

    private static func nearestRegion(to point: CGPoint, in tiles: [WindowSnapRegion: CGRect]) -> WindowSnapRegion? {
        WindowSnapRegion.allCases.min { lhs, rhs in
            distance(point, to: tiles[lhs]) < distance(point, to: tiles[rhs])
        }
    }

    private static func distance(_ point: CGPoint, to rect: CGRect?) -> CGFloat {
        guard let rect else { return .greatestFiniteMagnitude }
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(dx, dy)
    }

    private static func containsInclusive(_ rect: CGRect, _ point: CGPoint) -> Bool {
        point.x >= rect.minX
            && point.x <= rect.maxX
            && point.y >= rect.minY
            && point.y <= rect.maxY
    }
}
