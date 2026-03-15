import AppKit
import SwiftUI

struct EditorTabStripView: View {
    static let titleBarHeight: CGFloat = 38
    static let leadingPadding: CGFloat = 76
    static let trailingTabScrollPadding: CGFloat = 12
    static let trailingAccessoryWidth: CGFloat = 48
    static let trailingAccessoryPadding: CGFloat = 3
    static let minimumWindowEdge: CGFloat = {
        // Keep the window large enough for traffic lights, two tabs, and the pin accessory.
        ceil(
            leadingPadding +
            trailingTabScrollPadding +
            trailingAccessoryWidth +
            trailingAccessoryPadding +
            (EditorTabItemView.minimumTabWidth * 2) +
            24
        )
    }()

    @Binding var tabs: [EditorTab]
    let selectedTabID: UUID?
    let onSelectTab: (UUID) -> Void
    let onRenameTab: (UUID, String) -> Void
    @State private var selectedTabFrame: CGRect = .null
    @State private var isWindowPinned = false
    @State private var editingTabID: UUID? = nil

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach($tabs) { $tab in
                        EditorTabItemView(
                            tab: $tab,
                            isSelected: selectedTabID == tab.id,
                            isEditing: Binding(
                                get: { editingTabID == tab.id },
                                set: { isEditing in
                                    if isEditing {
                                        editingTabID = tab.id
                                    } else if editingTabID == tab.id {
                                        editingTabID = nil
                                    }
                                }
                            )
                        ) {
                            if editingTabID != nil && editingTabID != tab.id {
                                NSApp.keyWindow?.makeFirstResponder(nil)
                                editingTabID = nil
                            }
                            onSelectTab(tab.id)
                        } onRename: { newTitle in
                            onRenameTab(tab.id, newTitle)
                        }
                    }
                }
                .padding(.leading, Self.leadingPadding)
                .padding(.trailing, Self.trailingTabScrollPadding)
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PinWindowButton(isWindowPinned: $isWindowPinned)
                .frame(width: Self.trailingAccessoryWidth)
                .padding(.trailing, Self.trailingAccessoryPadding)
                .padding(.top, 4)
        }
        .coordinateSpace(name: TabBarLayout.coordinateSpaceName)
        .contentShape(Rectangle())
        .onTapGesture {
            if editingTabID != nil {
                NSApp.keyWindow?.makeFirstResponder(nil)
                editingTabID = nil
            }
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            let action = UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") ?? "Maximize"
            guard action != "None", let window = NSApp.keyWindow else { return }
            if action == "Maximize" {
                window.zoom(nil)
            } else if action == "Minimize" {
                window.performMiniaturize(nil)
            }
        })
        .onPreferenceChange(SelectedTabFramePreferenceKey.self) { frame in
            selectedTabFrame = frame
        }
        .background {
            ZStack(alignment: .bottom) {
                EditorChrome.tabBarBackground
                TabBarDividerOverlay(selectedTabFrame: selectedTabFrame)
            }
        }
        .background {
            TitleBarTrafficLightAlignmentView(
                titleBarHeight: Self.titleBarHeight,
                isWindowPinned: isWindowPinned
            )
        }
        .frame(height: Self.titleBarHeight)
    }
}

private struct PinWindowButton: View {
    @Binding var isWindowPinned: Bool
    @State private var isHovering = false

    var body: some View {
        Button {
            isWindowPinned.toggle()
        } label: {
            Image(systemName: "pin.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isWindowPinned ? Color.accentColor : Color.secondary)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(isHovering || isWindowPinned ? EditorChrome.hoverFill : .clear)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help(isWindowPinned ? "Disable Always on Top" : "Enable Always on Top")
        .accessibilityLabel(isWindowPinned ? "Disable Always on Top" : "Enable Always on Top")
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct EditorTabItemView: View {
    private static let titleFontSize: CGFloat = 13
    private static let invalidTitleSeparators = CharacterSet(charactersIn: "/:")
    private static let minimumHorizontalPadding: CGFloat = textWidth(for: "untit")
    static let minimumTabWidth: CGFloat = {
        let titleWidth = textWidth(for: "untitleduntitled")
        return ceil(titleWidth + (minimumHorizontalPadding * 2))
    }()

    private static func textWidth(for text: String) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: titleFontSize, weight: .medium)
        ]
        return (text as NSString).size(withAttributes: attributes).width
    }

    @Binding var tab: EditorTab
    let isSelected: Bool
    @Binding var isEditing: Bool
    let action: () -> Void
    let onRename: (String) -> Void

    @State private var isHovering = false
    @State private var draftTitle = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                tabBackground

                HStack(spacing: 6) {
                    if isEditing {
                        TextField("", text: $draftTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: Self.titleFontSize, weight: isSelected ? .medium : .regular))
                            .focused($isFocused)
                            .labelsHidden()
                            .onSubmit {
                                commitTitleEditing()
                            }
                            .onChange(of: isFocused) { _, isFocusedValue in
                                if !isFocusedValue {
                                    commitTitleEditing()
                                }
                            }
                            .onChange(of: isEditing) { _, isEditingValue in
                                if !isEditingValue {
                                    commitTitleEditing()
                                }
                            }
                            .onDisappear {
                                commitTitleEditing()
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
            .contentShape(TabItemHitShape(isSelected: isSelected))
        }
        .buttonStyle(.plain)
        .zIndex(isSelected ? 1 : 0)
        .onAppear {
            draftTitle = tab.title
        }
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
        .onTapGesture(count: 2) {
            draftTitle = tab.title
            isEditing = true
            isFocused = true
        }
    }

    private func commitTitleEditing() {
        let sanitizedTitle = sanitizedTitle(from: draftTitle)
        if !sanitizedTitle.isEmpty {
            DispatchQueue.main.async {
                onRename(sanitizedTitle)
            }
        }

        draftTitle = tab.title
        isEditing = false
    }

    private func sanitizedTitle(from rawTitle: String) -> String {
        let trimmedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return ""
        }

        let components = trimmedTitle.components(separatedBy: Self.invalidTitleSeparators)
        let separatorSafeTitle = components.joined(separator: "-")
        let singleLineTitle = separatorSafeTitle
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        let collapsedWhitespaceTitle = singleLineTitle
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        return collapsedWhitespaceTitle.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
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

private struct TabItemHitShape: Shape {
    let isSelected: Bool

    func path(in rect: CGRect) -> Path {
        if isSelected {
            return ConnectedTabFillShape(topInset: 6, topCornerRadius: 9, bottomJoinRadius: 9)
                .path(in: rect)
        }

        return Rectangle().path(in: rect)
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
        EditorTab(id: UUID(), title: "Untitled 1"),
        EditorTab(id: UUID(), title: "Config.yml"),
        EditorTab(id: UUID(), title: "Readme.md")
    ]
    @Previewable @State var selectedTabID: UUID?

    VStack(spacing: 0) {
        EditorTabStripView(
            tabs: $tabs,
            selectedTabID: selectedTabID,
            onSelectTab: { selectedTabID = $0 },
            onRenameTab: { id, newTitle in
                guard let index = tabs.firstIndex(where: { $0.id == id }) else {
                    return
                }

                tabs[index].title = newTitle
            }
        )
        Spacer()
    }
    .frame(width: 400, height: 200)
    .background(EditorChrome.tabBarBackground)
    .onAppear {
        selectedTabID = tabs.first?.id
    }
}
