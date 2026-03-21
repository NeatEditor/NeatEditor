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
- **标签切换、关闭与重命名**：支持无延迟切换当前标签，双击已选中标签标题可直接重命名；`Command + W` 可保存并关闭当前标签。
- **窗口交互控制**：双击标题栏空白区域可放大/缩小窗口（遵循系统设置）；支持通过标题栏图钉切换窗口置顶。
- **外部文件打开**：支持通过系统“打开方式”、拖拽文件到窗口、以及粘贴文件 URL 的方式打开本地文本文件；同一路径文件不会重复开标签。
- **行号编辑器**：编辑区内置行号 gutter，随文本和滚动位置实时刷新。
- **桌面端编辑体验**：支持撤销、macOS 原生查找面板、输入法组合态处理，以及 `Command +/-` 文本缩放。
- **搜索与导航**：`Command + F` 呼出内嵌搜索栏，按当前选区向后查找，找不到时会回绕到文档开头继续搜索。
- **自动保存**：输入停止 2 秒后自动保存；切换标签时会保存旧标签；应用进入 inactive/background 时会保存全部文档。
- **手动保存与快捷键**：支持 `Command + S` 保存当前文档，`Command + N` 新建文档，`Command + T` 新建标签。
- **本地文本落盘**：新文档首次保存若标题不含后缀，会默认写入 `~/Documents/<标题>.txt`；从外部打开的文件会沿用原路径并在标签上显示完整文件名；重命名已落盘文档时会按输入的完整文件名同步重命名磁盘文件，扩展名也可直接编辑。
- **空白文档保护**：纯空内容或仅包含空白字符的文档不会被写入磁盘；这是当前产品的有意设计，包括自动保存和手动保存都不会用空内容覆盖磁盘文件。
- **原生 macOS 窗口风格**：隐藏标题栏，保留简洁的标签栏与编辑区域布局，并支持通过标题栏图钉切换窗口置顶。

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

命令行构建校验：

```bash
xcodebuild -project "NeatEditor.xcodeproj" -scheme "NeatEditor" -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData build
```

## 项目结构

```
NeatEditor/
├── project.yml              # XcodeGen 配置
├── README.md
└── Sources/
    └── NeatEditor/
        ├── App/             # 应用入口、菜单命令、外部文件打开协调
        ├── Features/
        │   ├── Editor/      # AppKit bridge 编辑器、行号与缩放
        │   └── Workspace/   # 标签栏、工作区状态与主界面
        ├── Services/        # 自动保存与文档持久化
        ├── SharedUI/        # 共享样式与标题栏辅助视图
        └── Assets.xcassets  # 图片资源
```

## License

MIT
