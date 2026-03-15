import AppKit
import SwiftUI

struct LineNumberTextEditor: NSViewRepresentable {
    @Binding var text: String

    let onTextChange: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> LineNumberEditorContainerView {
        let containerView = LineNumberEditorContainerView()
        let textView = containerView.textView

        textView.delegate = context.coordinator
        textView.string = text
        containerView.refreshLineNumbers()

        return containerView
    }

    func updateNSView(_ containerView: LineNumberEditorContainerView, context: Context) {
        context.coordinator.parent = self

        if containerView.textView.string != text {
            context.coordinator.isSyncingFromSwiftUI = true
            containerView.textView.string = text
            context.coordinator.isSyncingFromSwiftUI = false
            containerView.refreshLineNumbers()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: LineNumberTextEditor
        var isSyncingFromSwiftUI = false

        init(parent: LineNumberTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isSyncingFromSwiftUI,
                  let textView = notification.object as? NSTextView,
                  let containerView = textView.enclosingScrollView?.superview as? LineNumberEditorContainerView else {
                return
            }

            parent.text = textView.string
            parent.onTextChange()
            containerView.refreshLineNumbers()
        }
    }
}

final class LineNumberEditorContainerView: NSView {
    let textView: NSTextView

    private let scrollView: NSScrollView
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

    override init(frame frameRect: NSRect) {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            fatalError("Expected NSTextView inside scrollableTextView")
        }

        self.scrollView = scrollView
        self.textView = textView
        self.lineNumberView = LineNumberGutterView(scrollView: scrollView, textView: textView)

        super.init(frame: frameRect)

        configureTextView()
        configureScrollView()
        configureLayout()
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
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
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

        let gutterWidthConstraint = lineNumberView.widthAnchor.constraint(equalToConstant: lineNumberView.requiredWidth)
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

private final class LineNumberGutterView: NSView {
    enum Metrics {
        static let minimumDigits = 3
        static let leftPadding: CGFloat = 10
        static let rightPadding: CGFloat = 8
    }

    private weak var scrollView: NSScrollView?
    private weak var textView: NSTextView?

    override var isFlipped: Bool {
        true
    }

    var requiredWidth: CGFloat {
        let digits = max(Metrics.minimumDigits, String(totalLineCount).count)
        let sample = String(repeating: "8", count: digits) as NSString
        let width = ceil(sample.size(withAttributes: textAttributes).width)
        return Metrics.leftPadding + width + Metrics.rightPadding
    }

    init(scrollView: NSScrollView, textView: NSTextView) {
        self.scrollView = scrollView
        self.textView = textView
        super.init(frame: .zero)
        wantsLayer = true
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
            drawLineNumber(1, atY: textView.textContainerInset.height)
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
            let lineGlyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)

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
                    drawLineNumber(lineNumber, atY: y)
                }
            }

            lineStartIndex = NSMaxRange(lineRange)
            lineNumber += 1
        }

        if textView.string.hasSuffix("\n") {
            let extraRect = layoutManager.extraLineFragmentRect
            if !extraRect.isEmpty {
                let y = extraRect.minY + textView.textContainerInset.height - visibleRect.minY
                drawLineNumber(totalLineCount, atY: y)
            }
        }
    }

    @objc
    private func handleTextDidChange() {
        needsDisplay = true
        superview.flatMap { $0 as? LineNumberEditorContainerView }?.refreshLineNumbers()
    }

    @objc
    private func handleScrollBoundsDidChange() {
        needsDisplay = true
    }

    func updateColors() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        needsDisplay = true
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

    private var totalLineCount: Int {
        guard let textView else {
            return 1
        }

        return max(1, textView.string.reduce(into: 1) { count, character in
            if character == "\n" {
                count += 1
            }
        })
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

    static var gutterColor: NSColor {
        NSColor.quaternaryLabelColor.blended(
            withFraction: 0.5,
            of: NSColor.tertiaryLabelColor.withAlphaComponent(0.75)
        ) ?? NSColor.tertiaryLabelColor.withAlphaComponent(0.6)
    }

    static var separatorColor: NSColor {
        NSColor.separatorColor.withAlphaComponent(0.35)
    }

    private func font(for textView: NSTextView) -> NSFont {
        let pointSize = textView.font?.pointSize ?? NSFont.systemFontSize
        return .monospacedDigitSystemFont(ofSize: pointSize, weight: .regular)
    }

    private func drawLineNumber(_ lineNumber: Int, atY y: CGFloat) {
        let label = String(lineNumber) as NSString
        let labelSize = label.size(withAttributes: textAttributes)
        let rect = NSRect(
            x: Metrics.leftPadding,
            y: y,
            width: bounds.width - Metrics.leftPadding - Metrics.rightPadding,
            height: labelSize.height
        )
        label.draw(in: rect, withAttributes: textAttributes)
    }

    private func lineNumber(atCharacterIndex characterIndex: Int, string: NSString) -> Int {
        guard characterIndex > 0 else {
            return 1
        }

        let prefix = string.substring(to: min(characterIndex, string.length))
        return prefix.reduce(into: 1) { count, character in
            if character == "\n" {
                count += 1
            }
        }
    }
}
