# NeatEditor

[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-1f6feb)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-orange)](https://www.swift.org/)
[![UI](https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-0a7ea4)](https://developer.apple.com/xcode/swiftui/)
[![Project](https://img.shields.io/badge/Project-XcodeGen-6f42c1)](https://github.com/yonaskolb/XcodeGen)
[![License](https://img.shields.io/badge/License-MIT-green)](./LICENSE)

> SwiftUI와 AppKit으로 만든, 빠르게 실행되는 미니멀한 macOS용 일반 텍스트 편집기입니다. 방해 없는 글쓰기, macOS다운 상호작용, 효율적인 멀티 탭 편집에 집중합니다.

**언어:** [English](./README.md) | [简体中文](./README.zh-CN.md) | [日本語](./README.ja.md) | [한국어](./README.ko.md) | [Español](./README.es.md) | [Français](./README.fr.md) | [Deutsch](./README.de.md)

## 스크린샷

<p align="center">
  <img src="./docs/images/neateditor-main-window.png" alt="NeatEditor 메인 작업 공간" width="1201" />
</p>

## 왜 NeatEditor인가

NeatEditor는 인터페이스의 소음을 줄이고 사용자의 집중을 다시 텍스트 자체로 돌리는 것을 목표로 합니다.

- 빠른 실행: 앱 시작 경로에서 불필요한 블로킹 작업을 피합니다.
- 공간 중심 UI: 주변 장식보다 편집 영역을 중심에 둡니다.
- macOS다운 동작: 제목 표시줄, 메뉴, 단축키, 창 상호작용을 자연스럽게 유지합니다.
- 일반 텍스트 중심: 메모, 초안, 임시 정리, 가벼운 편집에 적합합니다.

## 주요 특징

- 실행 즉시 사용할 수 있는 문서를 포함한 멀티 탭 일반 텍스트 편집.
- 탭 선택, 닫기, 인라인 이름 변경을 낮은 지연으로 처리.
- Finder, 드래그 앤 드롭, 파일 URL 붙여넣기로 로컬 텍스트 파일 열기 지원.
- 줄 번호, 네이티브 찾기, 실행 취소, IME 조합 입력 처리, `Command +/-` 확대/축소 제공.
- 2초 debounce 자동 저장과 탭 전환 시, 앱 비활성화 시 저장.
- 항상 위에 고정하는 핀과 제목 표시줄 더블클릭 줌 동작 지원.
- 저장된 문서를 이름 변경할 때 디스크의 파일명도 확장자를 유지한 채 함께 변경.
- 공백뿐인 내용은 기존 파일을 덮어쓰지 않도록 설계되어 있습니다.

## 현재 상태

NeatEditor는 가벼운 macOS 일반 텍스트 편집기로 이미 사용할 수 있으며 `1.0.0`으로 공개되고 있습니다.

- 대상 플랫폼: macOS 15.0+
- 기술 스택: Swift 6, SwiftUI, AppKit bridge, Observation, XcodeGen
- 현재 검증 방식: 빌드 확인 및 수동 테스트
- 현재 범위: 일반 텍스트 워크플로우 중심, 서식 있는 텍스트와 플러그인, 크로스 플랫폼 지원은 제외

## 빠른 시작

### 요구 사항

- macOS 15.0+
- Xcode 16.2+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.44+

### 클론 후 열기

```bash
git clone <repo-url>
cd NeatEditor
xcodegen generate
open NeatEditor.xcodeproj
```

### 터미널에서 빌드

```bash
xcodebuild -project "NeatEditor.xcodeproj" \
  -scheme "NeatEditor" \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  build
```

## 개발 메모

- `project.yml`이 프로젝트 구조의 기준입니다.
- 소스 파일을 추가하거나 삭제한 뒤에는 `xcodegen generate`를 실행하세요.
- 현재는 테스트 target이 없어서 `xcodebuild ... test`가 구성되어 있지 않습니다.
- 동작 변경을 확인할 때는 미리보기만 보지 말고 실제 빌드한 앱으로 검증하는 편이 좋습니다.

## 릴리스

이 저장소에는 태그 기반 GitHub Releases 워크플로가 포함되어 있습니다.

- `v1.0.0` 같은 태그를 푸시하면 GitHub Actions가 릴리스를 자동으로 빌드합니다.
- 워크플로는 macOS universal zip을 생성합니다.
- 릴리스에는 `SHA256SUMS.txt`도 포함됩니다.

가장 단순한 릴리스 흐름:

```bash
git tag v1.0.0
git push origin v1.0.0
```

자세한 내용은 [RELEASING.md](./RELEASING.md)를 참고하세요.

## 저장소 문서

- [README.md](./README.md): 영어 README
- [README.zh-CN.md](./README.zh-CN.md): 중국어 간체 README
- [README.ja.md](./README.ja.md): 일본어 README
- [README.es.md](./README.es.md): 스페인어 README
- [README.fr.md](./README.fr.md): 프랑스어 README
- [README.de.md](./README.de.md): 독일어 README
- [CONTRIBUTING.md](./CONTRIBUTING.md): 개발 환경과 기여 안내
- [CHANGELOG.md](./CHANGELOG.md): 릴리스 이력
- [RELEASING.md](./RELEASING.md): GitHub Release 흐름
- [TabStripGestures.md](./TabStripGestures.md): 탭 상호작용 설계 메모

## 다음 개선 후보

- 저장, 이름 변경, 상태 복원을 다루는 테스트 target 추가.
- Apple 서명, 공증, DMG 패키징을 추가해 배포 경험 개선.
- push와 pull request를 위한 일반적인 CI 워크플로 추가.

## 기여

이슈, 제안, Pull Request를 환영합니다. 먼저 [CONTRIBUTING.md](./CONTRIBUTING.md)를 읽어 주세요.

## 라이선스

NeatEditor는 [MIT License](./LICENSE)로 배포됩니다.
