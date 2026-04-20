# UIMole

**UIMole** is the SwiftUI graphical interface (GUI) for the [Mole](https://github.com/tw93/Mole) project — a command-line tool for developers.

This project aims to expose, in a native macOS experience, every feature available in the Mole CLI, making them accessible through a visual interface.

> **UIMole is not a replacement for Mole.** It is an addition — a complement to this fantastic piece of software — built to bring the same free and open-source experience to users who are not comfortable with command lines and terminals. All credit for the underlying functionality belongs to [Mole](https://github.com/tw93/Mole) and its contributors.

## About the project

- **Platform:** macOS 15.6+
- **Stack:** SwiftUI
- **Reference CLI:** [tw93/Mole](https://github.com/tw93/Mole) (also available locally at `../open-mole/`)
- **License:** MIT (open-source)
- **Distribution:** will be published on the Mac App Store

All features are developed with automated test coverage.

## Requirements

- macOS 15.6 or later
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- [SwiftLint](https://github.com/realm/SwiftLint) — `brew install swiftlint`

## Setup

After cloning the repository, generate the Xcode project with XcodeGen:

```bash
xcodegen generate
open UIMole.xcodeproj
```

Whenever you add, remove, or rename source files, run `xcodegen generate` again to keep the project in sync.

## Structure

```
open-ui-mole/
├── UIMole/              # SwiftUI app
├── UIMoleTests/         # Unit tests
├── UIMoleUITests/       # UI tests
├── project.yml          # XcodeGen configuration
└── .swiftlint.yml       # SwiftLint rules
```

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.
