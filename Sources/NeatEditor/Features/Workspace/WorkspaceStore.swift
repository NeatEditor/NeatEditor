import Foundation
import Observation
import AppKit
import OSLog

@Observable
@MainActor
final class WorkspaceStore {
    enum UserDefaultsKey {
        static let workspaceState = "WorkspaceState"
        static let appleLanguages = "AppleLanguages"
    }

    struct ClosedTabSnapshot {
        let tab: EditorTab
        let index: Int
    }

    struct RenameFailureAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    static let logger = Logger(
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

    var isRestoringState = false

    @ObservationIgnored
    let persistenceService: DocumentPersistenceService

    @ObservationIgnored
    let autoSaveScheduler: AutoSaveScheduler

    // saveState() is invoked from many small mutating paths and previously did
    // a synchronous JSONEncoder + UserDefaults write per call. Coalesce
    // back-to-back invocations onto a short trailing debounce so a single
    // user-triggered batch (e.g. open files / select tab / autosave) results
    // in one persisted snapshot instead of several. Always flush before
    // app-lifecycle save points.
    @ObservationIgnored
    var pendingSaveStateTask: Task<Void, Never>?

    var closedTabs: [ClosedTabSnapshot] = []

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
}
