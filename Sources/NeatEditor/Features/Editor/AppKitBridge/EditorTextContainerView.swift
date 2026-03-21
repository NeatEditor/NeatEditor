import AppKit

final class EditorTextContainerView: NSView {
    let textView: ZoomableTextView

    private static let editorLineHeightMultiple: CGFloat = 1.08
    private static let searchHighlightColor = NSColor.controlAccentColor.withAlphaComponent(0.22)
    private var currentEditorFontSize: CGFloat = NSFont.systemFontSize

    var onIncreaseFontSize: () -> Void {
        didSet {
            scrollView.onIncreaseFontSize = onIncreaseFontSize
            textView.onIncreaseFontSize = onIncreaseFontSize
        }
    }

    var onDecreaseFontSize: () -> Void {
        didSet {
            scrollView.onDecreaseFontSize = onDecreaseFontSize
            textView.onDecreaseFontSize = onDecreaseFontSize
        }
    }

    private let scrollView: ZoomableScrollView
    private let lineNumberView: LineNumberGutterView
    private let separatorView = NSView()
    private var gutterWidthConstraint: NSLayoutConstraint?

    override var isFlipped: Bool {
        true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateTextViewColors()
        applyDefaultTypingAttributes(using: editorMonospacedFont())
        updateSeparatorColor()
        lineNumberView.updateColors()
    }

    init(
        onIncreaseFontSize: @escaping () -> Void = {},
        onDecreaseFontSize: @escaping () -> Void = {}
    ) {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        )

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        let textView = ZoomableTextView(frame: .zero, textContainer: textContainer)
        let scrollView = ZoomableScrollView(frame: .zero)
        let contentView = NSClipView()

        contentView.drawsBackground = false
        scrollView.contentView = contentView
        scrollView.documentView = textView
        self.scrollView = scrollView
        self.textView = textView
        self.lineNumberView = LineNumberGutterView(scrollView: scrollView, textView: textView)
        self.onIncreaseFontSize = onIncreaseFontSize
        self.onDecreaseFontSize = onDecreaseFontSize

        super.init(frame: .zero)
        self.focusRingType = .none

        configureTextView()
        configureScrollView()
        configureLayout()
        self.scrollView.onIncreaseFontSize = onIncreaseFontSize
        self.scrollView.onDecreaseFontSize = onDecreaseFontSize
        self.textView.onIncreaseFontSize = onIncreaseFontSize
        self.textView.onDecreaseFontSize = onDecreaseFontSize
        refreshLineNumbers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refreshLineNumbers() {
        let gutterWidth = lineNumberView.requiredWidth
        gutterWidthConstraint?.constant = gutterWidth
        lineNumberView.needsDisplay = true
    }

    func synchronizeLineNumbersToCurrentText() {
        lineNumberView.synchronizeLineMetrics()
        refreshLineNumbers()
    }

    func applyFontSize(_ fontSize: CGFloat) {
        currentEditorFontSize = fontSize
        let font = editorMonospacedFont()
        let didChangeFont = textView.font?.fontName != font.fontName
            || textView.font?.pointSize != font.pointSize

        if didChangeFont {
            textView.font = font
            refreshLineNumbers()
        }

        applyDefaultTypingAttributes(using: font)
    }

    func applyEditorTextAttributes() {
        textView.font = editorMonospacedFont()
        updateTextViewColors()
        applyDefaultTypingAttributes(using: editorMonospacedFont())
        refreshLineNumbers()
    }

    func enforceEditorTextAttributesIfNeeded() {
        let font = editorMonospacedFont()
        updateTextViewColors()
        applyDefaultTypingAttributes(using: font)
    }

    func prepareTypingAttributes(for replacementString: String?) {
        _ = replacementString
        applyDefaultTypingAttributes(using: editorMonospacedFont())
    }

    func performSearch(for query: String, usesRegularExpression: Bool) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            clearSearchHighlights()
            return
        }

        let fullText = textView.string
        guard !fullText.isEmpty else {
            clearSearchHighlights()
            NSSound.beep()
            return
        }

        let matchRanges = if usesRegularExpression {
            regularExpressionSearchRanges(for: trimmedQuery, in: fullText)
        } else {
            literalSearchRanges(for: trimmedQuery, in: fullText)
        }

        guard !matchRanges.isEmpty else {
            clearSearchHighlights()
            NSSound.beep()
            return
        }

        applySearchHighlights(for: matchRanges)

        let selectedRange = textView.selectedRange()
        let selectionEnd = selectedRange.location == NSNotFound
            ? 0
            : min(NSMaxRange(selectedRange), fullText.utf16.count)

        let matchRange = nextMatchRange(from: matchRanges, selectionEnd: selectionEnd)

        textView.window?.makeFirstResponder(textView)
        textView.setSelectedRange(matchRange)
        textView.scrollRangeToVisible(matchRange)
    }

    private func literalSearchRanges(
        for query: String,
        in fullText: String
    ) -> [NSRange] {
        let nsText = fullText as NSString
        let searchOptions: NSString.CompareOptions = [.caseInsensitive]
        var searchRange = NSRange(location: 0, length: nsText.length)
        var matchRanges: [NSRange] = []

        while searchRange.length > 0 {
            let matchRange = nsText.range(
                of: query,
                options: searchOptions,
                range: searchRange
            )

            guard matchRange.location != NSNotFound else {
                break
            }

            matchRanges.append(matchRange)

            let nextLocation = NSMaxRange(matchRange)
            guard nextLocation < nsText.length else {
                break
            }

            searchRange = NSRange(
                location: nextLocation,
                length: nsText.length - nextLocation
            )
        }

        return matchRanges
    }

    private func regularExpressionSearchRanges(
        for pattern: String,
        in fullText: String
    ) -> [NSRange] {
        do {
            let regex = try Regex(pattern).ignoresCase()
            return fullText.matches(of: regex).compactMap { NSRange($0.range, in: fullText) }
        } catch {
            return []
        }
    }

    private func nextMatchRange(from matchRanges: [NSRange], selectionEnd: Int) -> NSRange {
        if let nextMatch = matchRanges.first(where: { $0.location >= selectionEnd }) {
            return nextMatch
        }

        return matchRanges[0]
    }

    private func applySearchHighlights(for matchRanges: [NSRange]) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: glyphRange)

        for matchRange in matchRanges {
            layoutManager.addTemporaryAttribute(
                .backgroundColor,
                value: Self.searchHighlightColor,
                forCharacterRange: matchRange
            )
        }
    }

    private func clearSearchHighlights() {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: glyphRange)
    }

    private func configureTextView() {
        currentEditorFontSize = NSFont.systemFontSize
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindPanel = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.font = editorMonospacedFont()
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: 0)
        textView.autoresizingMask = [.width]
        textView.focusRingType = .none
        updateTextViewColors()
        applyDefaultTypingAttributes(using: editorMonospacedFont())

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(
                width: 0,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
    }

    private static func editorFont(ofSize size: CGFloat) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    private func editorMonospacedFont() -> NSFont {
        Self.editorFont(ofSize: currentEditorFontSize)
    }

    private func applyDefaultTypingAttributes(using font: NSFont) {
        let paragraphStyle = Self.editorParagraphStyle()
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes[.font] = font
        textView.typingAttributes[.paragraphStyle] = paragraphStyle
        textView.typingAttributes[.foregroundColor] = Self.editorForegroundColor()
    }

    private static func editorParagraphStyle() -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = editorLineHeightMultiple
        return paragraphStyle
    }

    private static func editorForegroundColor() -> NSColor {
        .labelColor
    }

    private func configureScrollView() {
        wantsLayer = true
        layer?.masksToBounds = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollView.focusRingType = .none
    }

    private func configureLayout() {
        lineNumberView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.wantsLayer = true
        updateSeparatorColor()

        addSubview(lineNumberView)
        addSubview(separatorView)
        addSubview(scrollView)

        let gutterWidthConstraint = lineNumberView.widthAnchor.constraint(
            equalToConstant: lineNumberView.requiredWidth
        )
        self.gutterWidthConstraint = gutterWidthConstraint

        NSLayoutConstraint.activate([
            lineNumberView.leadingAnchor.constraint(equalTo: leadingAnchor),
            lineNumberView.topAnchor.constraint(equalTo: topAnchor),
            lineNumberView.bottomAnchor.constraint(equalTo: bottomAnchor),
            gutterWidthConstraint,

            separatorView.leadingAnchor.constraint(equalTo: lineNumberView.trailingAnchor),
            separatorView.topAnchor.constraint(equalTo: topAnchor),
            separatorView.bottomAnchor.constraint(equalTo: bottomAnchor),
            separatorView.widthAnchor.constraint(equalToConstant: 0.5),

            scrollView.leadingAnchor.constraint(equalTo: separatorView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func updateSeparatorColor() {
        separatorView.layer?.backgroundColor = LineNumberGutterView.separatorColor.cgColor
    }

    private func updateTextViewColors() {
        textView.textColor = Self.editorForegroundColor()
        textView.backgroundColor = .controlBackgroundColor
        textView.insertionPointColor = Self.editorForegroundColor()
    }
}
