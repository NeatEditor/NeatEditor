import AppKit

final class LineNumberGutterView: NSView {
    enum Metrics {
        static let minimumDigits = 3
        static let leftPadding: CGFloat = 7
        static let rightPadding: CGFloat = 5
        static let fontScale: CGFloat = 0.85
        static let minimumFontSize: CGFloat = 10
    }

    private weak var scrollView: NSScrollView?
    private weak var textView: NSTextView?
    private var lineStartIndices = [0]
    private var cachedLineCount = 1

    override var isFlipped: Bool {
        true
    }

    var requiredWidth: CGFloat {
        let digits = max(Metrics.minimumDigits, String(cachedLineCount).count)
        let sample = String(repeating: "8", count: digits) as NSString
        let width = ceil(sample.size(withAttributes: textAttributes).width)
        return Metrics.leftPadding + width + Metrics.rightPadding
    }

    init(scrollView: NSScrollView, textView: NSTextView) {
        self.scrollView = scrollView
        self.textView = textView
        super.init(frame: .zero)
        wantsLayer = true
        rebuildLineMetrics()
        updateColors()
        registerObservers(scrollView: scrollView, textView: textView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    override func scrollWheel(with event: NSEvent) {
        guard let scrollView else {
            super.scrollWheel(with: event)
            return
        }

        scrollView.scrollWheel(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        dirtyRect.fill()

        guard let scrollView,
              let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        layoutManager.ensureLayout(for: textContainer)

        let visibleRect = scrollView.contentView.bounds
        let string = textView.string as NSString
        let fullLength = string.length

        if fullLength == 0 {
            drawLineNumber(
                1,
                atY: textView.textContainerInset.height,
                lineHeight: editorLineHeight(for: textView)
            )
            return
        }

        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        if glyphRange.length == 0 {
            return
        }

        let firstGlyphIndex = glyphRange.location
        let firstCharacterIndex = layoutManager.characterIndexForGlyph(at: firstGlyphIndex)
        var lineStartIndex = string.lineRange(for: NSRange(location: firstCharacterIndex, length: 0)).location
        var lineNumber = lineNumber(atCharacterIndex: lineStartIndex, string: string)

        while lineStartIndex < fullLength {
            let lineRange = string.lineRange(for: NSRange(location: lineStartIndex, length: 0))
            let lineGlyphRange = layoutManager.glyphRange(
                forCharacterRange: lineRange,
                actualCharacterRange: nil
            )

            if lineGlyphRange.length > 0 {
                var lineRect = layoutManager.lineFragmentRect(
                    forGlyphAt: lineGlyphRange.location,
                    effectiveRange: nil,
                    withoutAdditionalLayout: true
                )
                lineRect.origin.y += textView.textContainerInset.height

                let y = lineRect.minY - visibleRect.minY
                if y > bounds.maxY {
                    break
                }

                if lineRect.maxY >= visibleRect.minY {
                    drawLineNumber(lineNumber, atY: y, lineHeight: lineRect.height)
                }
            }

            lineStartIndex = NSMaxRange(lineRange)
            lineNumber += 1
        }

        if textView.string.hasSuffix("\n") {
            let extraRect = layoutManager.extraLineFragmentRect
            if !extraRect.isEmpty {
                let y = extraRect.minY + textView.textContainerInset.height - visibleRect.minY
                drawLineNumber(cachedLineCount, atY: y, lineHeight: extraRect.height)
            }
        }
    }

    @objc
    private func handleTextDidChange() {
        rebuildLineMetrics()
        needsDisplay = true
        superview.flatMap { $0 as? EditorTextContainerView }?.refreshLineNumbers()
    }

    @objc
    private func handleScrollBoundsDidChange() {
        needsDisplay = true
    }

    func updateColors() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        needsDisplay = true
    }

    static var separatorColor: NSColor {
        NSColor.separatorColor.withAlphaComponent(0.35)
    }

    private func registerObservers(scrollView: NSScrollView, textView: NSTextView) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextDidChange),
            name: NSText.didChangeNotification,
            object: textView
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScrollBoundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    private func rebuildLineMetrics() {
        guard let textView else {
            lineStartIndices = [0]
            cachedLineCount = 1
            return
        }

        let string = textView.string as NSString
        guard string.length > 0 else {
            lineStartIndices = [0]
            cachedLineCount = 1
            return
        }

        var updatedLineStartIndices = [0]
        var searchRange = NSRange(location: 0, length: string.length)

        while searchRange.length > 0 {
            let matchRange = string.range(of: "\n", options: [], range: searchRange)
            guard matchRange.location != NSNotFound else {
                break
            }

            let nextLineStartIndex = matchRange.location + matchRange.length
            updatedLineStartIndices.append(nextLineStartIndex)
            searchRange = NSRange(
                location: nextLineStartIndex,
                length: string.length - nextLineStartIndex
            )
        }

        lineStartIndices = updatedLineStartIndices
        cachedLineCount = max(1, updatedLineStartIndices.count)
    }

    private var textAttributes: [NSAttributedString.Key: Any] {
        guard let textView else {
            return [:]
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right

        return [
            .font: font(for: textView),
            .foregroundColor: Self.gutterColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    private static var gutterColor: NSColor {
        NSColor.quaternaryLabelColor.blended(
            withFraction: 0.5,
            of: NSColor.tertiaryLabelColor.withAlphaComponent(0.75)
        ) ?? NSColor.tertiaryLabelColor.withAlphaComponent(0.6)
    }

    private func font(for textView: NSTextView) -> NSFont {
        let pointSize = textView.font?.pointSize ?? NSFont.systemFontSize
        let gutterPointSize = max(Metrics.minimumFontSize, pointSize * Metrics.fontScale)
        return .monospacedDigitSystemFont(ofSize: gutterPointSize, weight: .regular)
    }

    private func drawLineNumber(_ lineNumber: Int, atY y: CGFloat, lineHeight: CGFloat) {
        let label = String(lineNumber) as NSString
        let labelSize = label.size(withAttributes: textAttributes)
        let rect = NSRect(
            x: Metrics.leftPadding,
            y: y + max(0, (lineHeight - labelSize.height) / 2),
            width: bounds.width - Metrics.leftPadding - Metrics.rightPadding,
            height: labelSize.height
        )
        label.draw(in: rect, withAttributes: textAttributes)
    }

    private func editorLineHeight(for textView: NSTextView) -> CGFloat {
        let font = textView.font
            ?? .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        return textView.layoutManager?.defaultLineHeight(for: font)
            ?? font.ascender - font.descender + font.leading
    }

    private func lineNumber(atCharacterIndex characterIndex: Int, string: NSString) -> Int {
        guard characterIndex > 0 else {
            return 1
        }

        let safeCharacterIndex = min(characterIndex, string.length)
        var low = 0
        var high = lineStartIndices.count

        while low < high {
            let mid = (low + high) / 2
            if lineStartIndices[mid] <= safeCharacterIndex {
                low = mid + 1
            } else {
                high = mid
            }
        }

        return max(1, low)
    }
}
