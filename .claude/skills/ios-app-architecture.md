---
name: ios-app-architecture
version: 1.0.0
description: iOS/macOS app architecture patterns — MVVM, TCA, Clean Architecture, and layered design. Use when structuring a new app, refactoring, or deciding how to organize code across files and modules.
---

# iOS App Architecture Skill

Choose and apply the right architecture for iOS/macOS apps. Covers MVVM, The Composable Architecture (TCA), and layered Clean Architecture.

---

## Architecture Decision Guide

| Signal | Recommended Architecture |
|--------|--------------------------|
| Simple/small app, SwiftUI-first | **MVVM** with `@Observable` |
| Large app, complex state, testability priority | **TCA** (The Composable Architecture) |
| Enterprise, team-based, strict separation | **Clean Architecture** (layered) |
| Existing UIKit codebase | **Coordinator + MVVM** |

---

## 1. MVVM with @Observable (Default for SwiftUI)

The standard for most SwiftUI apps. Keep it simple.

```
App
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift         # SwiftUI view
│   │   ├── HomeViewModel.swift    # @Observable class
│   │   └── HomeModels.swift       # Local model types
│   └── Profile/
│       ├── ProfileView.swift
│       └── ProfileViewModel.swift
├── Services/
│   ├── APIClient.swift
│   ├── AuthService.swift
│   └── UserStore.swift
├── Models/                        # Shared domain models
├── Extensions/
└── App.swift
```

**ViewModel rules:**
- Annotate `@MainActor` — all UI state lives on main thread
- One `@Observable` class per screen/feature
- No UIKit/SwiftUI imports in ViewModel — pure Swift
- Use `async throws` functions, handle errors in View via `.task {}`

```swift
@MainActor
@Observable
final class HomeViewModel {
    var items: [Item] = []
    var isLoading = false
    var errorMessage: String?

    private let service: ItemService

    init(service: ItemService = .shared) {
        self.service = service
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await service.fetchItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

---

## 2. The Composable Architecture (TCA)

Best for complex apps where testability, modularity, and predictable state are priorities.

**Install:** `github.com/pointfreeco/swift-composable-architecture`

### Core concepts

```swift
// 1. State: all data for a feature
struct HomeFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var items: [Item] = []
        var isLoading = false
        var destination: Destination.State?
    }

    // 2. Actions: everything that can happen
    enum Action {
        case onAppear
        case itemsLoaded([Item])
        case loadFailed(String)
        case itemTapped(Item)
        case destination(PresentationAction<Destination.Action>)
    }

    // 3. Dependencies
    @Dependency(\.itemClient) var itemClient

    // 4. Reducer: pure state transitions
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    do {
                        let items = try await itemClient.fetch()
                        await send(.itemsLoaded(items))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }
            case .itemsLoaded(let items):
                state.isLoading = false
                state.items = items
                return .none
            case .loadFailed(let msg):
                state.isLoading = false
                // handle error
                return .none
            case .itemTapped(let item):
                state.destination = .detail(DetailFeature.State(item: item))
                return .none
            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}
```

### View with TCA Store

```swift
struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    var body: some View {
        List(store.items) { item in
            Button(item.title) {
                store.send(.itemTapped(item))
            }
        }
        .overlay { if store.isLoading { ProgressView() } }
        .task { store.send(.onAppear) }
        .navigationDestination(item: $store.scope(
            state: \.destination?.detail,
            action: \.destination.detail
        )) { store in
            DetailView(store: store)
        }
    }
}
```

### TCA Testing

```swift
@Test
func testLoadItems() async {
    let store = TestStore(initialState: HomeFeature.State()) {
        HomeFeature()
    } withDependencies: {
        $0.itemClient.fetch = { [.mock] }
    }

    await store.send(.onAppear) { $0.isLoading = true }
    await store.receive(\.itemsLoaded) {
        $0.isLoading = false
        $0.items = [.mock]
    }
}
```

---

## 3. Clean Architecture (Layered)

For large teams. Strict dependency rule: outer layers depend on inner layers, never the reverse.

```
Presentation Layer  →  Domain Layer  →  Data Layer
(Views, ViewModels)    (Use Cases,       (Repositories,
                        Entities)         APIs, DB)
```

### Folder structure

```
Sources/
├── Presentation/
│   ├── Scenes/Home/
│   │   ├── HomeView.swift
│   │   └── HomeViewModel.swift
│   └── Components/
├── Domain/
│   ├── Entities/
│   │   └── User.swift
│   ├── UseCases/
│   │   └── FetchUsersUseCase.swift
│   └── Repositories/           # Protocols only
│       └── UserRepository.swift
├── Data/
│   ├── Repositories/           # Concrete implementations
│   │   └── UserRepositoryImpl.swift
│   ├── Network/
│   │   └── UserAPIClient.swift
│   └── Persistence/
│       └── UserDAO.swift
└── DI/
    └── AppContainer.swift      # Dependency injection root
```

### Use Case pattern

```swift
// Domain layer — no framework imports
protocol FetchUsersUseCase {
    func execute() async throws -> [User]
}

final class FetchUsersUseCaseImpl: FetchUsersUseCase {
    private let repository: UserRepository

    init(repository: UserRepository) {
        self.repository = repository
    }

    func execute() async throws -> [User] {
        try await repository.fetchAll()
    }
}
```

### Repository pattern

```swift
// Domain layer — protocol
protocol UserRepository {
    func fetchAll() async throws -> [User]
    func fetch(id: User.ID) async throws -> User
    func save(_ user: User) async throws
}

// Data layer — implementation
final class UserRepositoryImpl: UserRepository {
    private let api: UserAPIClient
    private let cache: UserCache

    func fetchAll() async throws -> [User] {
        if let cached = cache.all(), !cached.isEmpty { return cached }
        let users = try await api.getUsers()
        cache.store(users)
        return users
    }
}
```

---

## Dependency Injection

### For MVVM: Environment + factory functions

```swift
// Root injection at app entry
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(UserStore())
                .environment(\.apiClient, APIClient.live)
        }
    }
}
```

### For TCA: `@Dependency` macro

```swift
extension DependencyValues {
    var itemClient: ItemClient {
        get { self[ItemClient.self] }
        set { self[ItemClient.self] = newValue }
    }
}

struct ItemClient: DependencyKey {
    var fetch: @Sendable () async throws -> [Item]

    static let liveValue = ItemClient(
        fetch: { try await APIClient.shared.fetchItems() }
    )
    static let testValue = ItemClient(
        fetch: { [] }
    )
}
```

---

## Module Structure (Multi-Package Apps)

For large apps, split into Swift packages:

```
MyApp (Xcode project)
├── AppModule              # App entry, composition root
├── HomeFeature            # Feature package
├── ProfileFeature         # Feature package
├── SharedUI               # Design system, components
├── Domain                 # Entities, use case protocols
├── Networking             # API client
└── CoreData               # Persistence
```

Each package declares only what it needs:
```swift
// Package.swift
.target(
    name: "HomeFeature",
    dependencies: ["Domain", "SharedUI", "Networking"]
)
```

---

## Checklist: Architecture Review

- [ ] ViewModels have no UIKit/SwiftUI imports
- [ ] Business logic is testable without a running app
- [ ] Data layer is replaceable (protocols + implementations)
- [ ] No singletons except at the app root / composition root
- [ ] Navigation logic lives in coordinator/router, not views
- [ ] All async work is structured (no unmanaged `Task {}` in views)
