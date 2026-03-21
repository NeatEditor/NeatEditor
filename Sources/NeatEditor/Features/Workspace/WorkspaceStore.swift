import Foundation
import Observation
import AppKit
import OSLog

enum AppLanguage: String, Codable, CaseIterable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var localizedName: String {
        switch self {
        case .system: return "System Default"
        case .english: return "English"
        case .simplifiedChinese: return "Simplified Chinese"
        }
    }
}

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
    var appLanguage: AppLanguage = .system {
        didSet {
            updateAppleLanguages()
            saveState()
        }
    }
    var isLanguageChangePendingRestart = false
    var isSearchBarPresented = false
    var searchQuery = ""
    var isRegexSearchEnabled = false
    var searchRequestID = 0
    var searchFocusRequestID = 0
    var canReopenClosedTab: Bool {
        !closedTabs.isEmpty
    }

    private var isRestoringState = false

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
        loadTabContentIfNeeded(id: newTab.id)
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

            let openedTab = persistenceService.openDocumentLazily(at: fileURL)
            tabs.append(openedTab)
            targetTabID = openedTab.id
        }

        if let targetTabID {
            selectedTabID = targetTabID
            loadTabContentIfNeeded(id: targetTabID)
        }
        saveState()
    }

    func selectTab(_ id: UUID) {
        guard selectedTabID != id else {
            return
        }

        saveSelectedDocumentIfNeeded()
        selectedTabID = id
        loadTabContentIfNeeded(id: id)
        saveState()
    }

    func selectTab(relativeOffset: Int) {
        guard relativeOffset != 0,
            let selectedTabID,
            let selectedIndex = tabs.firstIndex(where: { $0.id == selectedTabID })
        else {
            return
        }

        let lastIndex = tabs.index(before: tabs.endIndex)
        let targetIndex = min(max(selectedIndex + relativeOffset, tabs.startIndex), lastIndex)
        guard targetIndex != selectedIndex else {
            return
        }

        selectTab(tabs[targetIndex].id)
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
            if let newSelection = selectedTabID {
                loadTabContentIfNeeded(id: newSelection)
            }
        }

        saveState()
    }

    func closeOtherDocuments(keeping id: UUID) {
        saveAllDocuments()
        let idsToClose = tabs.filter { $0.id != id }.map { $0.id }
        for closeID in idsToClose {
            guard let index = tabs.firstIndex(where: { $0.id == closeID }) else { continue }
            autoSaveScheduler.cancel(for: closeID)
            let closedTab = tabs[index]
            if !closedTab.isSettings {
                closedTabs.append(ClosedTabSnapshot(tab: closedTab, index: index))
            }
            tabs.remove(at: index)
        }
        selectedTabID = id
        loadTabContentIfNeeded(id: id)
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
            loadTabContentIfNeeded(id: closedTabSnapshot.tab.id)
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
        loadTabContentIfNeeded(id: settingsTab.id)
        saveState()
    }

    func moveToTrash(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }),
              !tabs[index].isSettings,
              let fileURL = tabs[index].fileURL
        else { return }

        autoSaveScheduler.cancel(for: id)

        do {
            try FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
        } catch {
            Self.logger.error("Failed to trash file at \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }

        let closedTab = tabs[index]
        closedTabs.append(ClosedTabSnapshot(tab: closedTab, index: index))
        tabs.remove(at: index)

        if selectedTabID == id {
            if tabs.indices.contains(index) {
                selectedTabID = tabs[index].id
            } else {
                selectedTabID = tabs.last?.id
            }
            if let newSelection = selectedTabID {
                loadTabContentIfNeeded(id: newSelection)
            }
        }

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

        guard tabs[index].isContentLoaded else { return }

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

    private func loadTabContentIfNeeded(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }), 
              !tabs[index].isContentLoaded, 
              let fileURL = tabs[index].fileURL else {
            return
        }
        
        // Mark as loaded immediately so we don't trigger multiple loads
        tabs[index].isContentLoaded = true
        
        let normalizedURL = persistenceService.normalizedFileURL(for: fileURL)
        
        Task {
            do {
                let content = try await Task.detached(priority: .userInitiated) {
                    let data = try Data(contentsOf: normalizedURL, options: .mappedIfSafe)
                    guard let text = String(data: data, encoding: .utf8) else {
                        throw CocoaError(.fileReadInapplicableStringEncoding)
                    }
                    return text
                }.value
                
                guard let currentIndex = self.tabs.firstIndex(where: { $0.id == id }) else { return }
                self.tabs[currentIndex].content = content
            } catch {
                Self.logger.error("Failed to load document content lazily at \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                guard let currentIndex = self.tabs.firstIndex(where: { $0.id == id }) else { return }
                self.tabs[currentIndex].content = "Failed to load document: \(error.localizedDescription)"
            }
        }
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
        let appLanguage: AppLanguage?
    }

    private static let stateKey = "WorkspaceState"

    private func saveState() {
        guard !isRestoringState else { return }

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
            tabBehavior: tabBehavior,
            appLanguage: appLanguage
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
        isRestoringState = true
        defer { isRestoringState = false }

        var restoredSelectedTabID: UUID?
        
        editorFontSize = state.editorFontSize
        tabBehavior = state.tabBehavior
        if let loadedLanguage = state.appLanguage {
            appLanguage = loadedLanguage
        }
        
        for tabState in state.tabs {
            if tabState.isSettings {
                let settingsTab = EditorTab(title: "Settings", isSettings: true)
                tabs.append(settingsTab)
                if state.isSettingsSelected {
                    restoredSelectedTabID = settingsTab.id
                }
            } else if let fileURL = tabState.fileURL {
                let openedTab = persistenceService.openDocumentLazily(at: fileURL)
                tabs.append(openedTab)
                
                if let selectedFileURL = state.selectedFileURL,
                   persistenceService.normalizedFileURL(for: selectedFileURL) == persistenceService.normalizedFileURL(for: fileURL) {
                    restoredSelectedTabID = openedTab.id
                }
            }
        }
        
        if tabs.isEmpty {
            createNewDocument()
        } else if let restoredSelectedTabID {
            selectedTabID = restoredSelectedTabID
            loadTabContentIfNeeded(id: restoredSelectedTabID)
        } else {
            selectedTabID = tabs.first?.id
            if let id = selectedTabID {
                loadTabContentIfNeeded(id: id)
            }
        }
    }

    private func updateAppleLanguages() {
        // Only update if it actually differs from what's currently in UserDefaults
        // to avoid triggering "restart required" continuously.
        if appLanguage == .system {
            if UserDefaults.standard.object(forKey: "AppleLanguages") != nil {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                isLanguageChangePendingRestart = true
            }
        } else {
            let currentLanguages = UserDefaults.standard.stringArray(forKey: "AppleLanguages")
            if currentLanguages?.first != appLanguage.rawValue {
                UserDefaults.standard.set([appLanguage.rawValue], forKey: "AppleLanguages")
                isLanguageChangePendingRestart = true
            }
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
