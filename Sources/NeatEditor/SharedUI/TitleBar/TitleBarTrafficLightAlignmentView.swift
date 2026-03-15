import AppKit
import SwiftUI

struct TitleBarTrafficLightAlignmentView: NSViewRepresentable {
    let titleBarHeight: CGFloat

    func makeNSView(context: Context) -> TrafficLightAlignmentHostingView {
        TrafficLightAlignmentHostingView(titleBarHeight: titleBarHeight)
    }

    func updateNSView(_ nsView: TrafficLightAlignmentHostingView, context: Context) {
        nsView.titleBarHeight = titleBarHeight
        nsView.centerTrafficLightsIfNeeded()
    }
}

final class TrafficLightAlignmentHostingView: NSView {
    var titleBarHeight: CGFloat {
        didSet {
            centerTrafficLightsIfNeeded()
        }
    }

    init(titleBarHeight: CGFloat) {
        self.titleBarHeight = titleBarHeight
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
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let window {
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.didResizeNotification,
                object: window
            )
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
}
