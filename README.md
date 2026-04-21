# UIMole

**UIMole** is the SwiftUI graphical interface (GUI) for the [Mole](https://github.com/tw93/Mole) project — a command-line tool for developers.

This project aims to expose, in a native macOS experience, every feature available in the Mole CLI, making them accessible through a visual interface.

> **UIMole is not a replacement for Mole.** It is an addition — a complement to this fantastic piece of software — built to bring the same free and open-source experience to users who are not comfortable with command lines and terminals. All credit for the underlying functionality belongs to [Mole](https://github.com/tw93/Mole) and its contributors.

## About the project

- **Platform:** macOS 15.6+
- **Stack:** SwiftUI
- **Reference CLI:** [tw93/Mole](https://github.com/tw93/Mole) (embedded in the app bundle)
- **License:** MIT (open-source)
- **Distribution:** source-only for now — clone and run locally. Packaged distribution (Developer ID + notarized `.dmg`) is planned but not yet available.

All features are developed with automated test coverage.

### Why not the Mac App Store

UIMole wraps the Mole CLI, which performs disk cleanup across locations outside any single app's sandbox container (Xcode DerivedData, package-manager caches, system temp, etc.). The Mac App Store sandbox does not permit that level of file access, and it also forbids shipping and `exec`-ing a bundled helper binary. Every comparable macOS cleanup tool (CleanMyMac X, OnyX, DaisyDisk, Parallels Toolbox) ships outside the MAS for the same reason, so UIMole will too once packaged releases start shipping.

## Requirements

- macOS 15.6 or later
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- [SwiftLint](https://github.com/realm/SwiftLint) — `brew install swiftlint`

## Setup

After cloning the repository:

```bash
cp Config/Development.xcconfig.template Config/Development.xcconfig
cp Config/Production.xcconfig.template Config/Production.xcconfig
# edit both files with your own DEVELOPMENT_TEAM and BUNDLE_ID_PREFIX

./Scripts/fetch-mole.sh   # downloads and assembles the universal Mole binary
xcodegen generate
open UIMole.xcodeproj
```

Whenever you add, remove, or rename source files, run `xcodegen generate` again to keep the project in sync.

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.
