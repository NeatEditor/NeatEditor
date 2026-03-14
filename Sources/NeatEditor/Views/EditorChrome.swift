import SwiftUI

enum EditorChrome {
    static let tabBarBackground = Color(NSColor.windowBackgroundColor)
    static let editorSurface = Color(NSColor.controlBackgroundColor)
    static let border = Color(NSColor.separatorColor).opacity(1)
    static let hoverFill = Color.secondary.opacity(0.08)
}

struct EditorSurfaceBorderShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
