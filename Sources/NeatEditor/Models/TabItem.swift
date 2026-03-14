import Foundation

struct TabItem: Identifiable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var fileURL: URL?
    
    init(id: UUID = UUID(), title: String, content: String = "", fileURL: URL? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.fileURL = fileURL
    }
}
