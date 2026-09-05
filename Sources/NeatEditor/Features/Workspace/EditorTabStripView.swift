import AppKit
import SwiftUI

/// Set by tab button actions to prevent the title bar event monitor
/// from also triggering window zoom on the same double-click.
nonisolated(unsafe) var tabStripSuppressNextZoom = false

/// Written by EditorTabItemView before editing ends, read by
/// EditorTabStripView's dismiss callback to call onRenameTab.
nonisolated(unsafe) var tabStripPendingRename: String?

struct EditorTabStripView: View {
    static let titleBarHeight: CGFloat = 38
    static let leadingPadding: CGFloat = 76
    static let trailingTabScrollPadding: CGFloat = 12
    static let trailingAccessoryWidth: CGFloat = 48
    static let trailingAccessoryPadding: CGFloat = 4
    static let overflowFadeWidth: CGFloat = 16
    static let overflowVisibilityThreshold: CGFloat = 1
    static let minimumWindowEdge: CGFloat = {
        // Keep the window large enough for traffic lights, two tabs, and the pin accessory.
        ceil(
            leadingPadding + trailingTabScrollPadding + trailingAccessoryWidth
                + trailingAccessoryPadding + (EditorTabItemView.minimumTabWidth * 2) + 24
        )
    }()

    @Binding var tabs: [EditorTab]
    let selectedTabID: UUID?
    let onSelectTab: (UUID) -> Void
    let onSelectTabRelative: (Int) -> Void
    let onRenameTab: (UUID, String) -> Void
    let onCloseTab: (UUID) -> Void
    let onDeleteTab: (UUID) -> Void
    let onCloseOtherTabs: (UUID) -> Void
    @State private var selectedTabFrame: CGRect = .null
    @State private var tabFrames: [UUID: CGRect] = [:]
    @State private var tabScrollViewportFrame: CGRect = .null
    @State private var isWindowPinned = false
    @State private var editingTabID: UUID? = nil

    var body: some View {
        HStack(spacing: 0) {
            TitleBarAccessoryBackground()
                .frame(width: Self.leadingPadding)
                .allowsHitTesting(false)

            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach($tabs) { $tab in
                            EditorTabItemView(
                                tab: $tab,
                                isSelected: selectedTabID == tab.id,
                                tabCount: tabs.count,
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
                            } onClose: {
                                onCloseTab(tab.id)
                            } onDelete: {
                                onDeleteTab(tab.id)
                            } onCloseOthers: {
                                onCloseOtherTabs(tab.id)
                            }
                            .id(tab.id)
                        }
                    }
                    .padding(.trailing, Self.trailingTabScrollPadding)
                    .padding(.top, 6)
                }
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: TabScrollViewportFramePreferenceKey.self,
                            value: proxy.frame(in: .named(TabBarLayout.coordinateSpaceName))
                        )
                    }
                }
                .overlay(alignment: .leading) {
                    if showsLeadingOverflowFade {
                        TabStripOverflowFade(edge: .leading)
                    }
                }
                .overlay(alignment: .trailing) {
                    if showsTrailingOverflowFade {
                        TabStripOverflowFade(edge: .trailing)
                    }
                }
                .overlay {
                    TabStripScrollInterceptor(
                        isEditing: editingTabID != nil,
                        onSelectTabRelative: onSelectTabRelative
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: selectedTabID) { _, _ in
                    scrollSelectedTabIntoView(using: scrollProxy)
                }
                .onChange(of: tabFrames) { _, _ in
                    scrollSelectedTabIntoView(using: scrollProxy)
                }
                .onChange(of: tabScrollViewportFrame) { _, _ in
                    scrollSelectedTabIntoView(using: scrollProxy)
                }
                .onAppear {
                    scrollSelectedTabIntoView(using: scrollProxy)
                }
            }

            TitleBarAccessoryBackground()
                .overlay(alignment: .topTrailing) {
                    PinWindowButton(isWindowPinned: $isWindowPinned)
                        .frame(width: Self.trailingAccessoryWidth)
                        .padding(.trailing, Self.trailingAccessoryPadding)
                        .padding(.top, 4)
                }
                .frame(width: Self.trailingAccessoryWidth + Self.trailingAccessoryPadding)
        }
        .coordinateSpace(name: TabBarLayout.coordinateSpaceName)
        .onPreferenceChange(SelectedTabFramePreferenceKey.self) { frame in
            Task { @MainActor in
                selectedTabFrame = frame
            }
        }
        .onPreferenceChange(TabFramesPreferenceKey.self) { frames in
            Task { @MainActor in
                tabFrames = frames
            }
        }
        .onPreferenceChange(TabScrollViewportFramePreferenceKey.self) { frame in
            Task { @MainActor in
                tabScrollViewportFrame = frame
            }
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
                tabFrames: tabFrames,
                onDismissEditing: { dismissEditing() },
                onCloseTab: onCloseTab
            )
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
        ) { _ in
            dismissEditing()
        }
        .frame(height: Self.titleBarHeight)
    }

    private var showsLeadingOverflowFade: Bool {
        guard !tabScrollViewportFrame.isNull else {
            return false
        }

        return tabFrames.values.contains { frame in
            !frame.isNull
                && frame.minX < (
                    tabScrollViewportFrame.minX - Self.overflowVisibilityThreshold)
        }
    }

    private var showsTrailingOverflowFade: Bool {
        guard !tabScrollViewportFrame.isNull else {
            return false
        }

        return tabFrames.values.contains { frame in
            !frame.isNull
                && frame.maxX > (
                    tabScrollViewportFrame.maxX + Self.overflowVisibilityThreshold)
        }
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

    private func scrollSelectedTabIntoView(using scrollProxy: ScrollViewProxy) {
        guard let selectedTabID,
            let selectedFrame = tabFrames[selectedTabID],
            !tabScrollViewportFrame.isNull
        else {
            return
        }

        let isLeadingClipped = selectedFrame.minX < tabScrollViewportFrame.minX
        let isTrailingClipped = selectedFrame.maxX > tabScrollViewportFrame.maxX
        guard isLeadingClipped || isTrailingClipped else {
            return
        }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.14)) {
                scrollProxy.scrollTo(selectedTabID, anchor: .center)
            }
        }
    }
}

private struct TitleBarAccessoryBackground: View {
    var body: some View {
        EditorChrome.tabBarBackground
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(TabJoinDiagnostics.dividerColor)
                    .frame(height: EditorChrome.lineWidth)
            }
            .allowsHitTesting(false)
    }
}

private struct TabStripOverflowFade: View {
    enum Edge {
        case leading
        case trailing
    }

    let edge: Edge

    var body: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: edge == .leading ? .leading : .trailing,
            endPoint: edge == .leading ? .trailing : .leading
        )
        .frame(width: EditorTabStripView.overflowFadeWidth)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var gradientColors: [Color] {
        [
            EditorChrome.tabBarBackground,
            EditorChrome.tabBarBackground.opacity(0)
        ]
    }
}

struct TitleBarControlDragSuppression: ViewModifier {
    private static let activationDistance: CGFloat = 4

    @Binding var isSuppressingAction: Bool

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    guard !isSuppressingAction else {
                        return
                    }

                    let translation = value.translation
                    let distance = max(abs(translation.width), abs(translation.height))
                    if distance >= Self.activationDistance {
                        isSuppressingAction = true
                    }
                }
                .onEnded { _ in
                    DispatchQueue.main.async {
                        isSuppressingAction = false
                    }
                }
        )
    }
}

private struct TabStripScrollInterceptor: NSViewRepresentable {
    let isEditing: Bool
    let onSelectTabRelative: (Int) -> Void

    func makeNSView(context: Context) -> TabStripScrollInterceptorView {
        let view = TabStripScrollInterceptorView()
        view.isEditing = isEditing
        view.onSelectTabRelative = onSelectTabRelative
        return view
    }

    func updateNSView(_ nsView: TabStripScrollInterceptorView, context: Context) {
        nsView.isEditing = isEditing
        nsView.onSelectTabRelative = onSelectTabRelative
    }

    final class TabStripScrollInterceptorView: NSView {
        private enum ScrollTabSwitching {
            static let resetInterval: TimeInterval = 0.35
            static let threshold: CGFloat = 1
            static let mouseWheelSensitivity: CGFloat = 0.005
            static let trackpadSensitivity: CGFloat = 1 / 36
        }

        var isEditing = false
        var onSelectTabRelative: ((Int) -> Void)?
        private var accumulatedScrollDelta: CGFloat = 0
        private var lastScrollTimestamp: TimeInterval = 0

        override var isFlipped: Bool {
            true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard bounds.contains(point),
                let currentEvent = NSApp.currentEvent
            else {
                return nil
            }

            switch currentEvent.type {
            case .scrollWheel, .swipe:
                return self
            default:
                return nil
            }
        }

        override func scrollWheel(with event: NSEvent) {
            guard !isEditing else {
                super.scrollWheel(with: event)
                return
            }

            if !event.momentumPhase.isEmpty {
                resetAccumulatedScrollDelta()
                return
            }

            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                resetAccumulatedScrollDelta()
                return
            }

            let horizontalDelta = event.hasPreciseScrollingDeltas
                ? event.scrollingDeltaX
                : event.deltaX
            let verticalDelta = event.hasPreciseScrollingDeltas
                ? event.scrollingDeltaY
                : event.deltaY
            let dominantDelta = abs(verticalDelta) >= abs(horizontalDelta) ? verticalDelta : horizontalDelta
            guard dominantDelta != 0 else {
                return
            }

            let usesTrackpadSensitivity =
                !event.phase.isEmpty
                || !event.momentumPhase.isEmpty
            accumulateTabSelectionDelta(
                dominantDelta,
                timestamp: event.timestamp,
                sensitivity: usesTrackpadSensitivity
                    ? ScrollTabSwitching.trackpadSensitivity
                    : ScrollTabSwitching.mouseWheelSensitivity
            )
        }

        override func swipe(with event: NSEvent) {
            guard !isEditing else {
                super.swipe(with: event)
                return
            }

            let dominantDelta = abs(event.deltaY) >= abs(event.deltaX) ? event.deltaY : event.deltaX
            guard dominantDelta != 0 else {
                return
            }

            resetAccumulatedScrollDelta()
            let stepDelta: CGFloat = dominantDelta > 0 ? 1 : -1
            accumulateTabSelectionDelta(stepDelta, timestamp: event.timestamp, sensitivity: 1)
        }

        private func accumulateTabSelectionDelta(
            _ delta: CGFloat,
            timestamp: TimeInterval,
            sensitivity: CGFloat
        ) {
            if (timestamp - lastScrollTimestamp) > ScrollTabSwitching.resetInterval {
                accumulatedScrollDelta = 0
            }

            let scaledDelta = delta * sensitivity
            if accumulatedScrollDelta != 0,
                scaledDelta.sign != accumulatedScrollDelta.sign
            {
                accumulatedScrollDelta = 0
            }

            accumulatedScrollDelta += scaledDelta
            lastScrollTimestamp = timestamp

            while abs(accumulatedScrollDelta) >= ScrollTabSwitching.threshold {
                let relativeOffset = accumulatedScrollDelta > 0 ? -1 : 1
                onSelectTabRelative?(relativeOffset)
                accumulatedScrollDelta += accumulatedScrollDelta > 0 ? -1 : 1
            }
        }

        private func resetAccumulatedScrollDelta() {
            accumulatedScrollDelta = 0
            lastScrollTimestamp = 0
        }
    }
}

private struct PinWindowButton: View {
    @Binding var isWindowPinned: Bool
    @State private var isHovering = false
    @State private var suppressActionAfterDrag = false

    var body: some View {
        Button {
            guard !suppressActionAfterDrag else {
                return
            }
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
        .focusEffectDisabled()
        .contentShape(Circle())
        .help(isWindowPinned ? "Disable Always on Top" : "Enable Always on Top")
        .accessibilityLabel(isWindowPinned ? "Disable Always on Top" : "Enable Always on Top")
        .modifier(
            TitleBarControlDragSuppression(isSuppressingAction: $suppressActionAfterDrag)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct TitleBarEventMonitor: NSViewRepresentable {
    let isEditing: Bool
    let tabFrames: [UUID: CGRect]
    let onDismissEditing: () -> Void
    let onCloseTab: (UUID) -> Void

    func makeNSView(context: Context) -> TitleBarEventNSView {
        let view = TitleBarEventNSView()
        view.isEditing = isEditing
        view.tabFrames = tabFrames
        view.onDismissEditing = onDismissEditing
        view.onCloseTab = onCloseTab
        return view
    }

    func updateNSView(_ nsView: TitleBarEventNSView, context: Context) {
        nsView.isEditing = isEditing
        nsView.tabFrames = tabFrames
        nsView.onDismissEditing = onDismissEditing
        nsView.onCloseTab = onCloseTab
    }

    final class TitleBarEventNSView: NSView {
        var isEditing = false
        var tabFrames: [UUID: CGRect] = [:]
        var onDismissEditing: (() -> Void)?
        var onCloseTab: ((UUID) -> Void)?
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
            clickMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .leftMouseUp, .otherMouseUp]
            ) { [weak self] event in
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
                if isEditing && !isEventInTitleBarRegion(event) {
                    DispatchQueue.main.async { [weak self] in
                        self?.onDismissEditing?()
                    }
                }
            } else if event.type == .leftMouseUp {
                // Title bar double-click zoom on mouseUp so the SwiftUI Button
                // action (also mouseUp) has already set the suppress flag.
                guard event.clickCount >= 2,
                    event.window === self.window,
                    isEventInTitleBarRegion(event)
                else { return }

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
            } else if event.type == .otherMouseUp, event.buttonNumber == 2 {
                guard let tabID = tabID(at: event) else {
                    return
                }

                DispatchQueue.main.async { [weak self] in
                    if self?.isEditing == true {
                        self?.onDismissEditing?()
                    }
                    self?.onCloseTab?(tabID)
                }
            }
        }

        private func tabID(at event: NSEvent) -> UUID? {
            guard event.window === self.window else {
                return nil
            }

            let location = convert(event.locationInWindow, from: nil)
            return tabFrames.first { _, frame in
                frame.contains(location)
            }?.key
        }

        /// Check if the click is within the title bar / tab strip region
        /// (the top portion of the window).
        private func isEventInTitleBarRegion(_ event: NSEvent) -> Bool {
            guard let window = event.window else { return false }
            // With .hiddenTitleBar, the content fills the entire window.
            // The tab strip occupies the top titleBarHeight points.
            let titleBarHeight = EditorTabStripView.titleBarHeight
            let windowHeight = window.frame.height
            return event.locationInWindow.y >= (windowHeight - titleBarHeight)
        }

        private func performTitleBarDoubleClickAction() {
            let action =
                UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") ?? "Maximize"
            guard action != "None", let window = self.window else { return }
            if action == "Maximize" {
                window.zoom(nil)
            } else if action == "Minimize" {
                window.performMiniaturize(nil)
            }
        }
    }
}

enum TabJoinDiagnostics {
    static let isEnabled = false

    static var fillColor: Color {
        isEnabled ? .green.opacity(0.35) : EditorChrome.editorSurface
    }

    static var borderColor: Color {
        isEnabled ? .blue : EditorChrome.border
    }

    static var dividerColor: Color {
        isEnabled ? .red : EditorChrome.border
    }
}

private struct TabBarDividerOverlay: View {
    private static let leadingSelectedTabJoinClearance: CGFloat = 3.0
    private static let trailingSelectedTabJoinClearance: CGFloat = 3.0

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

                let leftEnd = max(
                    0,
                    min(
                        selectedTabFrame.minX - Self.leadingSelectedTabJoinClearance,
                        proxy.size.width)
                )
                let rightStart = max(
                    0,
                    min(
                        selectedTabFrame.maxX + Self.trailingSelectedTabJoinClearance,
                        proxy.size.width)
                )

                if leftEnd > 0 {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: leftEnd, y: y))
                }

                if rightStart < proxy.size.width {
                    path.move(to: CGPoint(x: rightStart, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
            }
            .stroke(TabJoinDiagnostics.dividerColor, lineWidth: EditorChrome.lineWidth)
        }
        .allowsHitTesting(false)
    }
}

struct ConnectedTabFillShape: Shape {
    private static let bottomLift: CGFloat = 0.5

    let topInset: CGFloat
    let topCornerRadius: CGFloat
    let bottomJoinRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset = min(topInset, rect.width / 4)
        let topRadius = min(topCornerRadius, rect.width / 2, rect.height / 2)
        let bottomRadius = min(bottomJoinRadius, rect.width / 2, rect.height / 2)
        let bottomY = rect.maxY - Self.bottomLift
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: bottomY))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX + inset, y: bottomY),
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
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: bottomY - bottomRadius))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX - inset, y: bottomY),
            tangent2End: CGPoint(x: rect.maxX, y: bottomY),
            radius: bottomRadius
        )
        path.addLine(to: CGPoint(x: rect.minX, y: bottomY))

        return path
    }
}

struct ConnectedTabBorderShape: Shape {
    private static let bottomLift: CGFloat = 0.5

    let topInset: CGFloat
    let topCornerRadius: CGFloat
    let bottomJoinRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset = min(topInset, rect.width / 4)
        let topRadius = min(topCornerRadius, rect.width / 2, rect.height / 2)
        let bottomRadius = min(bottomJoinRadius, rect.width / 2, rect.height / 2)
        let bottomY = rect.maxY - Self.bottomLift
        let leftTopStartX = rect.minX + inset + topRadius
        let rightTopStartX = rect.maxX - inset - topRadius
        let centerX = rect.midX
        var path = Path()

        path.move(to: CGPoint(x: centerX, y: rect.minY))
        path.addLine(to: CGPoint(x: leftTopStartX, y: rect.minY))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX + inset, y: rect.minY),
            tangent2End: CGPoint(x: rect.minX + inset, y: rect.minY + topRadius),
            radius: topRadius
        )
        path.addLine(to: CGPoint(x: rect.minX + inset, y: bottomY - bottomRadius))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX + inset, y: bottomY),
            tangent2End: CGPoint(x: rect.minX, y: bottomY),
            radius: bottomRadius
        )

        path.move(to: CGPoint(x: centerX, y: rect.minY))
        path.addLine(to: CGPoint(x: rightTopStartX, y: rect.minY))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX - inset, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX - inset, y: rect.minY + topRadius),
            radius: topRadius
        )
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: bottomY - bottomRadius))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX - inset, y: bottomY),
            tangent2End: CGPoint(x: rect.maxX, y: bottomY),
            radius: bottomRadius
        )

        return path
    }
}

#Preview {
    @Previewable @State var tabs = [
        EditorTab(id: UUID(), title: "Untitled 1"),
        EditorTab(id: UUID(), title: "Config.yml"),
        EditorTab(id: UUID(), title: "Readme.md"),
    ]
    @Previewable @State var selectedTabID: UUID?

    VStack(spacing: 0) {
        EditorTabStripView(
            tabs: $tabs,
            selectedTabID: selectedTabID,
            onSelectTab: { selectedTabID = $0 },
            onSelectTabRelative: { offset in
                guard let currentSelectedTabID = selectedTabID,
                    let selectedIndex = tabs.firstIndex(where: { $0.id == currentSelectedTabID })
                else {
                    return
                }

                let targetIndex = selectedIndex + offset
                guard tabs.indices.contains(targetIndex) else {
                    return
                }

                selectedTabID = tabs[targetIndex].id
            },
            onRenameTab: { id, newTitle in
                guard let index = tabs.firstIndex(where: { $0.id == id }) else {
                    return
                }

                tabs[index].title = newTitle
            },
            onCloseTab: { id in
                tabs.removeAll { $0.id == id }
                if selectedTabID == id {
                    selectedTabID = tabs.first?.id
                }
            },
            onDeleteTab: { _ in },
            onCloseOtherTabs: { _ in }
        )
        Spacer()
    }
    .frame(width: 400, height: 200)
    .background(EditorChrome.tabBarBackground)
    .onAppear {
        selectedTabID = tabs.first?.id
    }
}
