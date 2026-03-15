import AppKit
import SwiftUI

/// Set by tab button actions to prevent the title bar event monitor
/// from also triggering window zoom on the same double-click.
private nonisolated(unsafe) var tabStripSuppressNextZoom = false

/// Written by EditorTabItemView before editing ends, read by
/// EditorTabStripView's dismiss callback to call onRenameTab.
private nonisolated(unsafe) var tabStripPendingRename: String?

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
        .background {
            TitleBarEventMonitor(
                isEditing: editingTabID != nil,
                onDismissEditing: { dismissEditing() }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            dismissEditing()
        }
        .frame(height: Self.titleBarHeight)
    }

    private func dismissEditing() {
        guard let tabID = editingTabID else { return }
        // Read the pending rename that EditorTabItemView wrote before we clear editing.
        if let newTitle = tabStripPendingRename {
            tabStripPendingRename = nil
            onRenameTab(tabID, newTitle)
        }
        editingTabID = nil
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
    @State private var lastSelectedClickTime: Date = .distantPast
    @FocusState private var isFocused: Bool

    var body: some View {
        Button {
            handleClick()
        } label: {
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
        .onChange(of: draftTitle) { _, newValue in
            if isEditing {
                tabStripPendingRename = sanitizedTitle(from: newValue)
            }
        }
    }

    private func handleClick() {
        guard !isEditing else { return }

        // Suppress the monitor's zoom for this click event, auto-clearing
        // after the double-click interval so it never leaks into future events
        // but survives long enough to cover a full double-click sequence.
        tabStripSuppressNextZoom = true
        DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval + 0.1) {
            tabStripSuppressNextZoom = false
        }

        if isSelected {
            let now = Date()
            if now.timeIntervalSince(lastSelectedClickTime) < NSEvent.doubleClickInterval {
                draftTitle = tab.title
                tabStripPendingRename = sanitizedTitle(from: tab.title)
                isEditing = true
                isFocused = true
                lastSelectedClickTime = .distantPast
                return
            }
            lastSelectedClickTime = now
        } else {
            lastSelectedClickTime = .distantPast
        }

        action()
    }

    /// Called only from onSubmit (Enter key). For external dismiss (click
    /// outside), the parent reads tabStripPendingRename directly.
    private func commitTitleEditing() {
        lastSelectedClickTime = .distantPast
        tabStripPendingRename = nil

        let sanitizedTitle = sanitizedTitle(from: draftTitle)
        if !sanitizedTitle.isEmpty {
            onRename(sanitizedTitle)
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

private struct TitleBarEventMonitor: NSViewRepresentable {
    let isEditing: Bool
    let onDismissEditing: () -> Void

    func makeNSView(context: Context) -> TitleBarEventNSView {
        let view = TitleBarEventNSView()
        view.isEditing = isEditing
        view.onDismissEditing = onDismissEditing
        return view
    }

    func updateNSView(_ nsView: TitleBarEventNSView, context: Context) {
        nsView.isEditing = isEditing
        nsView.onDismissEditing = onDismissEditing
    }

    final class TitleBarEventNSView: NSView {
        var isEditing = false
        var onDismissEditing: (() -> Void)?
        private var clickMonitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            installMonitor()
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil {
                removeMonitor()
            }
            super.viewWillMove(toWindow: newWindow)
        }

        private func installMonitor() {
            removeMonitor()
            clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
                self?.handleMouseEvent(event)
                return event
            }
        }

        private func removeMonitor() {
            if let clickMonitor {
                NSEvent.removeMonitor(clickMonitor)
                self.clickMonitor = nil
            }
        }

        private func handleMouseEvent(_ event: NSEvent) {
            if event.type == .leftMouseDown {
                // Dismiss editing when clicking outside the title bar area
                // (where the rename text field lives).
                if isEditing && !isClickInTitleBarRegion(event) {
                    DispatchQueue.main.async { [weak self] in
                        self?.onDismissEditing?()
                    }
                }
            } else if event.type == .leftMouseUp {
                // Title bar double-click zoom on mouseUp so the SwiftUI Button
                // action (also mouseUp) has already set the suppress flag.
                guard event.clickCount >= 2,
                      event.window === self.window,
                      isClickInTitleBarRegion(event) else { return }

                // Defer to the next run loop iteration. The Button action fires
                // synchronously during event dispatch, so by the next iteration
                // the suppress flag is guaranteed to be set if a tab was clicked.
                DispatchQueue.main.async { [weak self] in
                    if tabStripSuppressNextZoom {
                        tabStripSuppressNextZoom = false
                        return
                    }
                    self?.performTitleBarDoubleClickAction()
                }
            }
        }

        /// Check if the click is within the title bar / tab strip region
        /// (the top portion of the window).
        private func isClickInTitleBarRegion(_ event: NSEvent) -> Bool {
            guard let window = event.window else { return false }
            // With .hiddenTitleBar, the content fills the entire window.
            // The tab strip occupies the top titleBarHeight points.
            let titleBarHeight = EditorTabStripView.titleBarHeight
            let windowHeight = window.frame.height
            return event.locationInWindow.y >= (windowHeight - titleBarHeight)
        }

        private func performTitleBarDoubleClickAction() {
            let action = UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") ?? "Maximize"
            guard action != "None", let window = self.window else { return }
            if action == "Maximize" {
                window.zoom(nil)
            } else if action == "Minimize" {
                window.performMiniaturize(nil)
            }
        }

        deinit {
            removeMonitor()
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
