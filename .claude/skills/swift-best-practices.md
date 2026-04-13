---
name: swift-best-practices
version: 1.0.0
description: Swift language best practices for iOS/macOS development — concurrency, memory management, error handling, type safety, and performance. Use when writing or reviewing Swift code.
---

# Swift Best Practices Skill

Write idiomatic, safe, and performant Swift code following Apple platform conventions.

---

## Concurrency (Swift Concurrency / async-await)

### Always use structured concurrency

```swift
// Good: structured, cancellation propagates automatically
func loadData() async throws -> [Item] {
    async let profile = fetchProfile()
    async let items = fetchItems()
    return try await (profile, items).1 // parallel fetches
}

// Avoid: unstructured Task { } unless you need fire-and-forget
```

### Actor isolation for shared mutable state

```swift
actor DataCache {
    private var cache: [String: Data] = [:]

    func get(_ key: String) -> Data? { cache[key] }
    func set(_ key: String, value: Data) { cache[key] = value }
}

// Caller always awaits
let data = await cache.get("profile")
```

### `@MainActor` for UI updates

```swift
@MainActor
class ViewModel: ObservableObject {
    @Published var items: [Item] = []

    func load() async {
        let result = await fetchItems() // runs off main
        items = result                   // back on main via @MainActor
    }
}
```

### Task cancellation

```swift
func search(query: String) async throws -> [Result] {
    // Check cancellation at natural suspension points
    try Task.checkCancellation()
    let results = try await api.search(query)
    try Task.checkCancellation()
    return results
}
```

---

## Memory Management

### Avoid retain cycles in closures

```swift
// Bad
viewModel.onUpdate = {
    self.refresh() // strong capture → retain cycle
}

// Good
viewModel.onUpdate = { [weak self] in
    self?.refresh()
}
```

### Use `weak` in delegates, `unowned` only when lifetime is guaranteed

```swift
// Delegate pattern
weak var delegate: SomeDelegate?

// unowned: only when you are CERTAIN delegate outlives self
// (rare — default to weak)
```

### `withCheckedThrowingContinuation` for legacy callback APIs

```swift
func fetchData() async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
        legacyAPI.fetch { result, error in
            if let error { continuation.resume(throwing: error) }
            else if let result { continuation.resume(returning: result) }
        }
    }
}
```

---

## Error Handling

### Define domain-specific errors

```swift
enum NetworkError: LocalizedError {
    case noConnection
    case unauthorized
    case serverError(statusCode: Int)
    case decodingFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noConnection: "No internet connection."
        case .unauthorized: "Session expired. Please sign in again."
        case .serverError(let code): "Server error (\(code))."
        case .decodingFailed: "Failed to parse server response."
        }
    }
}
```

### Propagate errors up, handle at the boundary

```swift
// Propagate (lower layers)
func fetchUser(id: String) async throws -> User {
    try await networkClient.get("/users/\(id)")
}

// Handle at the UI boundary
.task {
    do {
        user = try await fetchUser(id: userID)
    } catch let error as NetworkError {
        alertMessage = error.localizedDescription
    } catch {
        alertMessage = "Unexpected error."
    }
}
```

### Avoid `try!` and `try?` unless intentional

```swift
// try? is fine when failure is expected and you want nil
let image = try? loadImage(named: name)

// try! only for compile-time guaranteed success (bundle resources)
let url = Bundle.main.url(forResource: "config", withExtension: "json")!
```

---

## Type Safety

### Prefer `enum` over string/int constants

```swift
// Bad
let status = "active"

// Good
enum UserStatus: String, Codable {
    case active, inactive, suspended
}
```

### Use `Identifiable` and `Hashable` on model types

```swift
struct Item: Identifiable, Hashable {
    let id: UUID
    var title: String
}
```

### Phantom types for type-safe IDs

```swift
struct ID<T>: Hashable, Codable, ExpressibleByStringLiteral {
    let rawValue: String
    init(stringLiteral value: String) { rawValue = value }
}

struct User { let id: ID<User> }
struct Post { let id: ID<Post> }

// Compiler rejects: passing Post.id where User.id expected
```

### `Sendable` conformance for concurrency safety

```swift
// Value types are implicitly Sendable
struct Config: Sendable {
    let apiURL: URL
    let timeout: TimeInterval
}

// Classes need explicit conformance + isolation
@MainActor
final class AppState: ObservableObject, @unchecked Sendable { }
```

---

## Performance

### Lazy initialization for expensive resources

```swift
lazy var imageProcessor: ImageProcessor = ImageProcessor()
```

### `@inlinable` for hot-path generic functions

```swift
@inlinable
public func clamp<T: Comparable>(_ value: T, _ range: ClosedRange<T>) -> T {
    min(max(value, range.lowerBound), range.upperBound)
}
```

### Avoid recreating heavy objects in SwiftUI body

```swift
// Bad: creates formatter on every render
Text(date, formatter: DateFormatter()) // new formatter each time

// Good: static or stored
private static let formatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    return f
}()
```

### `Equatable` on view models to reduce redraws

```swift
struct ItemViewModel: Equatable {
    var title: String
    var subtitle: String
    // SwiftUI diffs this before re-rendering
}
```

---

## Code Style Conventions

- **File structure**: `// MARK: - Section` to organize properties, lifecycle, actions, helpers
- **Extensions**: One extension per conformance, in separate files for large types
- **Naming**: verb phrases for functions (`fetchUser`, `handleTap`), nouns for types (`UserStore`, `ProfileView`)
- **Access control**: Start `private`, open up only when needed
- **Force unwrap**: Justify with a `// safe: ...` comment when unavoidable
- **`guard` early returns**: Prefer `guard let` over nested `if let`

```swift
// MARK: - Lifecycle
// MARK: - Actions
// MARK: - Helpers
// MARK: - Private
```

---

## Swift 6 / Strict Concurrency Checklist

When adopting Swift 6 (`swift-tools-version: 6.0` or `SwiftSetting.swiftLanguageVersion(.v6)`):

- [ ] All types crossing actor boundaries conform to `Sendable`
- [ ] No `nonisolated(unsafe)` without clear justification
- [ ] ViewModels marked `@MainActor`
- [ ] `AsyncStream` used for event sequences instead of callbacks
- [ ] `withTaskGroup` used for parallel work instead of `DispatchGroup`
