import SwiftUI

@main
struct NeatEditorApp: App {
    @State private var workspaceStore = WorkspaceStore()

    var body: some Scene {
        WindowGroup {
            WorkspaceView()
                .environment(workspaceStore)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
        .commands {
            WorkspaceCommands(workspaceStore: workspaceStore)
        }
    }
}
