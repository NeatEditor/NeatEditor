import SwiftUI

struct WorkspaceCommands: Commands {
    let workspaceStore: WorkspaceStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New") {
                workspaceStore.createNewDocument()
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Tab") {
                workspaceStore.createNewDocument()
            }
            .keyboardShortcut("t", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                workspaceStore.saveCurrentDocument()
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("Close Tab") {
                workspaceStore.saveAndCloseCurrentDocument()
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(workspaceStore.selectedTabID == nil)
        }

        CommandGroup(after: .textEditing) {
            Button("Find") {
                workspaceStore.presentSearchBar()
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(workspaceStore.selectedTabID == nil)
        }

        CommandMenu("View") {
            Button("Zoom In") {
                workspaceStore.increaseEditorFontSize()
            }
            .keyboardShortcut("=", modifiers: .command)

            Button("Zoom Out") {
                workspaceStore.decreaseEditorFontSize()
            }
            .keyboardShortcut("-", modifiers: .command)
        }
    }
}
