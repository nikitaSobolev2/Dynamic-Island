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

import SwiftUI

struct ScreenshotClosedNotchNotification: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @State private var screenshotCaptureManager = ScreenshotCaptureManager.shared
    let isHovering: Bool

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                Text("Screenshot")
                    .font(.subheadline)
            }

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + 10)

            HStack {
                if screenshotCaptureManager.originalRevealURL != nil {
                    Button(action: screenshotCaptureManager.revealInFinder) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                            Text("Reveal")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "camera.fill")
                        .font(.subheadline)
                }
            }
            .frame(width: 76, alignment: .trailing)
        }
        .frame(height: vm.effectiveClosedNotchHeight + (isHovering ? 8 : 0), alignment: .center)
    }
}
