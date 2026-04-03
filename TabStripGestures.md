# Tab Strip Gestures

This document describes the gesture requirements and implementation details for `EditorTabStripView.swift` and its child views.

---

## Requirements Overview

1. **Single-click a tab**
   * **Behavior**: Switch to the selected tab immediately.
   * **Performance requirement**: **No delay**. Single-clicks must not feel slower because the system is waiting to see whether the user double-clicks.

2. **Double-click the active tab**
   * **Behavior**: Enter inline rename mode for the current tab title.

3. **Double-click an inactive tab**
   * **Behavior**: Select the tab only. It must not enter rename mode.

4. **Double-click empty title bar space**
   * **Behavior**: Trigger the macOS title bar zoom action, following the system's `AppleActionOnDoubleClick` preference.

5. **Click inside the rename field while editing**
   * **Behavior**: Move the insertion point normally without leaving edit mode.

6. **Click outside the title bar while editing**
   * **Behavior**: Save the edited title and leave edit mode.

7. **Switch to another app while editing**
   * **Behavior**: Save the edited title and leave edit mode.

---

## Core Constraint: Why SwiftUI Gestures Are Not Allowed

**Do not add `.onTapGesture` or `.simultaneousGesture(TapGesture(...))` to `EditorTabStripView` or any of its ancestors.**

Reason: SwiftUI multi-click gestures (`TapGesture(count: 2)` and `.onTapGesture(count: 2)`) inject click recognition delay into the entire view tree. Even if the double-click handler lives on a parent, child views with single-click interactions, including `Button` actions, are forced to wait for the double-click window (about 250 ms). That directly violates the no-delay requirement above.

**Conclusion**: All click and double-click handling must bypass the SwiftUI gesture system and use the following mechanisms instead:
- **Tab click and double-click**: SwiftUI `Button` action for immediate response plus manual timestamp-based double-click detection
- **Empty title bar double-click and edit dismissal**: AppKit `NSEvent.addLocalMonitorForEvents`

---

## Architecture

### Participating Components

| Component | Responsibility |
|------|------|
| `EditorTabStripView` | Parent container that owns `editingTabID` state and provides `dismissEditing()` |
| `EditorTabItemView` | Per-tab view with a SwiftUI `Button` that handles click, double-click, and rename |
| `TitleBarEventMonitor` | `NSViewRepresentable` event monitor at the AppKit layer |
| `tabStripSuppressNextZoom` | File-scoped flag that prevents a tab double-click from also triggering title bar zoom |
| `tabStripPendingRename` | File-scoped flag that stores the pending renamed title for external dismiss paths |

### Data Flow

```text
User input
  |
  |- mouseDown --> TitleBarEventMonitor
  |                 |- Outside title bar + editing in progress -> dismissEditing()
  |                 `- Otherwise -> ignore
  |
  |- mouseUp ----> TitleBarEventMonitor
  |                 `- clickCount >= 2 + inside title bar + same window
  |                    -> async { check suppress flag -> zoom or skip }
  |
  `- mouseUp ----> SwiftUI Button (EditorTabItemView.handleClick)
                    |- Set tabStripSuppressNextZoom = true
                    |- Selected tab + timestamp double-click check -> begin editing
                    `- Otherwise -> onSelectTab
```

---

## Detailed Implementation Notes

### 1. Single-click tab switching with no delay

`EditorTabItemView` uses a SwiftUI `Button` with `.buttonStyle(.plain)`, and the action directly calls `handleClick()`. `Button` fires immediately on `mouseUp` without gesture recognition delay.

### 2. Double-click rename via manual timestamp detection

Inside `handleClick()`, double-clicks are detected manually with `lastSelectedClickTime` and `NSEvent.doubleClickInterval`:

```swift
if isSelected {
    let now = Date()
    if now.timeIntervalSince(lastSelectedClickTime) < NSEvent.doubleClickInterval {
        // Double-clicking the selected tab enters rename mode.
        isEditing = true
        return
    }
    lastSelectedClickTime = now
}
```

Key details:
- Record timestamps and check for double-clicks only when `isSelected == true`.
- A double-click on an inactive tab never renames it: the first click only selects the tab and resets `lastSelectedClickTime` to `.distantPast`, so the second click is treated as the first eligible click for rename timing.

### 3. Empty title bar double-click zoom via AppKit event monitoring

`TitleBarEventMonitor` is an `NSViewRepresentable` that hosts `TitleBarEventNSView`, which listens to all local mouse events through `NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp])`.

**Zoom is checked on `mouseUp`, not `mouseDown`**, because:
- SwiftUI `Button` actions fire on `mouseUp`.
- During `mouseDown`, the `Button` action has not run yet, so the suppress flag is not set.
- Detecting zoom on `mouseDown` and trying to coordinate with `asyncAfter` is unreliable because the time from `mouseDown` to `mouseUp` varies widely.
- Detecting on `mouseUp` and then using `DispatchQueue.main.async` waits exactly one run loop, by which point the `Button` action has already completed.

```swift
} else if event.type == .leftMouseUp {
    guard event.clickCount >= 2,
          event.window === self.window,
          isClickInTitleBarRegion(event) else { return }

    DispatchQueue.main.async { [weak self] in
        if tabStripSuppressNextZoom {
            tabStripSuppressNextZoom = false
            return
        }
        self?.performTitleBarDoubleClickAction()
    }
}
```

**Title bar hit testing**: Because the window uses `.hiddenTitleBar`, `contentLayoutRect` matches the entire window. The implementation therefore uses absolute coordinates: `event.locationInWindow.y >= (windowHeight - titleBarHeight)`.

### 4. Suppress flag coordination

`tabStripSuppressNextZoom`, a file-scoped `nonisolated(unsafe) var`, prevents a tab double-click from also triggering title bar zoom:

- `handleClick()` sets the flag to `true` on **every click**, not just the second click, because the event monitor checks `event.clickCount >= 2` and still needs the first click's flag to be alive when the second `mouseUp` arrives.
- The flag is cleared automatically with `asyncAfter(NSEvent.doubleClickInterval + 0.1)` so it never leaks into unrelated future events.
- **The auto-clear timeout must be greater than `doubleClickInterval`**. If it expires too early, the first click's flag disappears before the second click arrives and title bar zoom is triggered accidentally.

```swift
tabStripSuppressNextZoom = true
DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval + 0.1) {
    tabStripSuppressNextZoom = false
}
```

### 5. Leaving edit mode and saving the title

Edit mode has multiple exit paths with slightly different commit behavior:

#### Path A: Press Enter (`onSubmit`)
`commitTitleEditing()` calls `onRename(sanitizedTitle)` directly and then sets `isEditing = false`.

#### Path B: Click outside (`monitor` dismiss)
1. The monitor sees a `mouseDown` outside the title bar region (`!isClickInTitleBarRegion`).
2. It asynchronously calls `EditorTabStripView.dismissEditing()`.
3. `dismissEditing()` reads the pending title from `tabStripPendingRename` and calls `onRenameTab`.
4. It sets `editingTabID = nil`, which makes `isEditing` false and removes the `TextField`.

**Why `tabStripPendingRename` is used instead of `onDisappear`**:
- `onDisappear` fires while the view is being torn down. Writing back to bindings at that point, such as `isEditing = false`, or calling `onRename` can trigger a render cascade and spike CPU usage.
- `tabStripPendingRename` is kept in sync through `onChange(of: draftTitle)`, so `dismissEditing()` can read the current draft title before the field disappears.

#### Path C: Switch to another app
`NSApplication.didResignActiveNotification` follows the same path as Path B.

### 6. Clicking inside the rename field does not dismiss edit mode

The monitor only dismisses editing on `mouseDown` when `!isClickInTitleBarRegion(event)` is true. The rename `TextField` lives inside the title bar region, so clicking it does not dismiss editing and caret movement works as expected.

---

## Pitfalls and Maintenance Notes

### Do Not Do These Things

1. **Do not add `.onTapGesture` or `.simultaneousGesture(TapGesture(...))` to `EditorTabStripView` or its ancestors.** This introduces roughly 250 ms of click delay to child views.

2. **Do not write to bindings or mutate the model from `onDisappear`.** During view teardown, that can trigger render cascades. With rapid double-clicks, repeated `TextField` creation and destruction can spike CPU usage dramatically.

3. **Do not use a fixed `asyncAfter` delay to coordinate `mouseDown` with the `Button` action.** The interval between `mouseDown` and `mouseUp` is not stable, so fixed delays are unreliable. Zoom detection belongs on `mouseUp`.

4. **Do not trigger commits from `onChange(of: isEditing)`.** `commitTitleEditing()` sets `isEditing = false` through the `editingTabID` binding, which can create a write-notify-write loop.

5. **Do not use `view is NSText` to decide whether the click happened inside the rename field.** The editor itself is also an `NSTextView` subclass, so type checks misclassify clicks. The current implementation uses title bar region checks instead.

6. **Do not make the suppress auto-clear timeout too short.** It must remain greater than `NSEvent.doubleClickInterval`, or the first click's flag will expire before the second click lands.

### Timing Model

Full sequence for double-clicking the selected tab:
```text
t=0ms     1st mouseDown  -> monitor: clickCount=1, ignore zoom
t=100ms   1st mouseUp    -> Button handleClick: suppress=true, lastSelectedClickTime=now
t=300ms   2nd mouseDown  -> monitor: clickCount=2, but still mouseDown, ignore zoom
t=400ms   2nd mouseUp    -> monitor: clickCount=2, inside title bar, async { check suppress }
                          -> Button handleClick: detect double-click -> enter edit mode, suppress=true
t=401ms   async block    -> suppress=true -> skip zoom
t=500ms   auto-clear     -> suppress=false (from the 1st click's asyncAfter)
```

Full sequence for double-clicking empty title bar space:
```text
t=0ms     1st mouseDown  -> monitor: clickCount=1
t=100ms   1st mouseUp    -> monitor: clickCount=1, skip. No Button here, suppress unchanged
t=300ms   2nd mouseDown  -> monitor: clickCount=2, but still mouseDown, ignore
t=400ms   2nd mouseUp    -> monitor: clickCount=2, async { check suppress }
                          -> No Button involved, suppress is still false
t=401ms   async block    -> suppress=false -> performTitleBarDoubleClickAction()
```
