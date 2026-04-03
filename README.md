# NeatEditor

[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-1f6feb)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-orange)](https://www.swift.org/)
[![UI](https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-0a7ea4)](https://developer.apple.com/xcode/swiftui/)
[![Project](https://img.shields.io/badge/Project-XcodeGen-6f42c1)](https://github.com/yonaskolb/XcodeGen)
[![License](https://img.shields.io/badge/License-MIT-green)](./LICENSE)

> A minimal macOS text editor focused on instant launch, dense content space, and native desktop interactions.
>
> 一个强调启动速度、屏幕利用率和原生桌面交互的极简 macOS 文本编辑器。

## Why NeatEditor

NeatEditor 的方向很明确：少一点 UI 干扰，多一点写作和编辑本身。

- 快速启动：尽量避免应用启动关键路径上的阻塞操作。
- 空间优先：让编辑区域成为主角，而不是被工具栏和面板切碎。
- 原生体验：保留 macOS 用户熟悉的标题栏、菜单命令、快捷键和窗口行为。
- 轻量纯文本：适合做快速记录、草稿、临时整理和轻量文本编辑。

## Highlights

- 多标签纯文本编辑，启动即创建可用文档。
- 标签切换、关闭、重命名都围绕低延迟交互设计。
- 支持系统“打开方式”、拖拽文件到窗口、粘贴文件 URL 打开本地文本。
- 内置行号 gutter、原生查找、撤销、输入法组合态处理和 `Command +/-` 缩放。
- 自动保存带 2 秒 debounce，并在切换标签、应用失焦或进入后台时保存。
- 支持标题栏图钉置顶、双击标题栏空白区域缩放窗口。
- 已落盘文档重命名时会同步处理磁盘文件名，保留扩展名编辑能力。
- 空白内容不会落盘覆盖现有文件，这是当前产品的明确设计选择。

## Current Status

NeatEditor 目前已经可以作为一个可用的 macOS 纯文本编辑器进行日常轻量使用，但它仍处于早期阶段。

- 平台目标：macOS 15.0+
- 技术栈：Swift 6, SwiftUI, AppKit bridge, Observation, XcodeGen
- 当前没有测试 target，主要依赖构建校验和手动验证
- 目前聚焦纯文本工作流，不包含富文本、插件系统或跨平台支持

如果你准备把它公开到 GitHub，这份仓库现在更适合被描述为“actively developed / pre-1.0”。

## Quick Start

### Requirements

- macOS 15.0+
- Xcode 16.2+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.44+

### Clone And Open

```bash
git clone <repo-url>
cd NeatEditor
xcodegen generate
open NeatEditor.xcodeproj
```

### Build From Terminal

```bash
xcodebuild -project "NeatEditor.xcodeproj" \
  -scheme "NeatEditor" \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  build
```

## Development Notes

- `project.yml` 是工程结构的真实来源；新增或删除源文件后请重新执行 `xcodegen generate`。
- 当前仓库没有测试 target，所以 `xcodebuild ... test` 目前不会通过。
- 如果你修改了运行流程、窗口行为或交互逻辑，建议用构建产物替换 `/Applications/NeatEditor.app` 后再验证。

## Project Structure

```text
NeatEditor/
├── project.yml
├── README.md
├── CONTRIBUTING.md
├── CHANGELOG.md
└── Sources/
    └── NeatEditor/
        ├── App/             # 应用入口、菜单命令、外部文件打开协调
        ├── Features/
        │   ├── Editor/      # AppKit bridge 编辑器、行号与缩放
        │   └── Workspace/   # 标签栏、工作区状态与主界面
        ├── Services/        # 自动保存与文档持久化
        ├── SharedUI/        # 共享样式与标题栏辅助视图
        ├── Resources/       # 本地化资源
        └── Assets.xcassets  # 图片资源
```

## Repository Docs

- [CONTRIBUTING.md](./CONTRIBUTING.md): 开发环境、提交流程和贡献建议
- [CHANGELOG.md](./CHANGELOG.md): 版本变更记录
- [TabStripGestures.md](./TabStripGestures.md): 标签栏点击和重命名交互的设计说明

## Known Gaps

这些点不影响公开仓库，但建议作为后续公开迭代目标：

- 补一张或一组实际运行截图，让 GitHub 首页第一眼更直观
- 增加测试 target，至少覆盖保存、重命名、恢复状态等核心流程
- 增加 release notes 和首个版本标签，例如 `v0.1.0`
- 根据公开协作需要补充 issue labels、GitHub Actions 或 release workflow

## Contributing

欢迎 issue、建议和 pull request。开始前请先阅读 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## License

NeatEditor is released under the [MIT License](./LICENSE).
