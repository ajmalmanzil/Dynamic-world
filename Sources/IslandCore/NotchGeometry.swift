import CoreGraphics

/// Screen-space math for placing the island over the hardware notch.
/// All rects use AppKit coordinates (origin bottom-left, y grows upward).
public enum NotchGeometry {
    /// Used when the screen has no notch (e.g. lid closed, external display only).
    public static let fallbackNotchSize = CGSize(width: 200, height: 32)

    /// The notch is the gap between the two "auxiliary" menu bar areas on either side of the camera.
    public static func notchRect(screenFrame: CGRect,
                                 leftAreaWidth: CGFloat?,
                                 rightAreaWidth: CGFloat?,
                                 topInset: CGFloat) -> CGRect {
        let size: CGSize
        if let left = leftAreaWidth, let right = rightAreaWidth, topInset > 0 {
            size = CGSize(width: screenFrame.width - left - right, height: topInset)
        } else {
            size = fallbackNotchSize
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
