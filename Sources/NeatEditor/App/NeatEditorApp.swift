import SwiftUI

@main
struct NeatEditorApp: App {
    @State private var documentManager = DocumentManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(documentManager)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New") {
                    documentManager.createNewDocument()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Tab") {
                    documentManager.createNewDocument()
                }
                .keyboardShortcut("t", modifiers: .command)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    documentManager.saveCurrentDocument()
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
    }
}
