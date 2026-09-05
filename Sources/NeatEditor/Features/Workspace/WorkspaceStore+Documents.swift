import Foundation

extension WorkspaceStore {
    // MARK: - Documents

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
        // saveDocument enqueues a debounced saveState; force a synchronous
        // flush here because saveAllDocuments is invoked at lifecycle
        // boundaries (scenePhase != active, app termination) where we cannot
        // rely on the debounce window completing.
        flushPendingSaveState()
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

    func loadTabContentIfNeeded(id: UUID) {
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

    func saveSelectedDocumentIfNeeded() {
        if let selectedTabID {
            saveDocument(id: selectedTabID)
        }
    }
}
