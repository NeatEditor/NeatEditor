import SwiftUI

@main
struct NeatEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let workspaceStore: WorkspaceStore

    init() {
        let workspaceStore = WorkspaceStore()
        self.workspaceStore = workspaceStore

        ExternalFileOpenCoordinator.shared.handler = { [weak workspaceStore] urls in
            workspaceStore?.openFiles(at: urls)
        }
    }

    var body: some Scene {
        Window("NeatEditor", id: "main") {
            WorkspaceView()
                .environment(workspaceStore)
        }
        .handlesExternalEvents(matching: [])
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
        .commands {
            WorkspaceCommands(workspaceStore: workspaceStore)
        }
    }
}
