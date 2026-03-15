import AppKit

final class EditorTextContainerView: NSView {
    let textView: ZoomableTextView

    private static let editorLineHeightMultiple: CGFloat = 1.08
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
        applyEditorTextAttributes()
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

    func applyFontSize(_ fontSize: CGFloat) {
        currentEditorFontSize = fontSize
        let font = editorMonospacedFont()
        let didChangeFont = textView.font?.fontName != font.fontName
            || textView.font?.pointSize != font.pointSize

        if didChangeFont {
            textView.font = font
            applyEditorTextAttributes()
        } else {
            applyDefaultTypingAttributes(using: font)
        }
    }

    func applyEditorTextAttributes() {
        let monospacedFont = editorMonospacedFont()
        let defaultFont = Self.defaultEditorFont(ofSize: monospacedFont.pointSize)
        applyDefaultTypingAttributes(using: monospacedFont)

        guard let textStorage = textView.textStorage, textStorage.length > 0 else {
            return
        }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        let paragraphStyle = Self.editorParagraphStyle()
        let foregroundColor = Self.editorForegroundColor()
        textStorage.beginEditing()
        textStorage.setAttributes(
            [
                .font: defaultFont,
                .paragraphStyle: paragraphStyle,
                .foregroundColor: foregroundColor
            ],
            range: fullRange
        )

        let string = textStorage.string
        var runStart = string.startIndex

        while runStart < string.endIndex {
            let isMonospacedRun = Self.shouldUseMonospacedFont(for: string[runStart])
            var runEnd = string.index(after: runStart)

            while runEnd < string.endIndex,
                  Self.shouldUseMonospacedFont(for: string[runEnd]) == isMonospacedRun {
                runEnd = string.index(after: runEnd)
            }

            if isMonospacedRun {
                textStorage.addAttribute(
                    .font,
                    value: monospacedFont,
                    range: NSRange(runStart..<runEnd, in: string)
                )
            }

            runStart = runEnd
        }

        textStorage.endEditing()
        refreshLineNumbers()
    }

    func enforceEditorTextAttributesIfNeeded() {
        let font = editorMonospacedFont()
        applyDefaultTypingAttributes(using: font)

        guard let textStorage = textView.textStorage, textStorage.length > 0 else {
            return
        }

        let attributes = textStorage.attributes(at: 0, effectiveRange: nil)
        let currentFont = attributes[.font] as? NSFont
        let currentParagraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle
        let needsFontRefresh = currentFont?.fontName != font.fontName
            || currentFont?.pointSize != font.pointSize
        let needsParagraphRefresh = currentParagraphStyle?.lineHeightMultiple
            != Self.editorLineHeightMultiple

        guard needsFontRefresh || needsParagraphRefresh else {
            return
        }

        applyEditorTextAttributes()
    }

    func prepareTypingAttributes(for replacementString: String?) {
        let pointSize = currentEditorFontSize
        let font: NSFont

        if let firstCharacter = replacementString?.first,
           Self.shouldUseMonospacedFont(for: firstCharacter) {
            font = Self.editorFont(ofSize: pointSize)
        } else if replacementString?.isEmpty == false {
            font = Self.defaultEditorFont(ofSize: pointSize)
        } else {
            font = Self.editorFont(ofSize: pointSize)
        }

        applyDefaultTypingAttributes(using: font)
    }

    func performSearch(for query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return
        }

        let fullText = textView.string as NSString
        guard fullText.length > 0 else {
            NSSound.beep()
            return
        }

        let selectedRange = textView.selectedRange()
        let selectionEnd = selectedRange.location == NSNotFound
            ? 0
            : min(NSMaxRange(selectedRange), fullText.length)
        let searchOptions: NSString.CompareOptions = [.caseInsensitive]
        let forwardSearchRange = NSRange(
            location: selectionEnd,
            length: fullText.length - selectionEnd
        )

        var matchRange = fullText.range(
            of: trimmedQuery,
            options: searchOptions,
            range: forwardSearchRange
        )

        if matchRange.location == NSNotFound, selectionEnd > 0 {
            matchRange = fullText.range(
                of: trimmedQuery,
                options: searchOptions,
                range: NSRange(location: 0, length: selectionEnd)
            )
        }

        guard matchRange.location != NSNotFound else {
            NSSound.beep()
            return
        }

        textView.window?.makeFirstResponder(textView)
        textView.setSelectedRange(matchRange)
        textView.scrollRangeToVisible(matchRange)
    }

    private func configureTextView() {
        currentEditorFontSize = NSFont.systemFontSize
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
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

    private static func defaultEditorFont(ofSize size: CGFloat) -> NSFont {
        NSFont.systemFont(ofSize: size)
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

    private static func shouldUseMonospacedFont(for character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(\.isASCII)
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
