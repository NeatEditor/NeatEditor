import Foundation

extension WorkspaceStore {
    // MARK: - Preferences

    private enum EditorFontStep {
        static let value: CGFloat = 1
    }

    func increaseEditorFontSize() {
        updateEditorFontSize(by: EditorFontStep.value)
    }

    func decreaseEditorFontSize() {
        updateEditorFontSize(by: -EditorFontStep.value)
    }

    func updateEditorFontSize(by delta: CGFloat) {
        guard preferences.stepEditorFontSize(
            by: delta,
            rememberingFor: selectedEditorFontFileURL()
        ) else {
            return
        }
    }

    func handlePreferencesChange(
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

    func updateAppleLanguages(for appLanguage: AppLanguage) {
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

    func selectedEditorFontFileURL() -> URL? {
        guard let selectedTabID,
              let tab = tabs.first(where: { $0.id == selectedTabID }),
              !tab.isSettings else {
            return nil
        }

        return normalizedEditorFontFileURL(for: tab.fileURL)
    }

    func normalizedEditorFontFileURL(for fileURL: URL?) -> URL? {
        guard let fileURL else {
            return nil
        }

        return persistenceService.normalizedFileURL(for: fileURL)
    }

    func applyEditorFontPreferenceForSelectedTab() {
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
