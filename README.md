# NeatEditor

[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-1f6feb)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-orange)](https://www.swift.org/)
[![UI](https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-0a7ea4)](https://developer.apple.com/xcode/swiftui/)
[![Project](https://img.shields.io/badge/Project-XcodeGen-6f42c1)](https://github.com/yonaskolb/XcodeGen)
[![License](https://img.shields.io/badge/License-MIT-green)](./LICENSE)

> A minimal, fast-launching macOS plain text editor built with SwiftUI and AppKit for distraction-free writing, native desktop interactions, and efficient multi-tab editing.

**Languages:** [English](./README.md) | [简体中文](./README.zh-CN.md) | [日本語](./README.ja.md) | [한국어](./README.ko.md) | [Español](./README.es.md) | [Français](./README.fr.md) | [Deutsch](./README.de.md)

## Screenshot

<p align="center">
  <img src="./docs/images/neateditor-main-window.png" alt="NeatEditor screenshot showing the main writing workspace on macOS" width="1201" />
</p>

## Why NeatEditor

NeatEditor is built around a simple goal: reduce interface noise and keep your attention on the text.

- Fast launch: avoid unnecessary blocking work on the app startup path.
- Space-first UI: keep the editor surface front and center instead of surrounding it with chrome.
- Native macOS behavior: preserve familiar title bar, menus, shortcuts, and window interactions.
- Plain-text focus: ideal for notes, drafts, scratch writing, and lightweight editing.

## Highlights

- Multi-tab plain text editing with a ready-to-use document on launch.
- Low-latency tab selection, closing, and in-place renaming.
- Open local text files through Finder, drag and drop, or pasted file URLs.
- Built-in line numbers, native find, undo, IME composition handling, and `Command +/-` zooming.
- Debounced autosave plus save-on-tab-switch and save-on-app-deactivation behavior.
- Pin-to-top window support and native title bar double-click zoom behavior.
- Disk-backed rename behavior that preserves editable file extensions.
- Blank content never overwrites existing files by design.

## Current Status

NeatEditor is ready to use as a lightweight macOS plain text editor and is now being published as `1.0.0`.

- Platform target: macOS 15.0+
- Stack: Swift 6, SwiftUI, AppKit bridge, Observation, XcodeGen
- Validation today: build verification and manual testing
- Scope today: plain text workflow, no rich text, plugins, or cross-platform support

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

- `project.yml` is the source of truth for the project structure.
- Run `xcodegen generate` after adding or removing source files.
- The repository does not yet include a test target, so `xcodebuild ... test` is not configured.
- For behavior changes, prefer validating with the built app rather than relying on previews alone.

## Releases

This repository includes a tag-driven GitHub Releases workflow.

- Push a tag like `v1.0.0` and GitHub Actions will build the release automatically.
- The workflow produces a macOS universal zip.
- The release also includes `SHA256SUMS.txt`.

The simplest release flow is:

```bash
git tag v1.0.0
git push origin v1.0.0
```

See [RELEASING.md](./RELEASING.md) for details.

## Project Structure

```text
NeatEditor/
├── docs/
│   └── images/
│       └── neateditor-main-window.png
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

- [README.ja.md](./README.ja.md): Japanese overview
- [README.ko.md](./README.ko.md): Korean overview
- [README.es.md](./README.es.md): Spanish overview
- [README.fr.md](./README.fr.md): French overview
- [README.de.md](./README.de.md): German overview
- [README.zh-CN.md](./README.zh-CN.md): Simplified Chinese overview
- [CONTRIBUTING.md](./CONTRIBUTING.md): development environment and contribution notes
- [CHANGELOG.md](./CHANGELOG.md): project release history
- [RELEASING.md](./RELEASING.md): tag-driven GitHub Release workflow
- [TabStripGestures.md](./TabStripGestures.md): design notes for tab click and rename interactions

## Known Gaps

These are reasonable next steps after the initial public release:

- Add a test target for save, rename, and state restoration flows.
- Add Apple code signing, notarization, and DMG packaging for smoother distribution.
- Add a general CI workflow for pushes and pull requests.

## Contributing

Issues, suggestions, and pull requests are welcome. Please read [CONTRIBUTING.md](./CONTRIBUTING.md) first.

## License

NeatEditor is released under the [MIT License](./LICENSE).
