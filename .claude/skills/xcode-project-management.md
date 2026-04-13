---
name: xcode-project-management
version: 1.0.0
description: Xcode project setup, build configuration, schemes, targets, signing, and CI/CD for iOS/macOS apps. Use when setting up a new project, managing build settings, troubleshooting Xcode issues, or configuring automation.
---

# Xcode Project Management Skill

Set up, configure, and maintain Xcode projects for professional iOS/macOS development.

---

## New Project Setup Checklist

### 1. Project Structure

After creating a new Xcode project, organize immediately:

```
MyApp/
├── MyApp.xcodeproj (or .xcworkspace if using CocoaPods)
├── MyApp/
│   ├── App/
│   │   ├── MyApp.swift          # @main entry point
│   │   └── AppDelegate.swift    # if needed
│   ├── Features/                # Feature folders
│   ├── Services/                # Business logic / networking
│   ├── Models/                  # Domain models
│   ├── UI/                      # Shared components
│   ├── Extensions/
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   ├── Localizable.strings
│   │   └── Info.plist
│   └── Supporting Files/
├── MyAppTests/
├── MyAppUITests/
└── Packages/                    # Local Swift packages
```

### 2. Build Settings to Configure First

| Setting | Recommended Value |
|---------|-------------------|
| Deployment Target | Match your minimum supported iOS version |
| Swift Language Version | Swift 6 (or 5 if not ready) |
| Debug Information Format | DWARF with dSYM (Release only) |
| Enable Testability | Yes (Debug only) |
| Treat Warnings as Errors | Yes (for CI) |
| Swift Strict Concurrency | `complete` (Swift 6) |

### 3. Configurations

Always have at least three configurations:

```
Debug       → local development, verbose logging, mock data
Staging     → connects to staging backend, TestFlight
Release     → production, App Store
```

Add via: Project → Info tab → Configurations → "+"

Use `.xcconfig` files to manage per-configuration settings:

```
// Configs/Debug.xcconfig
API_BASE_URL = https://staging.api.example.com
ENABLE_LOGGING = YES
BUNDLE_ID_SUFFIX = .debug

// Configs/Release.xcconfig
API_BASE_URL = https://api.example.com
ENABLE_LOGGING = NO
BUNDLE_ID_SUFFIX =
```

Reference in build settings: `$(API_BASE_URL)`

Access in code:
```swift
let baseURL = Bundle.main.infoDictionary?["API_BASE_URL"] as? String ?? ""
```

---

## Targets

### Multiple Targets Strategy

| Target | Purpose |
|--------|---------|
| `MyApp` | Main app |
| `MyAppTests` | Unit tests |
| `MyAppUITests` | UI tests |
| `MyAppWidget` | Widget extension |
| `MyAppNotificationService` | Notification service extension |
| `MyAppShare` | Share extension |

**Shared code between targets:** Extract into a local Swift Package or framework target rather than adding source files to multiple targets.

### Adding an Extension Target

1. File → New → Target → choose extension type
2. Set deployment target to match main app
3. Add shared code via local package dependency
4. Configure App Group for data sharing:
   ```swift
   // Shared UserDefaults
   let defaults = UserDefaults(suiteName: "group.com.example.myapp")

   // Shared file storage
   let containerURL = FileManager.default
       .containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.myapp")
   ```

---

## Schemes

### Scheme Setup for Each Environment

Create one scheme per configuration:

- `MyApp (Debug)` → Debug configuration, runs on simulator
- `MyApp (Staging)` → Staging configuration, for TestFlight builds
- `MyApp (Release)` → Release configuration, for App Store

**Scheme settings to configure:**
- Run → Build Configuration
- Test → Code Coverage enabled
- Archive → Release configuration, correct provisioning profile

### Launch Arguments & Environment Variables

In scheme Run → Arguments, add:
```
-com.apple.CoreData.SQLDebug 1       # CoreData SQL logging
-UIViewLayoutFeedbackLoopDebuggingThreshold 100  # Layout loop detection
```

Environment Variables:
```
CFNETWORK_DIAGNOSTICS = 1            # Network logging
```

---

## Code Signing

### Automatic vs Manual

| Scenario | Recommended |
|----------|-------------|
| Development / personal | Automatic signing |
| CI/CD, team, enterprise | Manual signing with fastlane match |

### fastlane match setup

```bash
# Initialize match
bundle exec fastlane match init

# Generate/sync certificates and profiles
bundle exec fastlane match development
bundle exec fastlane match appstore

# In CI (readonly mode)
bundle exec fastlane match appstore --readonly
```

`Matchfile`:
```ruby
git_url("https://github.com/your-org/certificates")
storage_mode("git")
type("appstore")
app_identifier(["com.example.myapp", "com.example.myapp.widget"])
username("apple-id@example.com")
```

---

## Build Automation with fastlane

### Fastfile structure

```ruby
# fastlane/Fastfile

default_platform(:ios)

platform :ios do
  before_all do
    ensure_git_status_clean
  end

  lane :test do
    run_tests(
      scheme: "MyApp",
      devices: ["iPhone 16 Pro"],
      code_coverage: true
    )
  end

  lane :beta do
    increment_build_number(
      build_number: latest_testflight_build_number + 1
    )
    match(type: "appstore", readonly: true)
    build_app(
      scheme: "MyApp (Staging)",
      configuration: "Staging",
      export_method: "app-store"
    )
    upload_to_testflight(skip_waiting_for_build_processing: true)
  end

  lane :release do
    match(type: "appstore", readonly: true)
    build_app(scheme: "MyApp (Release)", configuration: "Release")
    upload_to_app_store
  end
end
```

---

## Xcode Build Performance

### Speed up builds

1. **Enable parallel builds**: Product → Scheme → Build → check "Parallelize Build"
2. **Reduce module rebuilds**: Use `@_implementationOnly` for internal imports
3. **Explicit module builds**: `OTHER_SWIFT_FLAGS = -experimental-explicit-module-build`
4. **Preview support**: Keep `#Preview` out of production paths
5. **Clean DerivedData when stuck**:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

### xcodebuild commands

```bash
# Build
xcodebuild -project MyApp.xcodeproj -scheme "MyApp" -configuration Debug build

# Test
xcodebuild test -project MyApp.xcodeproj -scheme "MyApp" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro"

# Archive
xcodebuild archive -project MyApp.xcodeproj -scheme "MyApp" \
  -configuration Release \
  -archivePath build/MyApp.xcarchive

# Export IPA
xcodebuild -exportArchive \
  -archivePath build/MyApp.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/
```

---

## Common Issues & Fixes

| Issue | Fix |
|-------|-----|
| "No such module 'X'" | Clean build folder, check target membership |
| Provisioning profile mismatch | Run `match` again, or re-download profiles in Xcode |
| "Simulator not found" | `xcrun simctl list devices` to find exact name |
| Slow indexing | Delete DerivedData, disable "Index while building" in settings |
| Swift package resolution failure | File → Packages → Reset Package Caches |
| Code signing identity not found | Check Keychain Access for valid cert, run `security find-identity -v` |

---

## CI/CD Configuration (GitHub Actions)

```yaml
# .github/workflows/ios.yml
name: iOS CI

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app

      - name: Cache SPM
        uses: actions/cache@v4
        with:
          path: .build
          key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}

      - name: Run Tests
        run: |
          xcodebuild test \
            -project MyApp.xcodeproj \
            -scheme "MyApp" \
            -destination "platform=iOS Simulator,name=iPhone 16 Pro,OS=18.0" \
            -resultBundlePath TestResults.xcresult

      - name: Upload Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: TestResults.xcresult
```

---

## .gitignore for Xcode Projects

```gitignore
# Xcode
*.xcworkspace/xcuserdata/
*.xcodeproj/xcuserdata/
*.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
build/
DerivedData/

# Swift Package Manager
.build/
.swiftpm/

# fastlane
fastlane/report.xml
fastlane/Preview.html
fastlane/screenshots/**/*.png
fastlane/test_output

# Secrets (NEVER commit these)
*.p12
*.mobileprovision
.env
Secrets.xcconfig
```
