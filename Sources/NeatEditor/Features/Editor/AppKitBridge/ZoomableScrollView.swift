import AppKit

final class ZoomableScrollView: NSScrollView {
    private enum ZoomMetrics {
        static let scrollThreshold: CGFloat = 20
    }

    var onIncreaseFontSize: () -> Void = {}
    var onDecreaseFontSize: () -> Void = {}

    private var pendingZoomDelta: CGFloat = 0

    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command) else {
            pendingZoomDelta = 0
            super.scrollWheel(with: event)
            return
        }

        let deltaY = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY
        guard deltaY != 0 else {
            super.scrollWheel(with: event)
            return
        }

        pendingZoomDelta += deltaY

        while abs(pendingZoomDelta) >= ZoomMetrics.scrollThreshold {
            if pendingZoomDelta > 0 {
                onIncreaseFontSize()
                pendingZoomDelta -= ZoomMetrics.scrollThreshold
            } else {
                onDecreaseFontSize()
                pendingZoomDelta += ZoomMetrics.scrollThreshold
            }
        }

        if event.phase == .ended || event.phase == .cancelled
            || event.momentumPhase == .ended || event.momentumPhase == .cancelled {
            pendingZoomDelta = 0
        }
    }
}
