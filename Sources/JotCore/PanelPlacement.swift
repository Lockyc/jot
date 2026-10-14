import CoreGraphics

public enum PanelPlacement {
    /// The panel's frame on show: its saved size centred on the cursor, shrunk to fit and
    /// clamped inside the visible frame of the cursor's screen so no edge lands off-screen.
    public static func frame(size: CGSize, centredOn point: CGPoint, within visible: CGRect) -> CGRect {
        let w = min(size.width, visible.width), h = min(size.height, visible.height)
        let x = min(max(point.x - w / 2, visible.minX), visible.maxX - w)
        let y = min(max(point.y - h / 2, visible.minY), visible.maxY - h)
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
