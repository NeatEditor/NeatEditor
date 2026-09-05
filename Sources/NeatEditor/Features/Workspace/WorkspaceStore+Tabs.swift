import Foundation

extension WorkspaceStore {
    // MARK: - Tabs

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

    func existingTabID(for fileURL: URL) -> UUID? {
        let normalizedFileURL = persistenceService.normalizedFileURL(for: fileURL)

        return tabs.first {
            guard let tabFileURL = $0.fileURL else {
                return false
            }

            return persistenceService.normalizedFileURL(for: tabFileURL) == normalizedFileURL
        }?.id
    }

    func uniqueFileURLs(from urls: [URL]) -> [URL] {
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
}
