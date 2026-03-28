# AGENTS.md
本文件是 NeatEditor 仓库内 agent 的工作手册。
在本仓库中工作时，优先遵守这里的约定，再结合通用编码常识执行。

## 适用范围
- 平台：macOS 15.0+
- 语言：Swift 6
- UI：SwiftUI
- 工程管理：XcodeGen（`project.yml`）
- Xcode：16.2+

## 已检查的额外规则文件
- 已检查 `.cursor/rules/`：未找到规则文件。
- 已检查 `.cursorrules`：未找到规则文件。
- 已检查 `.github/copilot-instructions.md`：未找到规则文件。
- 因此当前仓库没有额外的 Cursor/Copilot 本地规则；本文件即仓库内 agent 约定的主要来源。

## 仓库结构
- `project.yml`：XcodeGen 配置，是工程结构的真实来源。
- `NeatEditor.xcodeproj`：生成产物；除非 `project.yml` 无法表达，否则不要手改。
- `Sources/NeatEditor/App`：应用入口与 Scene/commands 配置。
- `Sources/NeatEditor/App/Commands`：菜单命令与快捷键入口。
- `Sources/NeatEditor/Features/Workspace`：工作区状态、标签栏与主界面。
- `Sources/NeatEditor/Features/Editor/AppKitBridge`：编辑器桥接、行号 gutter、查找与缩放。
- `Sources/NeatEditor/Services`：自动保存与文档持久化服务。
- `Sources/NeatEditor/SharedUI`：共享 UI 样式与标题栏辅助视图。
- 当前仓库还没有 `Tests/` 目录，也没有测试 target。

## 动手前
- 先读相关文件，不要凭猜测做大改。
- 仅修改与任务直接相关的文件，避免顺手重构无关代码。
- 如果改动影响 `project.yml`，必须重新生成工程。
- 改完后至少做一次构建验证；若改动影响运行流程，也要将新构建出的 App 替换到 `/Applications/NeatEditor.app` 后再启动验证。

## 常用命令
### 工程生成
```bash
xcodegen generate
```
- 在修改 `project.yml`、新增/删除源文件、调整 target/scheme 后必须运行。
- 当前环境已验证 `xcodegen` 可用，版本为 `2.44.1`。

### 构建
```bash
xcodebuild -project "NeatEditor.xcodeproj" -scheme "NeatEditor" -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData build
```
- 这是当前仓库最可靠的编译检查方式。
- 推荐固定使用 `build/DerivedData`，便于后续启动 App 和排查产物。

### 分析 / 近似 lint
```bash
xcodebuild -project "NeatEditor.xcodeproj" -scheme "NeatEditor" -configuration Debug -destination 'platform=macOS' analyze
```
- 仓库当前没有 SwiftLint、SwiftFormat、`swift-format` 或 `.swiftlint.yml` 配置。
- 当前最接近 lint 的命令是 `xcodebuild ... analyze`。
- `swiftlint` 在当前环境中未安装，不要假设它可用。

### 运行 App
先执行上面的构建命令，然后关闭旧进程，用新构建产物替换 `/Applications/NeatEditor.app`，再从 `/Applications` 启动：
```bash
pkill -x "NeatEditor" || true
rm -rf "/Applications/NeatEditor.app"
ditto "build/DerivedData/Build/Products/Debug/NeatEditor.app" "/Applications/NeatEditor.app"
for attempt in 1 2 3; do
    if open "/Applications/NeatEditor.app"; then
        break
    fi
    if [ "$attempt" -eq 3 ]; then
        echo "Failed to launch NeatEditor after 3 attempts" >&2
        exit 1
    fi
    sleep 1
done
```
- 对 UI、窗口行为、命令菜单、保存流程做了修改时，优先执行这组命令验证。
- 启动验证时，以 `/Applications/NeatEditor.app` 作为唯一准入版本，不要直接打开 `build/DerivedData` 下的产物。
- 如果 `open` 失败，必须继续重试 2 次；只有连续 3 次都失败时，才可以向用户报告无法启动。

### 测试
当前状态：
```bash
xcodebuild -project "NeatEditor.xcodeproj" -scheme "NeatEditor" -configuration Debug -destination 'platform=macOS' test
```
- 该命令当前会失败，错误为：`Scheme NeatEditor is not currently configured for the test action.`
- 原因不是命令写错，而是仓库目前没有测试 target，也没有配置 test action。

当未来增加测试 target 后，推荐命令如下。
全量测试：
```bash
xcodebuild -project "NeatEditor.xcodeproj" -scheme "NeatEditor" -configuration Debug -destination 'platform=macOS' test
```
单个测试类：
```bash
xcodebuild -project "NeatEditor.xcodeproj" -scheme "NeatEditor" -configuration Debug -destination 'platform=macOS' -only-testing:NeatEditorTests/DocumentManagerTests test
```
单个测试方法：
```bash
xcodebuild -project "NeatEditor.xcodeproj" -scheme "NeatEditor" -configuration Debug -destination 'platform=macOS' -only-testing:NeatEditorTests/DocumentManagerTests/testAutoSaveDebounce test
```

- 如果你新增了测试，请同时更新 `project.yml`，确保 scheme 的 test action 生效。
- 不要假设 `swift test` 可用；这是 XcodeGen app 工程，不是纯 SwiftPM 包。

## 代码风格
### 导入（Imports）
- 每个 import 单独一行。
- 不保留未使用 import。
- 优先按语义分层排列：基础框架在前，UI 框架在后。
- 常见顺序：`Foundation` -> `Observation` -> `AppKit` -> `SwiftUI`。
- 只有用到 macOS 专属 API 时才引入 `AppKit`；纯 View 文件通常只需要 `SwiftUI`。

### 格式化
- 使用 4 空格缩进，不使用 tab。
- 使用 UTF-8 + LF。
- 类型、函数、条件语句的大括号与声明同行。
- 主要声明块之间保留一个空行；长表达式优先拆为局部变量。
- 不要为了“整洁”重排无关代码，避免制造大 diff。

### 命名
- 类型名使用 `UpperCamelCase`。
- 变量、属性、函数、参数使用 `lowerCamelCase`。
- 布尔值使用 `is`、`has`、`can`、`should` 前缀。
- 标识符主键或关联字段使用 `...ID` 后缀，例如 `selectedTabID`。
- 动作函数用动词开头，例如 `createNewDocument()`、`saveAllDocuments()`。

### 类型与建模
- 纯数据优先用 `struct`。
- 共享可变状态优先放在 `@Observable` 类型中。
- 引用语义确有必要时使用 `final class`，不要默认可继承。
- UI 相关状态或副作用入口尽量标记为 `@MainActor`。
- 能用 `some` / `any` 表达的地方遵循 Swift 6 语义明确写法。

### 并发与状态管理
- 默认按 Swift 6 严格并发思维写代码。
- 新代码优先使用 `async` / `await`，避免继续扩散回调风格。
- 需要保护可变共享状态时，优先考虑 actor 或清晰的 MainActor 隔离。
- 当前项目已经采用 Observation：优先使用 `@Observable`、`@Environment`、`@Bindable`。
- 不要在新代码中引入 `ObservableObject`、`@Published`、`@StateObject`、`@ObservedObject`，除非必须兼容外部 API。
- `View` 保持轻量；业务逻辑、持久化、状态转换放进管理对象或服务层。

### SwiftUI 约定
- View 负责声明 UI，不负责承载大块业务逻辑。
- 复用的视图片段拆成小组件或 `ViewModifier`。
- 优先保留 macOS 桌面交互习惯：标题栏、工具栏、快捷键、菜单命令、窗口尺寸。
- 修改窗口/命令相关逻辑时，同时检查 `Sources/NeatEditor/App/NeatEditorApp.swift`。
- 修改工作区或 tab 行为时，同时检查 `Sources/NeatEditor/Features/Workspace/WorkspaceView.swift` 与 `Sources/NeatEditor/Features/Workspace/EditorTabStripView.swift`。
- 修改编辑器行为时，同时检查 `Sources/NeatEditor/Features/Editor/AppKitBridge/EditorTextView.swift` 与 `Sources/NeatEditor/Features/Editor/AppKitBridge/EditorTextContainerView.swift`。

### 错误处理
- 不要新增 `!`、`try!`、强制 `as!`。
- 仓库里已有个别历史写法时，新增代码不要复制这种模式；触达相关代码时可顺手收敛。
- 可恢复错误优先通过 `throws`、显式错误状态或用户可见反馈处理。
- 不要只 `print(error)` 然后吞掉错误；更推荐把错误提升到调用层，或落到统一日志/提示。
- 文件 IO、保存、加载这类逻辑必须考虑失败路径。

### 极致的启动速度 (Ultimate Startup Speed)
- 严禁在 `@main` 或视图初始化等应用启动关键路径上，进行任何多余的同步文件 I/O 或阻塞操作。
- 任何耗时的文档加载必须采用**懒加载 (Lazy Load)**方案，如果首屏需要展示内容，必须**异步加载 (Async Load)**内容以确保主线程瞬间完成首帧渲染。
- 对于文件读取，尽可能使用 `Data(contentsOf:options:)` 结合 `.mappedIfSafe` 内存映射（mmap）技术，推迟物理内存分配并将文件 I/O 托付给操作系统的分页机制。

### 注释与文档
- 只在“意图不明显”或“约束容易误解”时加注释。
- 公共 API、复杂算法、重要状态机优先使用 `///` 文档注释。
- 注释描述“为什么”，不要机械复述“代码做了什么”。
- 不保留过期 TODO；如果留下 TODO，要具体说明缺什么。

### 文件与工程变更
- 新增 Swift 文件后，如果工程未自动包含，更新 `project.yml` 并重新执行 `xcodegen generate`。
- 非必要不要提交 `.xcodeproj` 内部手工改动。
- 不引入第三方库，除非用户明确要求并确认；优先使用系统框架：`Foundation`、`SwiftUI`、`Observation`、`OSLog`、`SwiftData` 等。

## 与当前代码保持一致的实现提示
- 文档标签页由 `EditorTab` 建模，集中存放在 `WorkspaceStore.tabs`。
- 当前选中文档由 `WorkspaceStore.selectedTabID` 驱动。
- 标签栏手势通过 `TitleBarEventMonitor` (AppKit `NSEvent` 局部监听) 实现，以绕过 SwiftUI `TapGesture` 导致的 ~250ms 点击延迟。
- 标签双击重命名使用 `NSEvent.doubleClickInterval` 手动判定，并配合文件级标志位 `tabStripSuppressNextZoom` 防止同时触发窗口缩放。
- 重命名编辑模式通过 `tabStripPendingRename` 在视图销毁前同步状态，确保点击外部区域或应用失去焦点时能正确保存并退出。
- 自动保存由 `WorkspaceStore.queueAutoSave(for:)` 触发，底层通过 `AutoSaveScheduler` 做 2 秒 debounce。
- 新建标签前、切换标签时、关闭当前标签时，都会先保存当前选中文档。
- 外部文件打开入口由 `ExternalFileOpenCoordinator` 接入，实际打开逻辑集中在 `WorkspaceStore.openFiles(at:)`。
- 同一路径的外部文件不会重复打开多个标签；重命名已落盘文件时会同步重命名磁盘文件并保留原扩展名。
- 切换标签时会保存旧标签；应用转入 inactive/background 时会保存全部文档。
- 空白内容（包括仅空白字符）不落盘是当前产品约定；触碰保存逻辑时不要把“清空文档后未覆盖磁盘文件”当作 bug 修掉，README 与实现需保持一致。
- 当前工作区支持内嵌搜索栏、`Command + +/-` 缩放，以及标题栏图钉控制窗口置顶；触碰相关交互时要连同命令菜单和最小窗口尺寸一起验证。
- 触碰这些逻辑时，要连同保存时机一起验证，不要只看 UI 是否能显示。

## Agent 工作方式
- 先读上下文，再改代码。
- 尽量小步提交，避免把“修功能”和“重排格式”混在一起。
- 完成修改后至少执行一次构建；如果变更影响运行流程，先用新构建产物替换 `/Applications/NeatEditor.app`，再启动该版本验证。
- 重启 App 时，必须从 `/Applications/NeatEditor.app` 启动；如果 `open` 启动失败，必须再重试 2 次；只有连续 3 次都失败时，才可结束并明确说明启动失败。
- 若测试仍未配置，不要谎称已跑测试；应明确说明“已构建/已 analyze，但 test action 尚不存在”。
- 若你新增了测试设施，请同步更新本文件中的命令示例。

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **NeatEditor** (60 symbols, 51 relationships, 0 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## When Debugging

1. `gitnexus_query({query: "<error or symptom>"})` — find execution flows related to the issue
2. `gitnexus_context({name: "<suspect function>"})` — see all callers, callees, and process participation
3. `READ gitnexus://repo/NeatEditor/process/{processName}` — trace the full execution flow step by step
4. For regressions: `gitnexus_detect_changes({scope: "compare", base_ref: "main"})` — see what your branch changed

## When Refactoring

- **Renaming**: MUST use `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` first. Review the preview — graph edits are safe, text_search edits need manual review. Then run with `dry_run: false`.
- **Extracting/Splitting**: MUST run `gitnexus_context({name: "target"})` to see all incoming/outgoing refs, then `gitnexus_impact({target: "target", direction: "upstream"})` to find all external callers before moving code.
- After any refactor: run `gitnexus_detect_changes({scope: "all"})` to verify only expected files changed.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Tools Quick Reference

| Tool | When to use | Command |
|------|-------------|---------|
| `query` | Find code by concept | `gitnexus_query({query: "auth validation"})` |
| `context` | 360-degree view of one symbol | `gitnexus_context({name: "validateUser"})` |
| `impact` | Blast radius before editing | `gitnexus_impact({target: "X", direction: "upstream"})` |
| `detect_changes` | Pre-commit scope check | `gitnexus_detect_changes({scope: "staged"})` |
| `rename` | Safe multi-file rename | `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` |
| `cypher` | Custom graph queries | `gitnexus_cypher({query: "MATCH ..."})` |

## Impact Risk Levels

| Depth | Meaning | Action |
|-------|---------|--------|
| d=1 | WILL BREAK — direct callers/importers | MUST update these |
| d=2 | LIKELY AFFECTED — indirect deps | Should test |
| d=3 | MAY NEED TESTING — transitive | Test if critical path |

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/NeatEditor/context` | Codebase overview, check index freshness |
| `gitnexus://repo/NeatEditor/clusters` | All functional areas |
| `gitnexus://repo/NeatEditor/processes` | All execution flows |
| `gitnexus://repo/NeatEditor/process/{name}` | Step-by-step execution trace |

## Self-Check Before Finishing

Before completing any code modification task, verify:
1. `gitnexus_impact` was run for all modified symbols
2. No HIGH/CRITICAL risk warnings were ignored
3. `gitnexus_detect_changes()` confirms changes match expected scope
4. All d=1 (WILL BREAK) dependents were updated

## Keeping the Index Fresh

After committing code changes, the GitNexus index becomes stale. Re-run analyze to update it:

```bash
npx gitnexus analyze
```

If the index previously included embeddings, preserve them by adding `--embeddings`:

```bash
npx gitnexus analyze --embeddings
```

To check whether embeddings exist, inspect `.gitnexus/meta.json` — the `stats.embeddings` field shows the count (0 means no embeddings). **Running analyze without `--embeddings` will delete any previously generated embeddings.**

> Claude Code users: A PostToolUse hook handles this automatically after `git commit` and `git merge`.

## CLI

- Re-index: `npx gitnexus analyze`
- Check freshness: `npx gitnexus status`
- Generate docs: `npx gitnexus wiki`

<!-- gitnexus:end -->
