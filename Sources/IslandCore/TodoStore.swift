import Combine
import Foundation

public struct TodoItem: Codable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var isDone: Bool
    public var createdAt: Date

    public init(id: UUID = UUID(), title: String, isDone: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
    }
}

/// Local todo list persisted as JSON.
public final class TodoStore: ObservableObject {
    @Published public private(set) var items: [TodoItem] = []
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    public static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("DynamicIsland", isDirectory: true)
            .appendingPathComponent("todos.json")
    }

    /// Open items first (oldest first), then completed ones.
    public var sortedItems: [TodoItem] {
        items.filter { !$0.isDone } + items.filter(\.isDone)
    }

    public var remainingCount: Int { items.filter { !$0.isDone }.count }

    @discardableResult
    public func add(_ title: String) -> TodoItem? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let item = TodoItem(title: trimmed)
        items.append(item)
        save()
        return item
    }

    public func toggle(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].isDone.toggle()
        save()
    }

    public func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    public func clearCompleted() {
        items.removeAll(where: \.isDone)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        items = (try? JSONDecoder().decode([TodoItem].self, from: data)) ?? []
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(items).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("TodoStore save failed: \(error)")
        }
    }
}
