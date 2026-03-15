import Foundation

@MainActor
final class AutoSaveScheduler {
    private let delay: Duration
    private var tasks: [UUID: Task<Void, Never>] = [:]

    init(delay: Duration = .seconds(2)) {
        self.delay = delay
    }

    deinit {
        for task in tasks.values {
            task.cancel()
        }
    }

    func cancel(for id: UUID) {
        tasks[id]?.cancel()
        tasks[id] = nil
    }

    func schedule(for id: UUID, operation: @escaping @MainActor () -> Void) {
        cancel(for: id)

        tasks[id] = Task { @MainActor [delay] in
            do {
                try await Task.sleep(for: delay)
                guard !Task.isCancelled else {
                    return
                }

                operation()
                self.tasks[id] = nil
            } catch {
                self.tasks[id] = nil
            }
        }
    }
}
