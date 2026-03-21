import Foundation

enum TabBehavior: String, Codable, CaseIterable {
    case tab = "Tab"
    case spaces2 = "2 Spaces"
    case spaces4 = "4 Spaces"
    
    var stringValue: String {
        switch self {
        case .tab:
            return "\t"
        case .spaces2:
            return "  "
        case .spaces4:
            return "    "
        }
    }
}
