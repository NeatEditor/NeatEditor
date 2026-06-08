import AppKit
import SwiftUI

struct EditorTextView: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let tabBehavior: TabBehavior
    let textSoftness: WorkspacePreferences.EditorTextSoftnessConfiguration
    let searchState: WorkspaceSearchState

    let onTextChange: (_ isComposing: Bool) -> Void
    let onCompositionEnd: () -> Void
    let onIncreaseFontSize: () -> Void
    let onDecreaseFontSize: () -> Void
    let onOpenFiles: ([URL]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> EditorTextContainerView {
        let containerView = EditorTextContainerView(
            onIncreaseFontSize: onIncreaseFontSize,
            onDecreaseFontSize: onDecreaseFontSize
        )
        let textView = containerView.textView

        textView.delegate = context.coordinator
        textView.string = text
        containerView.synchronizeLineNumbersToCurrentText()
        textView.onOpenFiles = onOpenFiles
        textView.tabBehavior = tabBehavior
        containerView.textSoftness = textSoftness
        containerView.applyEditorTextAttributes()
        textView.onCompositionEnd = {
            [weak containerView, weak coordinator = context.coordinator, weak textView] in
            guard let containerView, let coordinator, let textView else {
                return
            }

            coordinator.handleCompositionEnd(in: textView, containerView: containerView)
        }
        containerView.applyFontSize(fontSize)

        return containerView
    }

    func updateNSView(_ containerView: EditorTextContainerView, context: Context) {
        context.coordinator.parent = self
        containerView.onIncreaseFontSize = onIncreaseFontSize
        containerView.onDecreaseFontSize = onDecreaseFontSize
        containerView.textView.onOpenFiles = onOpenFiles
        containerView.textView.tabBehavior = tabBehavior
        containerView.textSoftness = textSoftness

        if !containerView.textView.hasMarkedText() && containerView.textView.string != text {
            context.coordinator.isSyncingFromSwiftUI = true
            containerView.textView.string = text
            context.coordinator.isSyncingFromSwiftUI = false
            containerView.synchronizeLineNumbersToCurrentText()
            containerView.applyEditorTextAttributes()
        }

        containerView.applyFontSize(fontSize)
        // Color/typing-attribute upkeep is driven by textSoftness didSet and
        // viewDidChangeEffectiveAppearance; repeating it on every SwiftUI
        // redraw was the dominant CPU source during long sessions.

        let query = searchState.trimmedQuery
        let isRegex = searchState.isRegexEnabled
        let isPresented = searchState.isPresented
        let coordinator = context.coordinator

        if coordinator.lastSearchWasPresented && !isPresented {
            containerView.clearSearchHighlights()
        }

        coordinator.lastSearchWasPresented = isPresented

        if isPresented {
            let requestChanged = coordinator.lastSearchRequestID != searchState.requestID
            let queryChanged = coordinator.lastAppliedSearchQuery != query
            let regexChanged = coordinator.lastAppliedIsRegex != isRegex

            if requestChanged || queryChanged || regexChanged {
                coordinator.lastSearchRequestID = searchState.requestID
                coordinator.lastAppliedSearchQuery = query
                coordinator.lastAppliedIsRegex = isRegex
                containerView.performSearch(
                    for: query,
                    usesRegularExpression: isRegex,
                    navigate: requestChanged
                )
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorTextView
        var isSyncingFromSwiftUI = false
        var lastSearchRequestID = 0
        var lastAppliedSearchQuery = ""
        var lastAppliedIsRegex = false
        var lastSearchWasPresented = false

        init(parent: EditorTextView) {
            self.parent = parent
        }

        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            guard let containerView = textView.enclosingScrollView?.superview as? EditorTextContainerView else {
                return true
            }

            containerView.prepareTypingAttributes(for: replacementString)
            return true
        }

        func textDidChange(_ notification: Notification) {
            guard !isSyncingFromSwiftUI,
                  let textView = notification.object as? NSTextView,
                  let containerView = textView.enclosingScrollView?.superview as? EditorTextContainerView else {
                return
            }

            let isComposing = textView.hasMarkedText()
            if !isComposing {
                parent.text = textView.string
            }

            parent.onTextChange(isComposing)
            containerView.refreshLineNumbers()
        }

        func handleCompositionEnd(in textView: NSTextView, containerView: EditorTextContainerView) {
            guard !isSyncingFromSwiftUI else {
                return
            }

            parent.text = textView.string
            containerView.applyEditorTextAttributes()
            parent.onCompositionEnd()
        }
    }
}
