import Foundation

enum AppLanguage: String, Codable, CaseIterable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var localizedNameKey: String {
        switch self {
        case .system:
            "System Default"
        case .english:
            "English"
        case .simplifiedChinese:
            "Simplified Chinese"
        }
    }
}
