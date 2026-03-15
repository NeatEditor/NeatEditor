import AppKit

final class EditorTextContainerView: NSView {
    let textView: ZoomableTextView

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
        guard textView.font?.pointSize != fontSize else {
            return
        }

        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.typingAttributes[.font] = textView.font
        refreshLineNumbers()
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
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .controlBackgroundColor
        textView.insertionPointColor = .labelColor
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

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(
                width: 0,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
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
}
