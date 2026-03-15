import Foundation
import Observation
import AppKit
import OSLog

@Observable
@MainActor
final class WorkspaceStore {
    private enum EditorFontMetrics {
        static let minimumSize: CGFloat = 10
        static let maximumSize: CGFloat = 36
        static let step: CGFloat = 1
    }

    private static let logger = Logger(
        subsystem: "com.geraltgraham.NeatEditor",
        category: "Workspace"
    )

    var tabs: [EditorTab] = []
    var selectedTabID: UUID?
    var editorFontSize: CGFloat = NSFont.systemFontSize
    var isSearchBarPresented = false
    var searchQuery = ""
    var searchRequestID = 0
    var searchFocusRequestID = 0

    @ObservationIgnored
    private let persistenceService: DocumentPersistenceService

    @ObservationIgnored
    private let autoSaveScheduler: AutoSaveScheduler

    init(
        persistenceService: DocumentPersistenceService = DocumentPersistenceService(),
        autoSaveScheduler: AutoSaveScheduler = AutoSaveScheduler()
    ) {
        self.persistenceService = persistenceService
        self.autoSaveScheduler = autoSaveScheduler
        createNewDocument()
    }

    func createNewDocument() {
        saveSelectedDocumentIfNeeded()

        let newTitle = persistenceService.nextUntitledName(existingTabs: tabs)
        let newTab = EditorTab(title: newTitle)
        tabs.append(newTab)
        selectedTabID = newTab.id
    }

    func selectTab(_ id: UUID) {
        guard selectedTabID != id else {
            return
        }

        saveSelectedDocumentIfNeeded()
        selectedTabID = id
    }

    func saveCurrentDocument() {
        guard let id = selectedTabID else { return }
        saveDocument(id: id)
    }

    func saveAndCloseCurrentDocument() {
        guard let id = selectedTabID,
              let index = tabs.firstIndex(where: { $0.id == id }) else {
            return
        }

        saveDocument(id: id)
        autoSaveScheduler.cancel(for: id)

        tabs.remove(at: index)

        if tabs.indices.contains(index) {
            selectedTabID = tabs[index].id
        } else {
            selectedTabID = tabs.last?.id
        }
    }

    func increaseEditorFontSize() {
        updateEditorFontSize(by: EditorFontMetrics.step)
    }

    func decreaseEditorFontSize() {
        updateEditorFontSize(by: -EditorFontMetrics.step)
    }

    func presentSearchBar() {
        isSearchBarPresented = true
        searchFocusRequestID += 1
    }

    func submitSearch() {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            presentSearchBar()
            return
        }

        if searchQuery != trimmedQuery {
            searchQuery = trimmedQuery
        }

        isSearchBarPresented = true
        searchRequestID += 1
    }
    
    func saveDocument(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        do {
            tabs[index] = try persistenceService.save(tab: tabs[index])
        } catch {
            Self.logger.error("Failed to save document: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveAllDocuments() {
        for tab in tabs {
            saveDocument(id: tab.id)
        }
    }

    func cancelAutoSave(for id: UUID) {
        autoSaveScheduler.cancel(for: id)
    }

    func queueAutoSave(for id: UUID) {
        autoSaveScheduler.schedule(for: id) { [weak self] in
            self?.saveDocument(id: id)
        }
    }

    private func updateEditorFontSize(by delta: CGFloat) {
        let nextSize = (editorFontSize + delta).clamped(
            to: EditorFontMetrics.minimumSize...EditorFontMetrics.maximumSize
        )
        guard nextSize != editorFontSize else {
            return
        }

        editorFontSize = nextSize
    }

    private func saveSelectedDocumentIfNeeded() {
        if let selectedTabID {
            saveDocument(id: selectedTabID)
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
