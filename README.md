# NeatEditor

> 快速启动、充分利用屏幕空间的极简文本编辑器。

## 愿景

NeatEditor 的核心理念：**少即是多**。

- **快速启动** — 打开即用，零等待，不拖慢你的思路。
- **极致空间利用** — 摒弃多余的 UI 元素，让文字占据屏幕的每一寸。
- **专注于内容** — 界面退到幕后，写作者的注意力只属于文字本身。

## 当前已实现功能

- **多标签纯文本编辑**：启动后自动创建一个新文档标签，支持同时维护多个文本标签页。
- **自动命名未命名文档**：新标签会按 `Untitled N` 递增命名，并结合当前打开标签与 `~/Documents` 目录中的已有文件避免重名。
- **标签切换与重命名**：支持切换当前编辑标签，双击标签标题可直接重命名。
- **行号编辑器**：编辑区内置行号 gutter，随文本和滚动位置实时刷新。
- **桌面端编辑体验**：使用等宽字体，支持撤销，以及 macOS 原生查找面板。
- **自动保存**：输入停止 2 秒后自动保存；切换标签时会保存旧标签；应用进入 inactive/background 时会保存全部文档。
- **手动保存与快捷键**：支持 `Command + S` 保存当前文档，`Command + N` 新建文档，`Command + T` 新建标签。
- **本地文本落盘**：文档会保存为纯文本 `.txt` 文件；首次保存默认写入 `~/Documents/<标题>.txt`，后续保存沿用原路径。
- **空白文档保护**：纯空内容或仅包含空白字符的文档不会被写入磁盘；这是当前产品的有意设计，包括自动保存和手动保存都不会用空内容覆盖磁盘文件。
- **原生 macOS 窗口风格**：隐藏标题栏，保留简洁的标签栏与编辑区域布局。

## 技术栈

| 项目 | 版本 |
|------|------|
| 平台 | macOS 15.0+ |
| 语言 | Swift 6 |
| UI 框架 | SwiftUI |
| 项目管理 | XcodeGen |

## 开发环境

- Xcode 16.2+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.44+

## 快速开始

```bash
# 克隆仓库
git clone <repo-url>
cd NeatEditor

# 生成 Xcode 项目
xcodegen generate

# 用 Xcode 打开
open NeatEditor.xcodeproj
```

## 项目结构

```
NeatEditor/
├── project.yml              # XcodeGen 配置
├── README.md
└── Sources/
    └── NeatEditor/
        ├── App/             # 应用入口
        ├── Views/           # SwiftUI 视图
        ├── Models/          # 数据模型
        └── Assets.xcassets  # 图片资源
```

## License

MIT
