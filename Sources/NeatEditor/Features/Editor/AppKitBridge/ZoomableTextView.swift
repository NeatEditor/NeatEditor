import AppKit

final class ZoomableTextView: NSTextView {
    private enum ZoomKeyCode {
        static let equal: UInt16 = 24
        static let minus: UInt16 = 27
    }

    var onIncreaseFontSize: () -> Void = {}
    var onDecreaseFontSize: () -> Void = {}
    var onCompositionEnd: () -> Void = {}
    var onOpenFiles: ([URL]) -> Void = { _ in }

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        prioritizedPasteboardTypes(from: super.readablePasteboardTypes)
    }

    override var acceptableDragTypes: [NSPasteboard.PasteboardType] {
        prioritizedPasteboardTypes(from: super.acceptableDragTypes)
    }

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

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        if type == .fileURL,
           let urls = pboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           !urls.isEmpty {
            onOpenFiles(urls)
            return true
        }

        return super.readSelection(from: pboard, type: type)
    }

    override func preferredPasteboardType(
        from availableTypes: [NSPasteboard.PasteboardType],
        restrictedToTypesFrom allowedTypes: [NSPasteboard.PasteboardType]? = nil
    ) -> NSPasteboard.PasteboardType? {
        let allowedTypes = allowedTypes ?? []
        let canUseFileURL = availableTypes.contains(.fileURL)
            && (allowedTypes.isEmpty || allowedTypes.contains(.fileURL))

        if canUseFileURL {
            return .fileURL
        }

        return super.preferredPasteboardType(
            from: availableTypes,
            restrictedToTypesFrom: allowedTypes.isEmpty ? nil : allowedTypes
        )
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

    private func prioritizedPasteboardTypes(
        from types: [NSPasteboard.PasteboardType]
    ) -> [NSPasteboard.PasteboardType] {
        var prioritizedTypes = [NSPasteboard.PasteboardType.fileURL]
        prioritizedTypes.append(contentsOf: types.filter { $0 != .fileURL })
        return prioritizedTypes
    }
}
