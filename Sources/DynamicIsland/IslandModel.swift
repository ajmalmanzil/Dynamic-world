import IslandCore
import SwiftUI

enum IslandTab: String, CaseIterable, Identifiable {
    case clock, todo, meetings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .clock: return "World Clock"
        case .todo: return "Todo"
        case .meetings: return "Meetings"
        }
    }

    var icon: DotMatrixIcon {
        switch self {
        case .clock: return .clock
        case .todo: return .checklist
        case .meetings: return .calendar
        }
    }
}

@MainActor
final class IslandModel: ObservableObject {
    @Published var isExpanded = false
    @Published var tab: IslandTab = .clock
    @Published var notchSize = NotchGeometry.fallbackNotchSize
    @Published var todoDraft = ""
    /// Cities shown on the clock tab; drives its height.
    @Published var clockCityCount = 1

    /// Width of the concave "flare" where the island meets the top of the screen.
    static let topRadius: CGFloat = 8
    static let expandedWidth: CGFloat = 480
    /// Largest size any tab uses; the panel is sized to fit it.
    static let maxExpandedSize = CGSize(width: expandedWidth, height: 240)

    var openSettings: () -> Void = {}

    /// Expanded size depends on the tab: the clock needs less height than the lists.
    var expandedSize: CGSize {
        switch tab {
        case .clock:
            let content = ClockTab.contentHeight(cityCount: clockCityCount)
            return CGSize(width: Self.expandedWidth, height: notchSize.height + 8 + content + 14)
        case .todo, .meetings: return Self.maxExpandedSize
        }
    }

    var collapsedSize: CGSize {
        CGSize(width: notchSize.width + Self.topRadius * 2, height: notchSize.height)
    }
}
