# NeatEditor

[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-1f6feb)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-orange)](https://www.swift.org/)
[![UI](https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-0a7ea4)](https://developer.apple.com/xcode/swiftui/)
[![Project](https://img.shields.io/badge/Project-XcodeGen-6f42c1)](https://github.com/yonaskolb/XcodeGen)
[![License](https://img.shields.io/badge/License-MIT-green)](./LICENSE)

> 一个极简、快速启动的 macOS 纯文本编辑器，基于 SwiftUI 与 AppKit 构建，专注无干扰写作、原生桌面交互和高效多标签编辑。

[English README](./README.md)

## 为什么是 NeatEditor

NeatEditor 的目标很直接：减少界面噪音，把注意力还给文字本身。

- 快速启动：尽量避免在应用启动路径上做阻塞操作。
- 空间优先：让编辑区域成为主角，而不是被界面装饰分散注意力。
- 原生体验：保留 macOS 用户熟悉的标题栏、菜单、快捷键和窗口行为。
- 纯文本专注：适合做笔记、草稿、临时整理和轻量编辑。

## 主要特性

- 多标签纯文本编辑，启动即创建可用文档。
- 标签切换、关闭、重命名都围绕低延迟交互设计。
- 支持通过 Finder、拖拽和粘贴文件 URL 打开本地文本文件。
- 内置行号 gutter、原生查找、撤销、输入法组合态处理，以及 `Command +/-` 缩放。
- 自动保存带 2 秒 debounce，并会在切换标签和应用失焦时保存。
- 支持窗口置顶以及标题栏空白区域双击缩放窗口。
- 已落盘文档重命名时会同步处理磁盘文件名，并允许编辑扩展名。
- 空白内容不会覆盖已有文件，这是当前产品的明确设计选择。

## 当前状态

NeatEditor 现在已经可以作为一个轻量 macOS 纯文本编辑器使用，并以 `1.0.0` 版本公开发布。

- 平台目标：macOS 15.0+
- 技术栈：Swift 6、SwiftUI、AppKit bridge、Observation、XcodeGen
- 当前验证方式：构建校验和手动测试
- 当前范围：专注纯文本，不包含富文本、插件系统或跨平台支持

## 快速开始

### 环境要求

- macOS 15.0+
- Xcode 16.2+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.44+

### 克隆并打开

```bash
git clone <repo-url>
cd NeatEditor
xcodegen generate
open NeatEditor.xcodeproj
```

### 终端构建

```bash
xcodebuild -project "NeatEditor.xcodeproj" \
  -scheme "NeatEditor" \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  build
```

## 开发说明

- `project.yml` 是工程结构的真实来源。
- 新增或删除源文件后，请重新执行 `xcodegen generate`。
- 仓库目前没有测试 target，所以 `xcodebuild ... test` 尚未配置。
- 如果你修改了运行流程或交互逻辑，优先用构建产物进行实际验证。

## 发布版本

仓库已经配置了基于 Git tag 的 GitHub Releases 自动流程。

- 推送 `v1.0.0` 这样的 tag 后，GitHub Actions 会自动构建 release。
- 工作流会生成一个 macOS universal zip。
- Release 页面还会附带 `SHA256SUMS.txt`。

最简单的发版方式：

```bash
git tag v1.0.0
git push origin v1.0.0
```

更完整的说明见 [RELEASING.md](./RELEASING.md)。

## 仓库文档

- [README.md](./README.md)：英文主 README
- [CONTRIBUTING.md](./CONTRIBUTING.md)：贡献和开发说明
- [CHANGELOG.md](./CHANGELOG.md)：版本变更记录
- [RELEASING.md](./RELEASING.md)：GitHub Release 流程
- [TabStripGestures.md](./TabStripGestures.md)：标签栏交互设计说明

## 已知后续改进方向

- 补运行截图或演示 GIF，提升 GitHub 首页第一印象。
- 增加测试 target，覆盖保存、重命名、恢复状态等核心流程。
- 增加 Apple 签名、公证和 DMG 打包，降低用户下载后的安全提示成本。
- 增加常规 CI workflow，覆盖 push 和 pull request。

## 参与贡献

欢迎 issue、建议和 pull request，开始前请先阅读 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## 许可证

NeatEditor 使用 [MIT License](./LICENSE) 开源。
