import Foundation

extension WorkspaceStore {
    // MARK: - State Restoration

    struct WorkspaceState: Codable {
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

    func saveState() {
        guard !isRestoringState else { return }

        pendingSaveStateTask?.cancel()
        pendingSaveStateTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(50))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.pendingSaveStateTask = nil
            self?.performSaveStateNow()
        }
    }

    func flushPendingSaveState() {
        pendingSaveStateTask?.cancel()
        pendingSaveStateTask = nil
        performSaveStateNow()
    }

    func performSaveStateNow() {
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

    func loadState() -> WorkspaceState? {
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

    func restoreState(_ state: WorkspaceState) {
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
}
