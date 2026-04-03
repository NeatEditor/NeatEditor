import Foundation
import Observation
import AppKit
import OSLog

@Observable
@MainActor
final class WorkspaceStore {
    private enum UserDefaultsKey {
        static let workspaceState = "WorkspaceState"
        static let appleLanguages = "AppleLanguages"
    }

    private enum EditorFontStep {
        static let value: CGFloat = 1
    }

    private struct ClosedTabSnapshot {
        let tab: EditorTab
        let index: Int
    }

    struct RenameFailureAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private static let logger = Logger(
        subsystem: "com.x0c.NeatEditor",
        category: "Workspace"
    )

    var tabs: [EditorTab] = []
    var selectedTabID: UUID?
    var preferences = WorkspacePreferences() {
        didSet {
            handlePreferencesChange(from: oldValue, to: preferences)
        }
    }
    var isLanguageChangePendingRestart = false
    var searchState = WorkspaceSearchState()
    var renameFailureAlert: RenameFailureAlert?
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
        applyEditorFontPreferenceForSelectedTab()
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
            applyEditorFontPreferenceForSelectedTab()
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
        applyEditorFontPreferenceForSelectedTab()
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
                applyEditorFontPreferenceForSelectedTab()
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
        applyEditorFontPreferenceForSelectedTab()
        saveState()
    }

    func reopenLastClosedDocument() {
        while let closedTabSnapshot = closedTabs.popLast() {
            saveSelectedDocumentIfNeeded()

            if let fileURL = closedTabSnapshot.tab.fileURL,
               let existingTabID = existingTabID(for: fileURL) {
                selectedTabID = existingTabID
                applyEditorFontPreferenceForSelectedTab()
                saveState()
                return
            }

            let restoredIndex = min(closedTabSnapshot.index, tabs.count)
            tabs.insert(closedTabSnapshot.tab, at: restoredIndex)
            selectedTabID = closedTabSnapshot.tab.id
            loadTabContentIfNeeded(id: closedTabSnapshot.tab.id)
            applyEditorFontPreferenceForSelectedTab()
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
        
        let settingsTab = EditorTab(title: String(localized: "Settings"), isSettings: true)
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
                applyEditorFontPreferenceForSelectedTab()
            }
        }

        saveState()
    }

    func renameDocument(id: UUID, to newTitle: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }), !tabs[index].isSettings else {
            return
        }

        let originalFileURL = normalizedEditorFontFileURL(for: tabs[index].fileURL)

        do {
            tabs[index] = try persistenceService.rename(tab: tabs[index], to: newTitle)
            preferences.moveRememberedEditorFontSize(
                from: originalFileURL,
                to: normalizedEditorFontFileURL(for: tabs[index].fileURL)
            )

            if selectedTabID == id {
                preferences.rememberCurrentEditorFontSize(
                    for: normalizedEditorFontFileURL(for: tabs[index].fileURL)
                )
            }
            saveState()
        } catch {
            if case let DocumentPersistenceService.PersistenceError.destinationAlreadyExists(url) = error {
                let messageFormat = String(
                    localized: "“%@” already exists in this folder. Use a different name and try again."
                )
                renameFailureAlert = RenameFailureAlert(
                    title: String(localized: "Rename Failed"),
                    message: String(format: messageFormat, url.lastPathComponent)
                )
            }
            Self.logger.error("Failed to rename document: \(error.localizedDescription, privacy: .public)")
        }
    }

    func dismissRenameFailureAlert() {
        renameFailureAlert = nil
    }

    func increaseEditorFontSize() {
        updateEditorFontSize(by: EditorFontStep.value)
    }

    func decreaseEditorFontSize() {
        updateEditorFontSize(by: -EditorFontStep.value)
    }

    func presentSearchBar() {
        searchState.present()
    }

    func dismissSearchBar() {
        searchState.dismiss()
    }

    func toggleRegexSearch() {
        searchState.toggleRegex()
    }

    func submitSearch() {
        searchState.submit()
    }
    
    func saveDocument(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }), !tabs[index].isSettings else { return }

        guard tabs[index].isContentLoaded else { return }

        do {
            tabs[index] = try persistenceService.save(tab: tabs[index])

            if selectedTabID == id {
                preferences.rememberCurrentEditorFontSize(
                    for: normalizedEditorFontFileURL(for: tabs[index].fileURL)
                )
            }
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
        guard preferences.stepEditorFontSize(
            by: delta,
            rememberingFor: selectedEditorFontFileURL()
        ) else {
            return
        }
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
                let messageFormat = String(localized: "Failed to load document: %@")
                self.tabs[currentIndex].content = String(
                    format: messageFormat,
                    error.localizedDescription
                )
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
        let preferences: WorkspacePreferences

        private enum CodingKeys: String, CodingKey {
            case tabs
            case selectedFileURL
            case isSettingsSelected
            case preferences
            case editorFontSize
            case tabBehavior
            case appLanguage
        }

        init(
            tabs: [TabState],
            selectedFileURL: URL?,
            isSettingsSelected: Bool,
            preferences: WorkspacePreferences
        ) {
            self.tabs = tabs
            self.selectedFileURL = selectedFileURL
            self.isSettingsSelected = isSettingsSelected
            self.preferences = preferences
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            tabs = try container.decode([TabState].self, forKey: .tabs)
            selectedFileURL = try container.decodeIfPresent(URL.self, forKey: .selectedFileURL)
            isSettingsSelected = try container.decode(Bool.self, forKey: .isSettingsSelected)

            if let preferences = try container.decodeIfPresent(
                WorkspacePreferences.self,
                forKey: .preferences
            ) {
                self.preferences = preferences
                return
            }

            let defaultPreferences = WorkspacePreferences()
            preferences = WorkspacePreferences(
                editorFontSize: try container.decodeIfPresent(
                    CGFloat.self,
                    forKey: .editorFontSize
                ) ?? defaultPreferences.editorFontSize,
                tabBehavior: try container.decodeIfPresent(
                    TabBehavior.self,
                    forKey: .tabBehavior
                ) ?? defaultPreferences.tabBehavior,
                appLanguage: try container.decodeIfPresent(
                    AppLanguage.self,
                    forKey: .appLanguage
                ) ?? defaultPreferences.appLanguage
            )
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(tabs, forKey: .tabs)
            try container.encodeIfPresent(selectedFileURL, forKey: .selectedFileURL)
            try container.encode(isSettingsSelected, forKey: .isSettingsSelected)
            try container.encode(preferences, forKey: .preferences)
        }
    }

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
            preferences: preferences
        )
        
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: UserDefaultsKey.workspaceState)
        } catch {
            Self.logger.error("Failed to save workspace state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadState() -> WorkspaceState? {
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKey.workspaceState) else {
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
        
        preferences = state.preferences
        
        for tabState in state.tabs {
            if tabState.isSettings {
                let settingsTab = EditorTab(
                    title: String(localized: "Settings"),
                    isSettings: true
                )
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
            applyEditorFontPreferenceForSelectedTab()
        } else {
            selectedTabID = tabs.first?.id
            if let id = selectedTabID {
                loadTabContentIfNeeded(id: id)
                applyEditorFontPreferenceForSelectedTab()
            }
        }
    }

    private func handlePreferencesChange(
        from oldPreferences: WorkspacePreferences,
        to newPreferences: WorkspacePreferences
    ) {
        guard !isRestoringState else {
            return
        }

        if oldPreferences.appLanguage != newPreferences.appLanguage {
            updateAppleLanguages(for: newPreferences.appLanguage)
        }

        saveState()
    }

    private func updateAppleLanguages(for appLanguage: AppLanguage) {
        // Only update if it actually differs from what's currently in UserDefaults
        // to avoid triggering "restart required" continuously.
        if appLanguage == .system {
            if UserDefaults.standard.object(forKey: UserDefaultsKey.appleLanguages) != nil {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKey.appleLanguages)
                isLanguageChangePendingRestart = true
            }
        } else {
            let currentLanguages = UserDefaults.standard.stringArray(
                forKey: UserDefaultsKey.appleLanguages
            )
            if currentLanguages?.first != appLanguage.rawValue {
                UserDefaults.standard.set(
                    [appLanguage.rawValue],
                    forKey: UserDefaultsKey.appleLanguages
                )
                isLanguageChangePendingRestart = true
            }
        }
    }

    private func selectedEditorFontFileURL() -> URL? {
        guard let selectedTabID,
              let tab = tabs.first(where: { $0.id == selectedTabID }),
              !tab.isSettings else {
            return nil
        }

        return normalizedEditorFontFileURL(for: tab.fileURL)
    }

    private func normalizedEditorFontFileURL(for fileURL: URL?) -> URL? {
        guard let fileURL else {
            return nil
        }

        return persistenceService.normalizedFileURL(for: fileURL)
    }

    private func applyEditorFontPreferenceForSelectedTab() {
        guard let selectedTabID,
              let tab = tabs.first(where: { $0.id == selectedTabID }),
              !tab.isSettings else {
            return
        }

        preferences.applyRememberedEditorFontSize(
            for: normalizedEditorFontFileURL(for: tab.fileURL)
        )
    }
}
