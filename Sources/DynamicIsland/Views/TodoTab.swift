import IslandCore
import SwiftUI

struct TodoTab: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var todos: TodoStore

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").opacity(0.6)
                TextField("Add a todo and press Return", text: $model.todoDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        todos.add(model.todoDraft)
                        model.todoDraft = ""
                    }
                Text("\(todos.remainingCount) left")
                    .font(.system(size: 11)).opacity(0.5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.08)))

            if todos.items.isEmpty {
                Spacer()
                Text("Nothing to do. Enjoy it.").font(.system(size: 12)).opacity(0.45)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(todos.sortedItems) { item in
                            TodoRow(item: item, todos: todos)
                        }
                    }
                }
                .scrollIndicators(.never)
            }
        }
    }
}

private struct TodoRow: View {
    let item: TodoItem
    let todos: TodoStore
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button { withAnimation(.easeOut(duration: 0.15)) { todos.toggle(item.id) } } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(item.isDone ? Color.green : Color.white.opacity(0.6))
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.system(size: 13))
                .strikethrough(item.isDone)
                .opacity(item.isDone ? 0.4 : 0.95)
                .lineLimit(1)

            Spacer()

            if hovering {
                Button { withAnimation(.easeOut(duration: 0.15)) { todos.remove(item.id) } } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).opacity(0.5)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(hovering ? 0.06 : 0)))
        .onHover { hovering = $0 }
    }
}
