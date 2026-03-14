# NeatEditor

> 快速启动、充分利用屏幕空间的极简文本编辑器。

## 愿景

NeatEditor 的核心理念：**少即是多**。

- **快速启动** — 打开即用，零等待，不拖慢你的思路。
- **极致空间利用** — 摒弃多余的 UI 元素，让文字占据屏幕的每一寸。
- **专注于内容** — 界面退到幕后，写作者的注意力只属于文字本身。

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
