import Foundation

struct WorkspaceSearchState: Equatable {
    var isPresented = false
    var query = ""
    var isRegexEnabled = false
    var requestID = 0
    var focusRequestID = 0

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSubmit: Bool {
        !trimmedQuery.isEmpty
    }

    mutating func present() {
        isPresented = true
        focusRequestID += 1
    }

    mutating func dismiss() {
        isPresented = false
    }

    mutating func toggleRegex() {
        isRegexEnabled.toggle()
        guard normalizeQueryIfNeeded() else {
            return
        }

        isPresented = true
        requestID += 1
    }

    mutating func submit() {
        guard normalizeQueryIfNeeded() else {
            present()
            return
        }

        isPresented = true
        requestID += 1
    }

    @discardableResult
    private mutating func normalizeQueryIfNeeded() -> Bool {
        let trimmedQuery = trimmedQuery
        guard !trimmedQuery.isEmpty else {
            return false
        }

        if query != trimmedQuery {
            query = trimmedQuery
        }

        return true
    }
}
