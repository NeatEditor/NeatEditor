import AppKit
import SwiftUI

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
    let tabCount: Int
    @Binding var isEditing: Bool
    let action: () -> Void
    let onRename: (String) -> Void
    let onClose: () -> Void
    let onDelete: (() -> Void)?
    let onCloseOthers: () -> Void

    @State private var isHovering = false
    @State private var draftTitle = ""
    @State private var lastSelectedClickTime: Date = .distantPast
    @State private var suppressActionAfterDrag = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button {
            guard !suppressActionAfterDrag else {
                return
            }
            handleClick()
        } label: {
            ZStack(alignment: .bottom) {
                tabBackground

                HStack(spacing: 6) {
                    if isEditing {
                        TextField("", text: $draftTitle)
                            .textFieldStyle(.plain)
                            .focusEffectDisabled()
                            .font(
                                .system(
                                    size: Self.titleFontSize,
                                    weight: isSelected ? .medium : .regular)
                            )
                            .focused($isFocused)
                            .labelsHidden()
                            .onAppear {
                                requestTitleFieldFocus()
                            }
                            .onSubmit {
                                commitTitleEditing()
                            }
                            .frame(minWidth: 40)
                    } else {
                        Text(tab.title)
                            .font(
                                .system(
                                    size: Self.titleFontSize,
                                    weight: isSelected ? .medium : .regular)
                            )
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
        .focusEffectDisabled()
        .modifier(
            TitleBarControlDragSuppression(isSuppressingAction: $suppressActionAfterDrag)
        )
        .zIndex(isSelected ? 1 : 0)
        .onAppear {
            draftTitle = tab.title
        }
        .background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .named(TabBarLayout.coordinateSpaceName))
                Color.clear
                    .preference(
                        key: SelectedTabFramePreferenceKey.self,
                        value: isSelected ? frame : .null
                    )
                    .preference(
                        key: TabFramesPreferenceKey.self,
                        value: [tab.id: frame]
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
        .contextMenu {
            if let fileURL = tab.fileURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                Divider()
            }

            Button {
                onClose()
            } label: {
                Label("Close Tab", systemImage: "xmark")
            }

            if tabCount > 1 {
                Divider()
                Button {
                    onCloseOthers()
                } label: {
                    Label("Close Other Tabs", systemImage: "xmark.rectangle.portrait")
                }
            }

            if let onDelete, tab.fileURL != nil {
                Divider()
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
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
                beginTitleEditing()
                return
            }
            lastSelectedClickTime = now
        } else {
            lastSelectedClickTime = .distantPast
        }

        action()
    }

    private func beginTitleEditing() {
        draftTitle = tab.title
        tabStripPendingRename = sanitizedTitle(from: tab.title)
        // Clear the editor responder first so the insertion caret does not
        // remain in the document while the rename field is taking focus.
        NSApp.keyWindow?.makeFirstResponder(nil)
        isEditing = true
        requestTitleFieldFocus()
        lastSelectedClickTime = .distantPast
    }

    private func requestTitleFieldFocus() {
        DispatchQueue.main.async {
            guard isEditing else {
                return
            }

            isFocused = true
        }
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
        let singleLineTitle =
            separatorSafeTitle
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        let collapsedWhitespaceTitle =
            singleLineTitle
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        return collapsedWhitespaceTitle.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
    }

    @ViewBuilder
    private var tabBackground: some View {
        if isSelected {
            ConnectedTabFillShape(topInset: 6, topCornerRadius: 9, bottomJoinRadius: 9)
                .fill(TabJoinDiagnostics.fillColor)
                .overlay {
                    ConnectedTabBorderShape(topInset: 6, topCornerRadius: 9, bottomJoinRadius: 9)
                        .stroke(
                            TabJoinDiagnostics.borderColor,
                            style: StrokeStyle(
                                lineWidth: EditorChrome.lineWidth,
                                lineCap: .butt,
                                lineJoin: .round
                            )
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
