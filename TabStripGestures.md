# Tab Strip Gestures (标签栏手势需求与实现规范)

本文件说明了 `EditorTabStripView.swift` 及其子视图中手势（Gestures）的设计需求与实现细节。

---

## 需求概览

1. **单点击 Tab**:
   * **行为**: 立即切换选中的标签页。
   * **性能需求**: **无延迟**。不可因为等待双击而使单点击操作产生明显滞后感。

2. **双击已激活 (Selected) Tab**:
   * **行为**: 触发当前标签的文件名编辑重命名。

3. **双击未激活 (Inactive) Tab**:
   * **行为**: **仅选中**，不可触发文件名编辑重命名。

4. **双击 Titlebar 空白区域**:
   * **行为**: 放大/缩小（Maximize/Minimize）窗口（跟随 macOS 的 "AppleActionOnDoubleClick" 系统偏好设置）。

5. **编辑文件名时单击重命名框内部**:
   * **行为**: 正常的光标定位，不退出编辑模式。

6. **编辑文件名时点击标题栏以外区域（编辑器、其他窗口等）**:
   * **行为**: 保存已编辑的文件名并退出编辑模式。

7. **编辑文件名时切换到其他 App**:
   * **行为**: 保存已编辑的文件名并退出编辑模式。

---

## 核心约束：为什么不能用 SwiftUI 手势

**禁止在 `EditorTabStripView` 或其祖先上使用任何 `.onTapGesture` 或 `.simultaneousGesture(TapGesture(...))`。**

原因：SwiftUI 的多次点击手势（`TapGesture(count: 2)`、`.onTapGesture(count: 2)`）会在整个视图树上注入手势判定延迟。即使只在父视图上添加 `count: 2`，所有子视图的 `count: 1` 手势（包括 Button action）也会被迫等待双击判定窗口（约 250ms）才能触发。这直接违反需求 1 的"无延迟"要求。

**结论**: 所有点击/双击逻辑必须绕过 SwiftUI 手势系统，使用以下两种机制：
- **Tab 点击/双击**: SwiftUI `Button` action（立即响应）+ 手动时间戳双击检测
- **标题栏空白区域双击 & 编辑退出**: AppKit `NSEvent.addLocalMonitorForEvents`

---

## 实现架构

### 参与组件

| 组件 | 职责 |
|------|------|
| `EditorTabStripView` | 父容器，持有 `editingTabID` 状态，提供 `dismissEditing()` |
| `EditorTabItemView` | 每个标签页，内含 SwiftUI `Button`，处理单击/双击/重命名 |
| `TitleBarEventMonitor` | `NSViewRepresentable`，AppKit 层事件监听器 |
| `tabStripSuppressNextZoom` | 文件级标志，协调 tab 双击与标题栏 zoom 的冲突 |
| `tabStripPendingRename` | 文件级标志，存储待保存的文件名（供外部 dismiss 时读取） |

### 数据流图

```
用户点击
  │
  ├─ mouseDown ──→ TitleBarEventMonitor
  │                  ├─ 在标题栏外 + 正在编辑 → dismissEditing()
  │                  └─ 其他 → 不处理
  │
  └─ mouseUp ───→ TitleBarEventMonitor
  │                  └─ clickCount >= 2 + 在标题栏内 + 本窗口
  │                       → async { 检查 suppress → zoom 或跳过 }
  │
  └─ mouseUp ───→ SwiftUI Button (EditorTabItemView.handleClick)
                     ├─ 设 tabStripSuppressNextZoom = true
                     ├─ 已选中 + 时间戳双击检测 → 进入编辑模式
                     └─ 其他 → onSelectTab
```

---

## 详细实现说明

### 1. Tab 单击切换（无延迟）

`EditorTabItemView` 使用 SwiftUI `Button`（`.buttonStyle(.plain)`），action 直接调用 `handleClick()`。Button 在 mouseUp 立即响应，无任何手势判定延迟。

### 2. Tab 双击重命名（手动时间戳检测）

`handleClick()` 内部用 `lastSelectedClickTime` + `NSEvent.doubleClickInterval` 手动判定双击：

```swift
if isSelected {
    let now = Date()
    if now.timeIntervalSince(lastSelectedClickTime) < NSEvent.doubleClickInterval {
        // 双击已选中 tab → 进入编辑模式
        isEditing = true
        return
    }
    lastSelectedClickTime = now
}
```

关键点：
- 只有 `isSelected == true` 时才记录时间戳和检测双击
- 未选中 tab 的双击：第 1 次点击切换选中（`lastSelectedClickTime` 重置为 `.distantPast`），第 2 次点击才开始计时，所以永远不会触发重命名

### 3. 标题栏空白区域双击 Zoom（AppKit NSEvent Monitor）

`TitleBarEventMonitor`（`NSViewRepresentable`）内含 `TitleBarEventNSView`，通过 `NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp])` 监听所有本地鼠标事件。

**Zoom 在 mouseUp 检测**（不是 mouseDown），原因：
- SwiftUI Button 在 mouseUp 触发 action
- NSEvent monitor 在 mouseDown 触发时，Button action 尚未执行，suppress 标志未设置
- 如果在 mouseDown 检测 zoom 并用 `asyncAfter` 延迟，延迟时间不可靠（mouseDown → mouseUp 间隔 100-400ms 不等）
- 改在 mouseUp 检测 + `DispatchQueue.main.async`（零延迟下一个 run loop），此时 Button action 已同步执行完毕

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

**标题栏区域判定**: 因为窗口使用 `.hiddenTitleBar`，`contentLayoutRect` 等于整个窗口，所以用绝对坐标判断：`event.locationInWindow.y >= (windowHeight - titleBarHeight)`。

### 4. Suppress 标志协调机制

`tabStripSuppressNextZoom`（文件级 `nonisolated(unsafe) var`）用于防止 tab 上的双击同时触发 zoom：

- `handleClick()` 中**每次点击**都设 `true`（不仅是双击时），因为 monitor 的 zoom 检测看的是 `event.clickCount >= 2`，而第 1 次点击设的 flag 需要在第 2 次 mouseUp 时仍然有效
- 设置后通过 `asyncAfter(NSEvent.doubleClickInterval + 0.1)` 自动清除，防止 flag 泄漏到后续无关事件
- **Auto-clear 必须 > doubleClickInterval**，否则两次点击之间 flag 就过期了（第 1 次点击设 flag → 等 250ms → 第 2 次点击 → flag 已清除 → zoom 误触发）

```swift
tabStripSuppressNextZoom = true
DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval + 0.1) {
    tabStripSuppressNextZoom = false
}
```

### 5. 编辑模式退出与文件名保存

编辑模式有两条退出路径，commit 逻辑不同：

#### 路径 A：Enter 键（onSubmit）
`commitTitleEditing()` 直接调用 `onRename(sanitizedTitle)`，然后设 `isEditing = false`。

#### 路径 B：点击外部（monitor dismiss）
1. Monitor 在 mouseDown 检测到点击在标题栏区域外（`!isClickInTitleBarRegion`）
2. 异步调用 `EditorTabStripView.dismissEditing()`
3. `dismissEditing()` 从 `tabStripPendingRename` 读取已编辑标题，调用 `onRenameTab`
4. 设 `editingTabID = nil` → `isEditing` 变 false → TextField 消失

**为什么用 `tabStripPendingRename` 而不是 `onDisappear`**:
- `onDisappear` 在 view 拆除过程中触发，此时写 Binding（`isEditing = false`）或调 `onRename` 会触发 re-render 级联，导致 CPU 100%
- `tabStripPendingRename` 通过 `onChange(of: draftTitle)` 实时同步，`dismissEditing()` 在 TextField 消失之前读取

#### 路径 C：切换到其他 App
`NSApplication.didResignActiveNotification` → 同路径 B。

### 6. 编辑模式内单击不退出

Monitor 的 mouseDown dismiss 只在 `!isClickInTitleBarRegion(event)` 时触发。重命名 TextField 在标题栏区域内，所以点击 TextField 不会触发 dismiss，光标定位正常工作。

---

## 已踩过的坑（维护提醒）

### 不要做

1. **不要在 EditorTabStripView 或其祖先上添加 `.onTapGesture`、`.simultaneousGesture(TapGesture(...))`** — 会给所有子视图引入 ~250ms 点击延迟。

2. **不要在 `onDisappear` 里写 Binding 或调 model 修改方法** — view 拆除过程中写 Binding 会触发 re-render 级联，快速双击时 TextField 反复创建/销毁会放大为 CPU 100%。

3. **不要用 `asyncAfter` 固定毫秒数来协调 mouseDown 和 Button action** — mouseDown → mouseUp 间隔不固定（100-400ms），任何固定延迟都不可靠。正确做法是在 mouseUp 检测 zoom。

4. **不要用 `onChange(of: isEditing)` 来触发 commit** — `commitTitleEditing()` 写 `isEditing = false`（通过 Binding 连到 `editingTabID`），可能形成写入 → 通知 → 写入的无限循环。

5. **不要用 `view is NSText` 来判断点击是否在重命名框内** — 编辑器主体也是 `NSTextView`（继承自 `NSText`），会误判。当前实现用区域判断（标题栏内/外）替代类型判断。

6. **Auto-clear suppress 标志的超时不能太短** — 必须 > `NSEvent.doubleClickInterval`，否则第 1 次点击设的 flag 在第 2 次点击到来前就过期了。

### 时序模型

双击已选中 tab 的完整时序：
```
t=0ms     1st mouseDown  → monitor: clickCount=1, 不处理 zoom
t=100ms   1st mouseUp    → Button handleClick: suppress=true, lastSelectedClickTime=now
t=300ms   2nd mouseDown  → monitor: clickCount=2 but this is mouseDown, 不处理 zoom
t=400ms   2nd mouseUp    → monitor: clickCount=2, 在标题栏, async { 检查 suppress }
                          → Button handleClick: 检测双击 → 进入编辑模式, suppress=true
t=401ms   async block    → suppress=true → 跳过 zoom ✓
t=500ms   auto-clear     → suppress=false（从 1st click 的 asyncAfter）
```

双击标题栏空白区域的完整时序：
```
t=0ms     1st mouseDown  → monitor: clickCount=1
t=100ms   1st mouseUp    → monitor: clickCount=1, 跳过. 无 Button 在此处, suppress 不变
t=300ms   2nd mouseDown  → monitor: clickCount=2 but mouseDown, 不处理
t=400ms   2nd mouseUp    → monitor: clickCount=2, async { 检查 suppress }
                          → 无 Button, suppress 仍 false
t=401ms   async block    → suppress=false → performTitleBarDoubleClickAction() ✓
```
