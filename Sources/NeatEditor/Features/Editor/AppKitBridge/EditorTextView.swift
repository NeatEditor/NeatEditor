import AppKit
import SwiftUI

struct EditorTextView: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let searchQuery: String
    let searchRequestID: Int

    let onTextChange: (_ isComposing: Bool) -> Void
    let onCompositionEnd: () -> Void
    let onIncreaseFontSize: () -> Void
    let onDecreaseFontSize: () -> Void

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
        containerView.applyEditorTextAttributes()
        textView.onCompositionEnd = {
            [weak containerView, weak coordinator = context.coordinator, weak textView] in
            guard let containerView, let coordinator, let textView else {
                return
            }

            coordinator.handleCompositionEnd(in: textView, containerView: containerView)
        }
        containerView.applyFontSize(fontSize)
        containerView.refreshLineNumbers()

        return containerView
    }

    func updateNSView(_ containerView: EditorTextContainerView, context: Context) {
        context.coordinator.parent = self
        containerView.onIncreaseFontSize = onIncreaseFontSize
        containerView.onDecreaseFontSize = onDecreaseFontSize

        if !containerView.textView.hasMarkedText() && containerView.textView.string != text {
            context.coordinator.isSyncingFromSwiftUI = true
            containerView.textView.string = text
            context.coordinator.isSyncingFromSwiftUI = false
            containerView.applyEditorTextAttributes()
            containerView.refreshLineNumbers()
        }

        containerView.applyFontSize(fontSize)

        if context.coordinator.lastSearchRequestID != searchRequestID {
            context.coordinator.lastSearchRequestID = searchRequestID
            containerView.performSearch(for: searchQuery)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorTextView
        var isSyncingFromSwiftUI = false
        var lastSearchRequestID = 0

        init(parent: EditorTextView) {
            self.parent = parent
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
            parent.onCompositionEnd()
            containerView.refreshLineNumbers()
        }
    }
}
