import IslandCore
import SwiftUI

struct ScreenshotsTab: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var store: ScreenshotStore

    static let tileSize = CGSize(width: 76, height: 52)
    /// Extra room so tilted corners and shadows aren't cut off by the island edge.
    static let tiltPadding: CGFloat = 6
    static let contentHeight: CGFloat = tileSize.height + tiltPadding * 2 + 6 + 12

    var body: some View {
        Group {
            if store.accessDenied {
                message("Allow Dynamic Island to read your screenshot folder under Privacy & Security › Files and Folders.",
                        button: "Open Privacy Settings", action: store.openPrivacySettings)
            } else if store.screenshots.isEmpty {
                message("No screenshots today. Press ⇧⌘4 to take one.")
            } else {
                TimelineView(.everyMinute) { context in
                    HStack(spacing: 10) {
                        ForEach(store.screenshots) { shot in
                            ScreenshotTile(shot: shot, thumbnail: store.thumbnails[shot.url], now: context.date) { dragging in
                                model.isDraggingOut = dragging
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, Self.tiltPadding)
                }
            }
        }
        .onAppear(perform: store.start)
    }

    private func message(_ text: String, button: String? = nil, action: @escaping () -> Void = {}) -> some View {
        HStack(spacing: 10) {
            Text(text).font(.system(size: 12)).opacity(0.6)
            if let button { Button(button, action: action).controlSize(.small) }
        }
        .frame(maxWidth: .infinity, minHeight: Self.contentHeight)
    }
}

private struct ScreenshotTile: View {
    let shot: Screenshot
    let thumbnail: NSImage?
    let now: Date
    let onDragChanged: (Bool) -> Void
    @State private var hovering = false

    private static let corner = RoundedRectangle(cornerRadius: 4, style: .continuous)

    var body: some View {
        VStack(spacing: 6 + ScreenshotsTab.tiltPadding) {
            ZStack {
                Rectangle().fill(Color.white.opacity(0.06))
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .frame(width: ScreenshotsTab.tileSize.width, height: ScreenshotsTab.tileSize.height)
            .clipShape(Self.corner)
            .overlay(Self.corner.strokeBorder(Color.white.opacity(hovering ? 0.55 : 0.3), lineWidth: 1.5))
            // Elevation: a dark drop shadow for depth plus a faint light halo so it reads on the black island.
            .shadow(color: .black.opacity(0.8), radius: hovering ? 9 : 5, y: hovering ? 6 : 3)
            .shadow(color: .white.opacity(hovering ? 0.16 : 0.08), radius: hovering ? 10 : 6)
            .overlay(CopyDragSource(url: shot.url, image: thumbnail, onDragChanged: onDragChanged))
            // Slightly tilted at rest; straightens and lifts on hover.
            .rotationEffect(.degrees(hovering ? 0 : ScreenshotLibrary.tilt(for: shot.url.lastPathComponent)))
            .scaleEffect(hovering ? 1.06 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
            .onHover { hovering = $0 }

            Text(ScreenshotLibrary.ageLabel(for: shot.createdAt, now: now))
                .font(.system(size: 10).monospacedDigit())
                .opacity(0.5)
                .frame(height: 12)
        }
    }
}
