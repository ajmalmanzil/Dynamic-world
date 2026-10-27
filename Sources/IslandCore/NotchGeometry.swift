import CoreGraphics

/// Screen-space math for placing the island over the hardware notch.
/// All rects use AppKit coordinates (origin bottom-left, y grows upward).
public enum NotchGeometry {
    /// Island size on a screen with no notch (external displays). Height follows the menu bar when known.
    public static let fallbackNotchSize = CGSize(width: 200, height: 32)

    /// The notch is the gap between the two "auxiliary" menu bar areas on either side of the camera.
    public static func notchRect(screenFrame: CGRect,
                                 leftAreaWidth: CGFloat?,
                                 rightAreaWidth: CGFloat?,
                                 topInset: CGFloat,
                                 menuBarHeight: CGFloat = 0) -> CGRect {
        let size: CGSize
        if let left = leftAreaWidth, let right = rightAreaWidth, topInset > 0 {
            size = CGSize(width: screenFrame.width - left - right, height: topInset)
        } else {
            // No notch: a pill that sits inside the menu bar (or the default height if it auto-hides).
            size = CGSize(width: fallbackNotchSize.width,
                          height: menuBarHeight > 0 ? menuBarHeight : fallbackNotchSize.height)
        }
        return CGRect(x: screenFrame.midX - size.width / 2,
                      y: screenFrame.maxY - size.height,
                      width: size.width,
                      height: size.height)
    }

    /// A rect of `size`, horizontally centred on the notch and pinned to the top of the screen.
    public static func topCenteredRect(size: CGSize, under notch: CGRect) -> CGRect {
        CGRect(x: notch.midX - size.width / 2,
               y: notch.maxY - size.height,
               width: size.width,
               height: size.height)
    }
}
