import Foundation
import Observation
import AppKit

@Observable
@MainActor
final class DocumentManager {
    var tabs: [TabItem] = []
    var selectedTabID: UUID?
    
    @ObservationIgnored
    private var autoSaveTasks: [UUID: Task<Void, Never>] = [:]
    
    let defaultDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    init() {
        // Initial setup can go here, like creating a first empty document if no tabs exist.
        createNewDocument()
    }
    
    func createNewDocument() {
        let newTitle = generateNextUntitledName()
        let newTab = TabItem(title: newTitle)
        tabs.append(newTab)
        selectedTabID = newTab.id
    }
    
    func saveCurrentDocument() {
        guard let id = selectedTabID else { return }
        saveDocument(id: id)
    }
    
    func saveDocument(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        
        var tab = tabs[index]
        
        // Skip saving if the document contains only whitespaces or is empty
        if tab.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }
        
        let fileURL = tab.fileURL ?? defaultDirectory.appendingPathComponent("\(tab.title).txt")
        
        do {
            try tab.content.write(to: fileURL, atomically: true, encoding: .utf8)
            tab.fileURL = fileURL
            
            // Re-assign back to array to publish state change
            tabs[index] = tab
            print("Successfully saved to \(fileURL.path)")
        } catch {
            print("Failed to save document: \(error)")
            // TODO: show alert to user
        }
    }
    
    func saveAllDocuments() {
        for tab in tabs {
            saveDocument(id: tab.id)
        }
    }
    
    func queueAutoSave(for id: UUID) {
        autoSaveTasks[id]?.cancel()
        
        let task = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(2))
                if !Task.isCancelled {
                    self.saveDocument(id: id)
                }
            } catch {
                // Task was cancelled, do nothing
            }
        }
        autoSaveTasks[id] = task
    }
    
    /// Finds the maximum "Untitled {N}" digit in the documents folder + currently opened tabs, and returns "Untitled {N+1}"
    private func generateNextUntitledName() -> String {
        var maxN = 0
        let baseName = "Untitled"
        
        // 1. Check existing files in ~/Documents
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: defaultDirectory.path) {
            for fileName in contents {
                // Remove .txt extension if present for checking
                let nameWithoutExtension = (fileName as NSString).deletingPathExtension
                if nameWithoutExtension.hasPrefix(baseName) {
                    let suffix = nameWithoutExtension.dropFirst(baseName.count).trimmingCharacters(in: .whitespaces)
                    if let number = Int(suffix), number > maxN {
                        maxN = number
                    }
                }
            }
        }
        
        // 2. Also check currently open tabs just in case they haven't been saved yet
        for tab in tabs {
            let nameWithoutExtension = (tab.title as NSString).deletingPathExtension
            if nameWithoutExtension.hasPrefix(baseName) {
                let suffix = nameWithoutExtension.dropFirst(baseName.count).trimmingCharacters(in: .whitespaces)
                if let number = Int(suffix), number > maxN {
                    maxN = number
                }
            }
        }
        
        return "\(baseName) \(maxN + 1)"
    }
}
