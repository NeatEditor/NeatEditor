import AppKit
import SwiftUI

struct TabBarView: View {
    @Binding var tabs: [TabItem]
    @Binding var selectedTabID: UUID?
    @State private var selectedTabFrame: CGRect = .null
    
    // Window control buttons width + padding to ensure tabs don't overlap traffic lights
    private let leadingPadding: CGFloat = 76
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach($tabs) { $tab in
                    TabItemView(tab: $tab, isSelected: selectedTabID == tab.id) {
                        selectedTabID = tab.id
                    }
                }
            }
            .padding(.leading, leadingPadding)
            .padding(.trailing, 16)
            .padding(.top, 6)
        }
        .coordinateSpace(name: TabBarLayout.coordinateSpaceName)
        .onPreferenceChange(SelectedTabFramePreferenceKey.self) { frame in
            selectedTabFrame = frame
        }
        .background(EditorChrome.tabBarBackground)
        .overlay(alignment: .bottom) {
            TabBarDividerOverlay(selectedTabFrame: selectedTabFrame)
        }
        .frame(height: 38)
    }
}

// Subview for a single Tab
struct TabItemView: View {
    private static let titleFontSize: CGFloat = 13
    private static let minimumHorizontalPadding: CGFloat = textWidth(for: "untit")
    private static let minimumTabWidth: CGFloat = {
        let titleWidth = textWidth(for: "untitleduntitled")
        return ceil(titleWidth + (minimumHorizontalPadding * 2))
    }()

    private static func textWidth(for text: String) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: titleFontSize, weight: .medium)
        ]
        return (text as NSString).size(withAttributes: attributes).width
    }

    @Binding var tab: TabItem
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                tabBackground

                HStack(spacing: 6) {
                    if isEditing {
                        TextField("", text: $tab.title)
                            .textFieldStyle(.plain)
                            .font(.system(size: Self.titleFontSize, weight: isSelected ? .medium : .regular))
                            .focused($isFocused)
                            .labelsHidden()
                            .onSubmit {
                                isEditing = false
                            }
                            .onChange(of: isFocused) { _, isFocusedValue in
                                if !isFocusedValue {
                                    isEditing = false
                                }
                            }
                            .frame(minWidth: 40)
                    } else {
                        Text(tab.title)
                            .font(.system(size: Self.titleFontSize, weight: isSelected ? .medium : .regular))
                            .foregroundColor(isSelected ? .primary : .secondary)
                    }
                }
                .padding(.horizontal, Self.minimumHorizontalPadding)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
            .frame(minWidth: Self.minimumTabWidth)
            .frame(height: 32, alignment: .bottom)
        }
        .buttonStyle(.plain)
        .zIndex(isSelected ? 1 : 0)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SelectedTabFramePreferenceKey.self,
                    value: isSelected ? proxy.frame(in: .named(TabBarLayout.coordinateSpaceName)) : .null
                )
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            isEditing = true
            isFocused = true
        })
    }

    @ViewBuilder
    private var tabBackground: some View {
        if isSelected {
            ConnectedTabFillShape(topInset: 6, topCornerRadius: 9, bottomJoinRadius: 9)
                .fill(EditorChrome.editorSurface)
                .overlay {
                    ConnectedTabBorderShape(topInset: 6, topCornerRadius: 9, bottomJoinRadius: 9)
                        .stroke(
                            EditorChrome.border,
                            style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                        )
                }
        } else if isHovering {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(EditorChrome.hoverFill)
                .padding(.horizontal, 2)
                .padding(.top, 3)
                .padding(.bottom, 5)
        }
    }
}

private enum TabBarLayout {
    static let coordinateSpaceName = "TabBarLayout"
}

private struct SelectedTabFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .null

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let nextValue = nextValue()
        if !nextValue.isNull {
            value = nextValue
        }
    }
}

private struct TabBarDividerOverlay: View {
    let selectedTabFrame: CGRect

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let y = proxy.size.height - 0.5

                if selectedTabFrame.isNull {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    return
                }

                let leftEnd = max(0, min(selectedTabFrame.minX, proxy.size.width))
                let rightStart = max(0, min(selectedTabFrame.maxX, proxy.size.width))

                if leftEnd > 0 {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: leftEnd, y: y))
                }

                if rightStart < proxy.size.width {
                    path.move(to: CGPoint(x: rightStart, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
            }
            .stroke(EditorChrome.border, lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

private struct ConnectedTabFillShape: Shape {
    let topInset: CGFloat
    let topCornerRadius: CGFloat
    let bottomJoinRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset = min(topInset, rect.width / 4)
        let topRadius = min(topCornerRadius, rect.width / 2, rect.height / 2)
        let bottomRadius = min(bottomJoinRadius, rect.width / 2, rect.height / 2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX + inset, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX + inset, y: rect.minY),
            radius: bottomRadius
        )
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.minY + topRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + inset + topRadius, y: rect.minY),
            control: CGPoint(x: rect.minX + inset, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - inset - topRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - inset, y: rect.minY + topRadius),
            control: CGPoint(x: rect.maxX - inset, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - bottomRadius))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX - inset, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.maxY),
            radius: bottomRadius
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))

        return path
    }
}

private struct ConnectedTabBorderShape: Shape {
    let topInset: CGFloat
    let topCornerRadius: CGFloat
    let bottomJoinRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset = min(topInset, rect.width / 4)
        let topRadius = min(topCornerRadius, rect.width / 2, rect.height / 2)
        let bottomRadius = min(bottomJoinRadius, rect.width / 2, rect.height / 2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX + inset, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX + inset, y: rect.minY),
            radius: bottomRadius
        )
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.minY + topRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + inset + topRadius, y: rect.minY),
            control: CGPoint(x: rect.minX + inset, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - inset - topRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - inset, y: rect.minY + topRadius),
            control: CGPoint(x: rect.maxX - inset, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - bottomRadius))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX - inset, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.maxY),
            radius: bottomRadius
        )

        return path
    }
}

#Preview {
    @Previewable @State var tabs = [
        TabItem(id: UUID(), title: "Untitled 1"),
        TabItem(id: UUID(), title: "Config.yml"),
        TabItem(id: UUID(), title: "Readme.md")
    ]
    @Previewable @State var selectedTabID: UUID?
    
    VStack(spacing: 0) {
        TabBarView(tabs: $tabs, selectedTabID: $selectedTabID)
        Spacer()
    }
    .frame(width: 400, height: 200)
    .background(EditorChrome.tabBarBackground)
    .onAppear {
        selectedTabID = tabs.first?.id
    }
}
