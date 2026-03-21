import Foundation

struct DocumentPersistenceService {
    enum PersistenceError: LocalizedError {
        case destinationAlreadyExists(URL)

        var errorDescription: String? {
            switch self {
            case .destinationAlreadyExists(let url):
                return "A document named \"\(url.lastPathComponent)\" already exists."
            }
        }
    }

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
            ?? initialFileURL(for: savedTab.title)

        try savedTab.content.write(to: fileURL, atomically: true, encoding: .utf8)
        savedTab.fileURL = fileURL
        savedTab.title = fileURL.lastPathComponent

        return savedTab
    }

    func rename(tab: EditorTab, to newTitle: String) throws -> EditorTab {
        var renamedTab = tab
        renamedTab.title = newTitle

        guard let fileURL = renamedTab.fileURL else {
            return renamedTab
        }

        let normalizedFileURL = normalizedFileURL(for: fileURL)
        let destinationURL = renamedFileURL(for: normalizedFileURL, title: newTitle)

        guard destinationURL != normalizedFileURL else {
            renamedTab.fileURL = normalizedFileURL
            renamedTab.title = normalizedFileURL.lastPathComponent
            return renamedTab
        }

        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw PersistenceError.destinationAlreadyExists(destinationURL)
        }

        if fileManager.fileExists(atPath: normalizedFileURL.path) {
            try fileManager.moveItem(at: normalizedFileURL, to: destinationURL)
        }

        renamedTab.fileURL = destinationURL
        renamedTab.title = destinationURL.lastPathComponent
        return renamedTab
    }

    func openDocument(at fileURL: URL) throws -> EditorTab {
        let normalizedFileURL = normalizedFileURL(for: fileURL)
        let content = try String(contentsOf: normalizedFileURL, encoding: .utf8)

        return EditorTab(
            title: normalizedFileURL.lastPathComponent,
            content: content,
            fileURL: normalizedFileURL
        )
    }

    func normalizedFileURL(for fileURL: URL) -> URL {
        fileURL.standardizedFileURL.resolvingSymlinksInPath()
    }

    private func renamedFileURL(for fileURL: URL, title: String) -> URL {
        return fileURL
            .deletingLastPathComponent()
            .appendingPathComponent(title)
    }

    private func initialFileURL(for title: String) -> URL {
        let fileName = (title as NSString).pathExtension.isEmpty
            ? "\(title).txt"
            : title

        return defaultDirectory.appendingPathComponent(fileName)
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
