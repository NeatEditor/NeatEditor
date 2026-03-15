import AppKit

final class ZoomableTextView: NSTextView {
    private enum ZoomKeyCode {
        static let equal: UInt16 = 24
        static let minus: UInt16 = 27
    }

    var onIncreaseFontSize: () -> Void = {}
    var onDecreaseFontSize: () -> Void = {}
    var onCompositionEnd: () -> Void = {}

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleZoomShortcut(for: event) {
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if handleZoomShortcut(for: event) {
            return
        }

        super.keyDown(with: event)
    }

    override func unmarkText() {
        let wasComposing = hasMarkedText()
        super.unmarkText()

        if wasComposing {
            onCompositionEnd()
        }
    }

    private func handleZoomShortcut(for event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let nonShiftModifiers = modifiers.subtracting(.shift)

        guard nonShiftModifiers == .command else {
            return false
        }

        switch event.keyCode {
        case ZoomKeyCode.equal:
            onIncreaseFontSize()
            return true
        case ZoomKeyCode.minus:
            onDecreaseFontSize()
            return true
        default:
            break
        }

        let characters = event.characters ?? ""
        let normalizedCharacters = event.charactersIgnoringModifiers ?? characters

        switch (characters, normalizedCharacters) {
        case ("+", _), ("=", "="):
            onIncreaseFontSize()
            return true
        case ("_", _), ("-", "-"):
            onDecreaseFontSize()
            return true
        default:
            return false
        }
    }
}
