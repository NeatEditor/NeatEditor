import AppKit
import SwiftUI

struct TitleBarTrafficLightAlignmentView: NSViewRepresentable {
    let titleBarHeight: CGFloat
    let isWindowPinned: Bool

    func makeNSView(context: Context) -> TrafficLightAlignmentHostingView {
        TrafficLightAlignmentHostingView(
            titleBarHeight: titleBarHeight,
            isWindowPinned: isWindowPinned
        )
    }

    func updateNSView(_ nsView: TrafficLightAlignmentHostingView, context: Context) {
        nsView.titleBarHeight = titleBarHeight
        nsView.isWindowPinned = isWindowPinned
        nsView.centerTrafficLightsIfNeeded()
    }
}

final class TrafficLightAlignmentHostingView: NSView {
    var titleBarHeight: CGFloat {
        didSet {
            centerTrafficLightsIfNeeded()
        }
    }
    var isWindowPinned: Bool {
        didSet {
            applyWindowPinningIfNeeded()
        }
    }

    init(titleBarHeight: CGFloat, isWindowPinned: Bool) {
        self.titleBarHeight = titleBarHeight
        self.isWindowPinned = isWindowPinned
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindowObserver()
        centerTrafficLightsIfNeeded()
        applyWindowPinningIfNeeded()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let window {
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.didResizeNotification,
                object: window
            )
            if window != newWindow {
                window.level = .normal
            }
        }

        super.viewWillMove(toWindow: newWindow)
    }

    override func layout() {
        super.layout()
        centerTrafficLightsIfNeeded()
    }

    func centerTrafficLightsIfNeeded() {
        guard let window,
              let closeButton = window.standardWindowButton(.closeButton),
              let minimizeButton = window.standardWindowButton(.miniaturizeButton),
              let zoomButton = window.standardWindowButton(.zoomButton),
              let buttonContainer = closeButton.superview else {
            return
        }

        let nativeTitleBarHeight = window.frame.height - window.contentLayoutRect.height
        let resolvedTitleBarHeight = max(titleBarHeight, nativeTitleBarHeight)
        let targetOriginY = buttonContainer.frame.height - resolvedTitleBarHeight
            + ((resolvedTitleBarHeight - closeButton.frame.height) / 2)

        for button in [closeButton, minimizeButton, zoomButton] {
            guard abs(button.frame.origin.y - targetOriginY) > 0.5 else {
                continue
            }

            button.setFrameOrigin(
                NSPoint(
                    x: button.frame.origin.x,
                    y: round(targetOriginY)
                )
            )
        }
    }

    private func configureWindowObserver() {
        guard let window else {
            return
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidResize),
            name: NSWindow.didResizeNotification,
            object: window
        )
    }

    @objc
    private func handleWindowDidResize() {
        centerTrafficLightsIfNeeded()
    }

    private func applyWindowPinningIfNeeded() {
        guard let window else {
            return
        }

        let targetLevel: NSWindow.Level = isWindowPinned ? .floating : .normal
        guard window.level != targetLevel else {
            return
        }

        window.level = targetLevel
    }
}
