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

    private struct ClosedTabSnapshot {
        let tab: EditorTab
        let index: Int
    }

    private static let logger = Logger(
        subsystem: "com.geraltgraham.NeatEditor",
        category: "Workspace"
    )

    var tabs: [EditorTab] = []
    var selectedTabID: UUID?
    var editorFontSize: CGFloat = 13 {
        didSet {
            saveState()
        }
    }
    var tabBehavior: TabBehavior = .spaces2 {
        didSet {
            saveState()
        }
    }
    var isSearchBarPresented = false
    var searchQuery = ""
    var isRegexSearchEnabled = false
    var searchRequestID = 0
    var searchFocusRequestID = 0
    var canReopenClosedTab: Bool {
        !closedTabs.isEmpty
    }

    @ObservationIgnored
    private let persistenceService: DocumentPersistenceService

    @ObservationIgnored
    private let autoSaveScheduler: AutoSaveScheduler

    private var closedTabs: [ClosedTabSnapshot] = []

    init(
        persistenceService: DocumentPersistenceService = DocumentPersistenceService(),
        autoSaveScheduler: AutoSaveScheduler = AutoSaveScheduler()
    ) {
        self.persistenceService = persistenceService
        self.autoSaveScheduler = autoSaveScheduler
        
        if let state = loadState() {
            restoreState(state)
        } else {
            createNewDocument()
        }
    }

    func createNewDocument() {
        saveSelectedDocumentIfNeeded()

        let newTitle = persistenceService.nextUntitledName(existingTabs: tabs)
        let newTab = EditorTab(title: newTitle)
        tabs.append(newTab)
        selectedTabID = newTab.id
        saveState()
    }

    func openFiles(at urls: [URL]) {
        let fileURLs = uniqueFileURLs(from: urls)
        guard !fileURLs.isEmpty else {
            return
        }

        saveSelectedDocumentIfNeeded()

        var targetTabID: UUID?

        for fileURL in fileURLs {
            if let existingTabID = existingTabID(for: fileURL) {
                targetTabID = existingTabID
                continue
            }

            do {
                let openedTab = try persistenceService.openDocument(at: fileURL)
                tabs.append(openedTab)
                targetTabID = openedTab.id
            } catch {
                Self.logger.error(
                    "Failed to open document at \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        if let targetTabID {
            selectedTabID = targetTabID
        }
        saveState()
    }

    func selectTab(_ id: UUID) {
        guard selectedTabID != id else {
            return
        }

        saveSelectedDocumentIfNeeded()
        selectedTabID = id
        saveState()
    }

    func saveCurrentDocument() {
        guard let id = selectedTabID else { return }
        saveDocument(id: id)
    }

    func saveAndCloseCurrentDocument() {
        guard let id = selectedTabID else {
            return
        }

        closeDocument(id: id)
    }

    func closeDocument(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            return
        }

        saveDocument(id: id)
        autoSaveScheduler.cancel(for: id)

        let closedTab = tabs[index]
        if !closedTab.isSettings {
            closedTabs.append(ClosedTabSnapshot(tab: closedTab, index: index))
        }

        tabs.remove(at: index)

        if selectedTabID == id {
            if tabs.indices.contains(index) {
                selectedTabID = tabs[index].id
            } else {
                selectedTabID = tabs.last?.id
            }
        }

        saveState()
    }

    func reopenLastClosedDocument() {
        while let closedTabSnapshot = closedTabs.popLast() {
            saveSelectedDocumentIfNeeded()

            if let fileURL = closedTabSnapshot.tab.fileURL,
               let existingTabID = existingTabID(for: fileURL) {
                selectedTabID = existingTabID
                saveState()
                return
            }

            let restoredIndex = min(closedTabSnapshot.index, tabs.count)
            tabs.insert(closedTabSnapshot.tab, at: restoredIndex)
            selectedTabID = closedTabSnapshot.tab.id
            saveState()
            return
        }
    }
    
    func openSettings() {
        if let existingSettingsTab = tabs.first(where: { $0.isSettings }) {
            selectTab(existingSettingsTab.id)
            return
        }
        
        saveSelectedDocumentIfNeeded()
        
        let settingsTab = EditorTab(title: "Settings", isSettings: true)
        tabs.append(settingsTab)
        selectedTabID = settingsTab.id
        saveState()
    }

    func renameDocument(id: UUID, to newTitle: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }), !tabs[index].isSettings else {
            return
        }

        do {
            tabs[index] = try persistenceService.rename(tab: tabs[index], to: newTitle)
            saveState()
        } catch {
            Self.logger.error("Failed to rename document: \(error.localizedDescription, privacy: .public)")
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

    func dismissSearchBar() {
        isSearchBarPresented = false
    }

    func toggleRegexSearch() {
        isRegexSearchEnabled.toggle()

        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return
        }

        if searchQuery != trimmedQuery {
            searchQuery = trimmedQuery
        }

        isSearchBarPresented = true
        searchRequestID += 1
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
        guard let index = tabs.firstIndex(where: { $0.id == id }), !tabs[index].isSettings else { return }

        do {
            tabs[index] = try persistenceService.save(tab: tabs[index])
            saveState()
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
        guard let index = tabs.firstIndex(where: { $0.id == id }), !tabs[index].isSettings else { return }
        
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
        saveState()
    }

    private func saveSelectedDocumentIfNeeded() {
        if let selectedTabID {
            saveDocument(id: selectedTabID)
        }
    }

    private func existingTabID(for fileURL: URL) -> UUID? {
        let normalizedFileURL = persistenceService.normalizedFileURL(for: fileURL)

        return tabs.first {
            guard let tabFileURL = $0.fileURL else {
                return false
            }

            return persistenceService.normalizedFileURL(for: tabFileURL) == normalizedFileURL
        }?.id
    }

    private func uniqueFileURLs(from urls: [URL]) -> [URL] {
        var seen = Set<URL>()
        var result: [URL] = []

        for url in urls where url.isFileURL {
            let normalizedFileURL = persistenceService.normalizedFileURL(for: url)
            if seen.insert(normalizedFileURL).inserted {
                result.append(normalizedFileURL)
            }
        }

        return result
    }

    // MARK: - State Restoration

    private struct WorkspaceState: Codable {
        struct TabState: Codable {
            let fileURL: URL?
            let isSettings: Bool
        }
        let tabs: [TabState]
        let selectedFileURL: URL?
        let isSettingsSelected: Bool
        let editorFontSize: CGFloat
        let tabBehavior: TabBehavior
    }

    private static let stateKey = "WorkspaceState"

    private func saveState() {
        let stateTabs = tabs.map { WorkspaceState.TabState(fileURL: $0.fileURL, isSettings: $0.isSettings) }
        
        var selectedFileURL: URL?
        var isSettingsSelected = false
        
        if let selectedTabID {
            if let tab = tabs.first(where: { $0.id == selectedTabID }) {
                if tab.isSettings {
                    isSettingsSelected = true
                } else {
                    selectedFileURL = tab.fileURL
                }
            }
        }
        
        let state = WorkspaceState(
            tabs: stateTabs,
            selectedFileURL: selectedFileURL,
            isSettingsSelected: isSettingsSelected,
            editorFontSize: editorFontSize,
            tabBehavior: tabBehavior
        )
        
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: Self.stateKey)
        } catch {
            Self.logger.error("Failed to save workspace state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadState() -> WorkspaceState? {
        guard let data = UserDefaults.standard.data(forKey: Self.stateKey) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(WorkspaceState.self, from: data)
        } catch {
            Self.logger.error("Failed to load workspace state: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func restoreState(_ state: WorkspaceState) {
        var restoredSelectedTabID: UUID?
        
        editorFontSize = state.editorFontSize
        tabBehavior = state.tabBehavior
        
        for tabState in state.tabs {
            if tabState.isSettings {
                let settingsTab = EditorTab(title: "Settings", isSettings: true)
                tabs.append(settingsTab)
                if state.isSettingsSelected {
                    restoredSelectedTabID = settingsTab.id
                }
            } else if let fileURL = tabState.fileURL {
                do {
                    let openedTab = try persistenceService.openDocument(at: fileURL)
                    tabs.append(openedTab)
                    
                    if let selectedFileURL = state.selectedFileURL,
                       persistenceService.normalizedFileURL(for: selectedFileURL) == persistenceService.normalizedFileURL(for: fileURL) {
                        restoredSelectedTabID = openedTab.id
                    }
                } catch {
                    Self.logger.error("Failed to restore document at \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        
        if tabs.isEmpty {
            createNewDocument()
        } else if let restoredSelectedTabID {
            selectedTabID = restoredSelectedTabID
        } else {
            selectedTabID = tabs.first?.id
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
