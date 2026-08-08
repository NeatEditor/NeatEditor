import Combine
import Sparkle
import SwiftUI

@main
struct NeatEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let workspaceStore: WorkspaceStore
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        let workspaceStore = WorkspaceStore()
        self.workspaceStore = workspaceStore

        ExternalFileOpenCoordinator.shared.handler = { [weak workspaceStore] urls in
            workspaceStore?.openFiles(at: urls)
        }
    }

    var body: some Scene {
        Window("NeatEditor", id: "main") {
            WorkspaceView()
                .frame(
                    minWidth: EditorTabStripView.minimumWindowEdge,
                    minHeight: EditorTabStripView.minimumWindowEdge
                )
                .environment(workspaceStore)
        }
        .handlesExternalEvents(matching: [])
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesMenuItem(updater: updaterController.updater)
            }
            WorkspaceCommands(workspaceStore: workspaceStore)
        }
    }
}

private struct CheckForUpdatesMenuItem: View {
    @StateObject private var model: CheckForUpdatesMenuItemModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        _model = StateObject(wrappedValue: CheckForUpdatesMenuItemModel(updater: updater))
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!model.canCheckForUpdates)
    }
}

@MainActor
private final class CheckForUpdatesMenuItemModel: ObservableObject {
    @Published private(set) var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
    }
}
