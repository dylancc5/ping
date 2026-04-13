---
name: swift-package-manager
version: 1.0.0
description: Swift Package Manager (SPM) for iOS/macOS — creating packages, adding dependencies, managing versions, local packages, and binary targets. Use when adding third-party libraries, creating shared modules, or structuring a multi-package app.
---

# Swift Package Manager Skill

Manage dependencies and modularize iOS/macOS apps using Swift Package Manager.

---

## Adding Dependencies to an Xcode Project

### Via Xcode UI

1. File → Add Package Dependencies
2. Paste the package URL (e.g., `https://github.com/pointfreeco/swift-composable-architecture`)
3. Choose version rule → Add Package
4. Select target(s) to link the library

### Via Package.swift (for Swift packages)

```swift
// Package.swift
let package = Package(
    name: "MyPackage",
    platforms: [.iOS(.v17), .macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/onevcat/Kingfisher", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "MyFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Kingfisher", package: "Kingfisher"),
            ]
        ),
    ]
)
```

---

## Version Rules

| Rule | Syntax | Behavior |
|------|--------|---------|
| From (minimum) | `.from("1.2.0")` | `>= 1.2.0`, `< 2.0.0` (next major) |
| Exact | `.exact("1.2.3")` | Pinned to exact version |
| Range | `"1.0.0"..<"2.0.0"` | Any version in range |
| Branch | `.branch("main")` | Latest commit on branch (use with caution) |
| Revision | `.revision("abc1234")` | Specific git SHA |

**Recommended:** Use `.from("x.y.z")` for stable packages that follow semver.

---

## Creating a Swift Package

### Initialize

```bash
# Library package
swift package init --name MyLibrary --type library

# Executable
swift package init --name MyCLI --type executable
```

### Package.swift anatomy

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SharedUI",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        // What this package exposes
        .library(name: "SharedUI", targets: ["SharedUI"]),
        .library(name: "SharedUITestHelpers", targets: ["SharedUITestHelpers"]),
    ],
    dependencies: [
        // External dependencies
        .package(url: "https://github.com/onevcat/Kingfisher", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "SharedUI",
            dependencies: [
                .product(name: "Kingfisher", package: "Kingfisher"),
            ],
            resources: [
                .process("Resources/"),  // images, fonts, etc.
            ]
        ),
        .target(
            name: "SharedUITestHelpers",
            dependencies: ["SharedUI"]
        ),
        .testTarget(
            name: "SharedUITests",
            dependencies: ["SharedUI", "SharedUITestHelpers"]
        ),
    ]
)
```

---

## Local Packages

Use local packages to modularize a large app without publishing to GitHub.

### Setup

```
MyApp/
├── MyApp.xcodeproj
├── MyApp/
└── Packages/
    ├── SharedUI/
    │   ├── Package.swift
    │   └── Sources/SharedUI/
    ├── Domain/
    │   ├── Package.swift
    │   └── Sources/Domain/
    └── Networking/
        ├── Package.swift
        └── Sources/Networking/
```

### Reference local packages in Xcode

In Xcode: File → Add Package Dependencies → click "Add Local..." → select the package folder.

Or in another `Package.swift`:

```swift
dependencies: [
    .package(path: "../SharedUI"),
    .package(path: "../Domain"),
],
```

### Benefits of local packages

- Enforces explicit dependency boundaries (compile-time)
- Faster incremental builds (only changed packages rebuild)
- Reusable across multiple app targets
- Easy to extract to a separate repo later

---

## Resources in Packages

```swift
.target(
    name: "SharedUI",
    resources: [
        .process("Resources/"),   // processed (images optimized, .strings compiled)
        .copy("Static/"),         // copied as-is
    ]
)
```

Access in code:

```swift
// Images
let image = UIImage(named: "logo", in: .module, compatibleWith: nil)
Image("logo", bundle: .module)  // SwiftUI

// Files
let url = Bundle.module.url(forResource: "config", withExtension: "json")!
```

---

## Binary Targets (XCFrameworks)

For closed-source SDKs distributed as `.xcframework`:

```swift
.binaryTarget(
    name: "Segment",
    url: "https://github.com/segmentio/analytics-swift/releases/download/1.5.0/Segment.xcframework.zip",
    checksum: "abc123..."  // SHA256 of the zip
)

// Or local:
.binaryTarget(
    name: "ClosedSourceSDK",
    path: "Frameworks/ClosedSourceSDK.xcframework"
)
```

Generate checksum:
```bash
swift package compute-checksum Segment.xcframework.zip
```

---

## Key SPM CLI Commands

```bash
# Resolve dependencies (fetch Package.resolved)
swift package resolve

# Update all packages to latest allowed versions
swift package update

# Update a specific package
swift package update Kingfisher

# Show dependency graph
swift package show-dependencies

# Build
swift build
swift build -c release

# Test
swift test
swift test --filter MyTests

# Clean build artifacts
swift package clean

# Reset (removes .build and Package.resolved)
swift package reset

# Generate Xcode project (rarely needed with modern Xcode)
swift package generate-xcodeproj
```

---

## Package.resolved

- **Commit `Package.resolved`** to version control — ensures reproducible builds for all team members
- **Never manually edit** `Package.resolved`
- It gets updated automatically when you run `swift package update` or change dependencies

---

## Popular iOS Packages by Category

### Networking
- `Alamofire/Alamofire` — HTTP networking
- `kean/Get` — lightweight async/await HTTP client

### Image Loading
- `onevcat/Kingfisher` — SwiftUI + UIKit image loading/caching

### Architecture
- `pointfreeco/swift-composable-architecture` — TCA
- `pointfreeco/swift-dependencies` — dependency injection

### Database / Persistence
- `groue/GRDB.swift` — SQLite with Swift idioms
- `realm/realm-swift` — Realm mobile database

### UI / Animation
- `exyte/PopupView` — SwiftUI popups
- `airbnb/lottie-ios` — Lottie animations

### Testing
- `pointfreeco/swift-snapshot-testing` — snapshot tests
- `nicklockwood/SwiftFormat` — code formatting

### Utilities
- `apple/swift-collections` — OrderedDictionary, Deque, etc.
- `apple/swift-algorithms` — sequence/collection algorithms
- `apple/swift-async-algorithms` — async sequence algorithms

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Package resolution failed" | File → Packages → Reset Package Caches |
| Outdated `Package.resolved` conflict | Accept incoming (if CI), or run `swift package update` |
| Missing package after checkout | Run `swift package resolve` |
| "No such module" after adding package | Ensure product is linked to correct target in Xcode |
| Build fails with binary target | Verify checksum matches, re-download |
| Slow package resolution | Check network, use `--disable-automatic-resolution` in CI if pinned |
