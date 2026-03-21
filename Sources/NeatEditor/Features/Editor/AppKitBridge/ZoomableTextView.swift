import AppKit

final class ZoomableTextView: NSTextView {
    private enum EditorKeyCode {
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
    }

    private enum ZoomKeyCode {
        static let equal: UInt16 = 24
        static let minus: UInt16 = 27
    }

    var onIncreaseFontSize: () -> Void = {}
    var onDecreaseFontSize: () -> Void = {}
    var onCompositionEnd: () -> Void = {}
    var onOpenFiles: ([URL]) -> Void = { _ in }
    var tabBehavior: TabBehavior = .spaces2

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

        if handleMoveToNextLineShortcut(for: event) {
            return
        }

        super.keyDown(with: event)
    }

    override func insertTab(_ sender: Any?) {
        insertText(tabBehavior.stringValue, replacementRange: selectedRange())
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

    private func handleMoveToNextLineShortcut(for event: NSEvent) -> Bool {
        guard !hasMarkedText(),
              isMoveToNextLineShortcut(event) else {
            return false
        }

        moveInsertionPointToNextLine()
        return true
    }

    private func isMoveToNextLineShortcut(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let disallowedModifiers = modifiers.subtracting([.shift, .capsLock])

        guard modifiers.contains(.shift),
              disallowedModifiers.isEmpty else {
            return false
        }

        switch event.keyCode {
        case EditorKeyCode.returnKey, EditorKeyCode.keypadEnter:
            return true
        default:
            return false
        }
    }

    private func moveInsertionPointToNextLine() {
        let currentText = string as NSString
        let insertionLocation = min(selectedRange().location, currentText.length)
        let currentLineRange = currentText.lineRange(
            for: NSRange(location: insertionLocation, length: 0)
        )
        // 计算当前行结尾（不含换行符）的位置
        let lineEnd = NSMaxRange(currentLineRange)
        let lineEndWithoutNewline: Int
        if lineEnd > 0 {
            let lastChar = currentText.character(at: lineEnd - 1)
            // 0x0A = LF, 0x0D = CR, 0x2028 = Unicode line separator
            lineEndWithoutNewline = (lastChar == 0x0A || lastChar == 0x0D || lastChar == 0x2028)
                ? lineEnd - 1
                : lineEnd
        } else {
            lineEndWithoutNewline = lineEnd
        }
        // 将光标移到行末（不含换行符），再插入换行
        setSelectedRange(NSRange(location: lineEndWithoutNewline, length: 0))
        insertText("\n", replacementRange: selectedRange())
    }

    private func prioritizedPasteboardTypes(
        from types: [NSPasteboard.PasteboardType]
    ) -> [NSPasteboard.PasteboardType] {
        var prioritizedTypes = [NSPasteboard.PasteboardType.fileURL]
        prioritizedTypes.append(contentsOf: types.filter { $0 != .fileURL })
        return prioritizedTypes
    }
}
