# Contributing to NeatEditor

Thank you for your interest in contributing to NeatEditor.

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

The repository does not currently have a test target, so `xcodebuild ... test` will not pass yet.

If you add tests, please also update `project.yml` so the scheme's test action is configured correctly.

## Contribution Guidelines

- Read the relevant code and surrounding context before making changes.
- Keep changes focused, and avoid mixing feature fixes with broad formatting cleanups.
- Re-run `xcodegen generate` after adding or removing source files.
- Make sure the project builds successfully at least once before finishing.
- If your changes affect window behavior, command menus, save flows, or startup behavior, prioritize a real app run for verification.

## Coding Style

- Use 4-space indentation with UTF-8 + LF line endings.
- Keep one `import` per line and remove unused imports.
- Prefer Swift 6-style concurrency and Observation in new code.
- Do not introduce `ObservableObject`, `@Published`, `@StateObject`, or `@ObservedObject` unless they are truly necessary.
- Avoid adding force unwraps or forced casts such as `!`, `try!`, or `as!`.

## Pull Requests

When opening a PR, please include:

- What changed
- Why the change was needed
- What you verified manually
- Whether the change affects documentation, keyboard shortcuts, save behavior, or window interactions
