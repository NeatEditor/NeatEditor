import Foundation

struct DocumentPersistenceService {
    let defaultDirectory: URL
    private let fileManager: FileManager

    init(
        fileManager: FileManager = .default,
        defaultDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.defaultDirectory = defaultDirectory
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    func save(tab: EditorTab) throws -> EditorTab {
        guard !tab.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return tab
        }

        var savedTab = tab
        let fileURL = savedTab.fileURL
            ?? defaultDirectory.appendingPathComponent("\(savedTab.title).txt")

        try savedTab.content.write(to: fileURL, atomically: true, encoding: .utf8)
        savedTab.fileURL = fileURL

        return savedTab
    }

    func openDocument(at fileURL: URL) throws -> EditorTab {
        let normalizedFileURL = normalizedFileURL(for: fileURL)
        let content = try String(contentsOf: normalizedFileURL, encoding: .utf8)

        return EditorTab(
            title: normalizedFileURL.deletingPathExtension().lastPathComponent,
            content: content,
            fileURL: normalizedFileURL
        )
    }

    func normalizedFileURL(for fileURL: URL) -> URL {
        fileURL.standardizedFileURL.resolvingSymlinksInPath()
    }

    func nextUntitledName(existingTabs: [EditorTab]) -> String {
        var maxN = 0
        let baseName = "Untitled"

        if let contents = try? fileManager.contentsOfDirectory(atPath: defaultDirectory.path) {
            for fileName in contents {
                let nameWithoutExtension = (fileName as NSString).deletingPathExtension
                if nameWithoutExtension.hasPrefix(baseName) {
                    let suffix = nameWithoutExtension
                        .dropFirst(baseName.count)
                        .trimmingCharacters(in: .whitespaces)
                    if let number = Int(suffix), number > maxN {
                        maxN = number
                    }
                }
            }
        }

        for tab in existingTabs {
            let nameWithoutExtension = (tab.title as NSString).deletingPathExtension
            if nameWithoutExtension.hasPrefix(baseName) {
                let suffix = nameWithoutExtension
                    .dropFirst(baseName.count)
                    .trimmingCharacters(in: .whitespaces)
                if let number = Int(suffix), number > maxN {
                    maxN = number
                }
            }
        }

        return "\(baseName) \(maxN + 1)"
    }
}
