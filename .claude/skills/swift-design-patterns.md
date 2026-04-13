---
name: swift-design-patterns
version: 1.0.0
description: SwiftUI and UIKit design patterns for iOS/macOS apps. Use when building UI components, managing state, handling navigation, or structuring views in Swift projects.
---

# Swift Design Patterns Skill

Apply proven SwiftUI and UIKit design patterns to build maintainable, idiomatic iOS/macOS apps.

## When to Use This Skill

- Building or refactoring SwiftUI views and components
- Choosing between state management approaches
- Structuring navigation flows
- Designing reusable UI components
- Handling data flow between views

---

## SwiftUI Patterns

### 1. ViewModifier for Reusable Styling

Extract repeated styling into `ViewModifier` instead of copy-pasting modifiers.

```swift
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// Usage
Text("Hello").cardStyle()
```

### 2. State Management Hierarchy

Choose the right state tool for the scope:

| Scope | Tool |
|-------|------|
| Local, transient UI state | `@State` |
| Shared across child views (read-only) | `@Environment` |
| Shared mutable object | `@StateObject` / `@ObservedObject` |
| Global app-wide state | `@EnvironmentObject` or `@Observable` singleton |
| Persisted lightweight values | `@AppStorage` |
| Persisted model objects | SwiftData `@Model` + `@Query` |

```swift
// Prefer @Observable (iOS 17+) over ObservableObject
@Observable
class UserStore {
    var currentUser: User?
    var isAuthenticated = false
}

// In view
@State private var store = UserStore()
// or inject via environment
.environment(store)
```

### 3. Container / Presenter Split

Keep views dumb. Extract data logic into a container or view model.

```swift
// Container: owns state and business logic
struct ProfileContainer: View {
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        ProfileView(
            user: viewModel.user,
            onSave: viewModel.save
        )
        .task { await viewModel.load() }
    }
}

// Presenter: pure UI, no business logic
struct ProfileView: View {
    let user: User
    let onSave: () -> Void

    var body: some View {
        // render only
    }
}
```

### 4. Preference Key for Child-to-Parent Communication

When a child view needs to communicate upward (e.g., dynamic heights, titles):

```swift
struct TitlePreferenceKey: PreferenceKey {
    static var defaultValue: String = ""
    static func reduce(value: inout String, nextValue: () -> String) {
        value = nextValue()
    }
}

// Child sets it
.preference(key: TitlePreferenceKey.self, value: "My Title")

// Parent reads it
.onPreferenceChange(TitlePreferenceKey.self) { title in
    self.navigationTitle = title
}
```

### 5. Navigation Patterns (iOS 16+)

Use `NavigationStack` with `navigationDestination` for type-safe routing:

```swift
enum Route: Hashable {
    case detail(Item)
    case settings
    case profile(userID: String)
}

struct AppView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .detail(let item): DetailView(item: item)
                    case .settings: SettingsView()
                    case .profile(let id): ProfileView(userID: id)
                    }
                }
        }
    }
}
```

### 6. Generic Async Content Pattern

Reusable loading/error/success state view:

```swift
enum LoadState<T> {
    case idle, loading, loaded(T), failed(Error)
}

struct AsyncContentView<T, Content: View>: View {
    let state: LoadState<T>
    let content: (T) -> Content

    var body: some View {
        switch state {
        case .idle: EmptyView()
        case .loading: ProgressView()
        case .loaded(let value): content(value)
        case .failed(let error):
            ContentUnavailableView(error.localizedDescription,
                systemImage: "exclamationmark.triangle")
        }
    }
}
```

### 7. Environment-Based Dependency Injection

Inject dependencies through the environment instead of passing through every view:

```swift
// Define environment key
private struct APIClientKey: EnvironmentKey {
    static let defaultValue: APIClient = .shared
}

extension EnvironmentValues {
    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

// Inject at root
ContentView().environment(\.apiClient, MockAPIClient())

// Use anywhere in tree
@Environment(\.apiClient) var apiClient
```

---

## UIKit Patterns (when UIKit is needed)

### Coordinator Pattern for Navigation

```swift
protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get }
    func start()
}

class AppCoordinator: Coordinator {
    let navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        let vc = HomeViewController()
        vc.coordinator = self
        navigationController.pushViewController(vc, animated: false)
    }

    func showDetail(for item: Item) {
        let vc = DetailViewController(item: item)
        navigationController.pushViewController(vc, animated: true)
    }
}
```

### Diffable Data Source for Collections

```swift
typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>

var dataSource: DataSource!

func configureDataSource() {
    let cellRegistration = UICollectionView.CellRegistration<UICollectionViewCell, Item> { cell, indexPath, item in
        // configure cell
    }

    dataSource = DataSource(collectionView: collectionView) { cv, indexPath, item in
        cv.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, with: item)
    }
}

func applySnapshot(items: [Item]) {
    var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
    snapshot.appendSections([.main])
    snapshot.appendItems(items)
    dataSource.apply(snapshot, animatingDifferences: true)
}
```

---

## Anti-Patterns to Avoid

- **Massive View**: Split views larger than ~100 lines into subviews
- **Logic in View body**: Move async calls, formatting, and business logic out of `body`
- **Prop drilling**: Use environment or a shared store instead of passing data 5+ levels deep
- **Force unwrapping optionals** in views — use `if let` or `guard let`
- **Mutating `@ObservableObject` from background threads** — always publish on main
- **Embedding `NavigationStack` inside `NavigationStack`** — one stack per navigation hierarchy
