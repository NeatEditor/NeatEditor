# Tab Strip Gestures (标签栏手势需求与实现规范)

本文件说明了 `EditorTabStripView.swift` 及其子视图中手势（Gestures）的设计需求。

---

## 📌 需求概览

1. **单点击 Tab**: 
   * **行为**: 立即切换选中的标签页。
   * **性能需求**: **无延迟**。不可因为等待双击而使单点击操作产生明显滞后感。

2. **双击已激活 (Selected) Tab**:
   * **行为**: 触发当前标签的文件名编辑重命名。

3. **双击未激活 (Inactive) Tab**:
   * **行为**: **仅选中**，不可触发文件名编辑重命名。

4. **双击 Titlebar 空白区域**:
   * **行为**: 放大/缩小（Maximize/Minimize）窗口（跟随 macOS 的 “AppleActionOnDoubleClick” 系统偏好设置）。

