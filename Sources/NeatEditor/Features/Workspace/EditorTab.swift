import Foundation

struct EditorTab: Identifiable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var fileURL: URL?
    var isSettings: Bool
    var isContentLoaded: Bool
    
    init(id: UUID = UUID(), title: String, content: String = "", fileURL: URL? = nil, isSettings: Bool = false, isContentLoaded: Bool = true) {
        self.id = id
        self.title = title
        self.content = content
        self.fileURL = fileURL
        self.isSettings = isSettings
        self.isContentLoaded = isContentLoaded
    }
}
