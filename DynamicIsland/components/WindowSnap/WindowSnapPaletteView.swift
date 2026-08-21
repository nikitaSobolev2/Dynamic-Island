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
import SwiftUI

struct WindowSnapPaletteView: View {
    let highlightedRegion: WindowSnapRegion?
    @Default(.accentColor) private var accent

    private let highlightAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8)

    var body: some View {
        VStack(spacing: WindowSnapPaletteLayout.gap) {
            tile(.full)
            row([.topLeft, .top, .topRight])
            row([.left, .center, .right])
            row([.bottomLeft, .bottom, .bottomRight])
        }
        .animation(highlightAnimation, value: highlightedRegion)
        .background {
            WindowSnapPaletteFrameReader { frame in
                WindowSnapManager.shared.updatePaletteScreenFrame(frame)
            }
        }
    }

    private func row(_ regions: [WindowSnapRegion]) -> some View {
        HStack(spacing: WindowSnapPaletteLayout.gap) {
            ForEach(regions, id: \.self) { region in
                tile(region)
            }
        }
    }

    private func tile(_ region: WindowSnapRegion) -> some View {
        let highlighted = region == highlightedRegion
        return RoundedRectangle(cornerRadius: WindowSnapPaletteLayout.tileCornerRadius, style: .continuous)
            .fill(highlighted ? accent.opacity(0.35) : Color.white.opacity(0.08))
            .overlay {
                RoundedRectangle(cornerRadius: WindowSnapPaletteLayout.tileCornerRadius, style: .continuous)
                    .stroke(
                        highlighted ? accent.opacity(0.9) : Color.white.opacity(0.12),
                        lineWidth: highlighted ? 1.5 : 1
                    )
            }
            .overlay {
                WindowSnapGlyph(region: region, highlighted: highlighted, accent: accent)
                    .padding(.horizontal, region == .full ? 48 : 10)
                    .padding(.vertical, 5)
            }
            .scaleEffect(highlighted ? 1.04 : 1)
            .frame(height: region == .full ? WindowSnapPaletteLayout.fullRowHeight : WindowSnapPaletteLayout.cellHeight)
    }
}

private struct WindowSnapGlyph: View {
    let region: WindowSnapRegion
    let highlighted: Bool
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let screen = screenRect(in: proxy.size)
            let fill = region.glyphFillNormalized
            let fillRect = CGRect(
                x: screen.minX + fill.minX * screen.width,
                y: screen.minY + fill.minY * screen.height,
                width: fill.width * screen.width,
                height: fill.height * screen.height
            ).insetBy(dx: 1.5, dy: 1.5)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.white.opacity(highlighted ? 0.95 : 0.45), lineWidth: 1)
                    .frame(width: screen.width, height: screen.height)
                    .offset(x: screen.minX, y: screen.minY)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(highlighted ? Color.white : accent.opacity(0.85))
                    .frame(width: fillRect.width, height: fillRect.height)
                    .offset(x: fillRect.minX, y: fillRect.minY)
            }
        }
        .allowsHitTesting(false)
    }

    private func screenRect(in size: CGSize) -> CGRect {
        let aspect: CGFloat = 1.6
        let height = min(size.height, size.width / aspect)
        let width = height * aspect
        return CGRect(
            x: (size.width - width) / 2,
            y: (size.height - height) / 2,
            width: width,
            height: height
        )
    }
}

private struct WindowSnapPaletteFrameReader: NSViewRepresentable {
    var onChange: (CGRect) -> Void

    func makeNSView(context: Context) -> WindowSnapPaletteFrameProbe {
        let probe = WindowSnapPaletteFrameProbe()
        probe.onChange = onChange
        return probe
    }

    func updateNSView(_ probe: WindowSnapPaletteFrameProbe, context: Context) {
        probe.onChange = onChange
        probe.publishScreenFrame()
    }
}

private final class WindowSnapPaletteFrameProbe: NSView {
    var onChange: ((CGRect) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(publishScreenFrame),
            name: NSView.frameDidChangeNotification,
            object: self
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        publishScreenFrame()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        publishScreenFrame()
    }

    @objc func publishScreenFrame() {
        guard let window, !bounds.isEmpty else {
            onChange?(.zero)
            return
        }
        onChange?(window.convertToScreen(convert(bounds, to: nil)))
    }
}
