import Foundation
import AppKit
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

        CommandGroup(after: .newItem) {
            Button("Open...") {
                openDocumentsFromUserHome()
            }
            .keyboardShortcut("o", modifiers: .command)
        }
        
        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                workspaceStore.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
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

            Button("Reopen Closed Tab") {
                workspaceStore.reopenLastClosedDocument()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .disabled(!workspaceStore.canReopenClosedTab)
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

    @MainActor
    private func openDocumentsFromUserHome() {
        let panel = NSOpenPanel()
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true

        guard panel.runModal() == .OK else {
            return
        }

        workspaceStore.openFiles(at: panel.urls)
    }
}
