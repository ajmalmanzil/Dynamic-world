import AppKit
import SwiftUI

/// Icons from Streamline (https://www.streamlinehq.com), CC BY 4.0: the "Sharp" free set, plus
/// "crop-selection" from the core set with its rounded corners squared off. Strokes thinned to 1.25 (on 24px).
enum StreamlineIcon: String, CaseIterable {
    case clock = "watch-square-time"
    case todo = "bullet-list"
    case calendar = "calendar-mark"
    case refresh = "arrow-reload-horizontal-2"
    case settings = "cog"
    case screenshots = "crop-selection"

    static let strokeWidth = 1.25

    /// Grid the path data is drawn on.
    private var viewBox: Double { self == .screenshots ? 14 : 24 }

    /// Path data on a `viewBox`-sized grid.
    private var paths: [String] {
        switch self {
        case .clock:
            return ["M7 5.518V2h10v3.538M7 18.494V22h10v-3.506", "M19.5 5.5v13h-15v-13z", "M12 8v4h3"]
        case .todo:
            return ["M10 4h13m-13 8h13m-13 8h13M2 2h4v4H2zm0 8h4v4H2zm0 8h4v4H2z"]
        case .calendar:
            return ["M2 4h20v18H2zm5-3v3m10-3v3M2 8h20M5 12.5h3m-3 5h3m2.5-5h3m2.5 0h3m-8.5 5h3"]
        case .refresh:
            return ["m15.918 13.829l-3.97 3.97l3.97 3.969M8.187 10.171l3.97-3.97l-3.97-3.969",
                    "M12.05 17.799h10.052V6.2H16.69m-4.64.001H2V17.8h5.412"]
        case .settings:
            return ["M9 12a3 3 0 1 0 6 0a3 3 0 1 0-6 0",
                    "M14.5 2h-5v2.398a8 8 0 0 0-2.831 1.637l-2.08-1.2l-2.5 4.33l2.078 1.2a8 8 0 0 0 0 3.27l-2.077 1.2l2.5 4.33l2.079-1.2a8 8 0 0 0 2.83 1.637V22h5v-2.398a8 8 0 0 0 2.832-1.637l2.08 1.2l2.5-4.33l-2.078-1.2a8 8 0 0 0 0-3.27l2.077-1.2l-2.5-4.33l-2.079 1.2A8 8 0 0 0 14.5 4.398z"]
        case .screenshots:
            return ["M6.5 3.5h4v4", "M3.5.5v10h10m-10-7h-3m10 7v3"]
        }
    }

    private var svg: String {
        let body = paths.map { "<path d=\"\($0)\"/>" }.joined()
        let stroke = Self.strokeWidth * viewBox / 24 // same visual weight on every grid
        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 \(viewBox) \(viewBox)">\
        <g fill="none" stroke="#000" stroke-width="\(stroke)">\(body)</g></svg>
        """
    }

    private static var cache: [StreamlineIcon: NSImage] = [:]

    /// Template image (tinted by `foregroundStyle`); NSImage renders the SVG as vectors.
    var image: NSImage {
        if let cached = Self.cache[self] { return cached }
        let image = NSImage(data: Data(svg.utf8)) ?? NSImage()
        image.isTemplate = true
        Self.cache[self] = image
        return image
    }
}

struct StreamlineIconView: View {
    let icon: StreamlineIcon
    var size: CGFloat = 16

    var body: some View {
        Image(nsImage: icon.image)
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
