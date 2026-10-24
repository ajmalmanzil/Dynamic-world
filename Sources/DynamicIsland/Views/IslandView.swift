import IslandCore
import SwiftUI

/// Notch silhouette: concave flares at the top corners, rounded bottom corners.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let tr = topRadius, br = min(bottomRadius, (h - tr) / 2)
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addQuadCurve(to: CGPoint(x: tr, y: tr), control: CGPoint(x: tr, y: 0))
        p.addLine(to: CGPoint(x: tr, y: h - br))
        p.addQuadCurve(to: CGPoint(x: tr + br, y: h), control: CGPoint(x: tr, y: h))
        p.addLine(to: CGPoint(x: w - tr - br, y: h))
        p.addQuadCurve(to: CGPoint(x: w - tr, y: h - br), control: CGPoint(x: w - tr, y: h))
        p.addLine(to: CGPoint(x: w - tr, y: tr))
        p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w - tr, y: 0))
        p.closeSubpath()
        return p
    }
}

struct IslandView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var settings: SettingsStore
    @ObservedObject var todos: TodoStore
    @ObservedObject var calendar: CalendarService
    @ObservedObject var screenshots: ScreenshotStore
    @State private var refreshSpin: Double = 0

    var body: some View {
        let size = model.isExpanded ? model.expandedSize : model.collapsedSize
        let shape = NotchShape(topRadius: IslandModel.topRadius, bottomRadius: model.isExpanded ? 24 : 10)

        ZStack(alignment: .top) {
            shape.fill(Color.black)
            if model.isExpanded {
                expandedContent
                    .padding(.horizontal, IslandModel.topRadius)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            topBar.frame(height: model.notchSize.height)
            Group {
                switch model.tab {
                case .clock: ClockTab(settings: settings)
                case .todo: TodoTab(model: model, todos: todos)
                case .meetings: MeetingsTab(calendar: calendar)
                case .screenshots: ScreenshotsTab(model: model, store: screenshots)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    /// Lives in the "ears" either side of the camera: tabs on the left, refresh (Meetings only) and settings on the right.
    private var topBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(settings.visibleTabs) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { model.tab = tab }
                    } label: {
                        iconLabel(tab.icon, selected: model.tab == tab)
                    }
                    .buttonStyle(.plain)
                    .help(tab.title)
                }
            }
            .padding(.leading, 10)

            Spacer(minLength: model.notchSize.width)

            HStack(spacing: 2) {
                if model.tab == .meetings && calendar.access == .granted {
                    Button {
                        withAnimation(.easeInOut(duration: 0.8)) { refreshSpin += 360 }
                        calendar.syncNow()
                    } label: {
                        iconLabel(.refresh, selected: calendar.isSyncing)
                            .rotationEffect(.degrees(refreshSpin))
                    }
                    .buttonStyle(.plain)
                    .help("Refresh from Apple Calendar")
                    .transition(.opacity)
                }
                Button(action: model.openSettings) {
                    iconLabel(.settings, selected: false)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.trailing, 10)
        }
    }

    /// Thin Streamline icon; the selected tab is full brightness with a hairline underneath.
    private func iconLabel(_ icon: StreamlineIcon, selected: Bool) -> some View {
        let color = settings.dotColor.color
        return StreamlineIconView(icon: icon, size: 15)
            .foregroundStyle(selected ? color : color.opacity(0.4))
            .frame(width: 28, height: 24)
            .overlay(alignment: .bottom) {
                Rectangle().fill(color).frame(width: 12, height: 1).opacity(selected ? 1 : 0)
            }
            .contentShape(Rectangle())
    }
}
