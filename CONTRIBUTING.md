# Contributing to NeatEditor

感谢你愿意关注或参与 NeatEditor。

## Development Environment

- macOS 15.0+
- Xcode 16.2+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.44+

## Setup

```bash
git clone <repo-url>
cd NeatEditor
xcodegen generate
open NeatEditor.xcodeproj
```

## Build

```bash
xcodebuild -project "NeatEditor.xcodeproj" \
  -scheme "NeatEditor" \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  build
```

## Analyze

```bash
xcodebuild -project "NeatEditor.xcodeproj" \
  -scheme "NeatEditor" \
  -configuration Debug \
  -destination 'platform=macOS' \
  analyze
```

## Tests

仓库当前还没有测试 target，因此 `xcodebuild ... test` 暂时不会通过。

如果你新增了测试，请同步更新 `project.yml`，确保 scheme 的 test action 生效。

## Contribution Guidelines

- 先读相关代码和上下文，再开始改动。
- 尽量保持改动聚焦，不把功能修复和大范围格式整理混在一起。
- 新增或删除源文件后，请重新执行 `xcodegen generate`。
- 变更完成后，至少保证一次成功构建。
- 如果改动影响窗口行为、命令菜单、保存流程或启动流程，请优先做实际运行验证。

## Coding Style

- 使用 4 空格缩进，UTF-8 + LF。
- 每个 `import` 单独一行，不保留未使用 import。
- 新代码优先使用 Swift 6 风格的并发与 Observation。
- 除非必要，不引入 `ObservableObject`、`@Published`、`@StateObject`、`@ObservedObject`。
- 不要新增 `!`、`try!`、`as!` 这类强制解包或强制转换。

## Pull Requests

提交 PR 时，建议在描述里写清楚：

- 改了什么
- 为什么要改
- 手动验证了什么
- 是否影响文档、快捷键、保存行为或窗口交互
