import Foundation

struct WorkspacePreferences: Codable, Equatable {
    private enum EditorFontMetrics {
        static let defaultSize: CGFloat = 13
        static let minimumSize: CGFloat = 10
        static let maximumSize: CGFloat = 36
        static let rememberedFileLimit = 5_000
    }

    struct RememberedEditorFontSize: Codable, Equatable {
        var size: CGFloat
        var lastAccessSequence: UInt64
    }

    struct EditorTextSoftnessConfiguration: Codable, Equatable {
        var lightModeTextSoftness: CGFloat = 0.16
        var darkModeTextSoftness: CGFloat = 0.22
        var highContrastTextSoftness: CGFloat = 0.08

        private enum CodingKeys: String, CodingKey, CaseIterable {
            case lightModeTextSoftness
            case darkModeTextSoftness
            case highContrastTextSoftness
        }

        init(
            lightModeTextSoftness: CGFloat = 0.16,
            darkModeTextSoftness: CGFloat = 0.22,
            highContrastTextSoftness: CGFloat = 0.08
        ) {
            self.lightModeTextSoftness = lightModeTextSoftness
            self.darkModeTextSoftness = darkModeTextSoftness
            self.highContrastTextSoftness = highContrastTextSoftness
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let defaults = Self()
            lightModeTextSoftness = try container.decodeIfPresent(
                CGFloat.self,
                forKey: .lightModeTextSoftness
            ) ?? defaults.lightModeTextSoftness
            darkModeTextSoftness = try container.decodeIfPresent(
                CGFloat.self,
                forKey: .darkModeTextSoftness
            ) ?? defaults.darkModeTextSoftness
            highContrastTextSoftness = try container.decodeIfPresent(
                CGFloat.self,
                forKey: .highContrastTextSoftness
            ) ?? defaults.highContrastTextSoftness
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(lightModeTextSoftness, forKey: .lightModeTextSoftness)
            try container.encode(darkModeTextSoftness, forKey: .darkModeTextSoftness)
            try container.encode(highContrastTextSoftness, forKey: .highContrastTextSoftness)
        }

        func sanitized() -> Self {
            Self(
                lightModeTextSoftness: lightModeTextSoftness.clamped(to: 0...1),
                darkModeTextSoftness: darkModeTextSoftness.clamped(to: 0...1),
                highContrastTextSoftness: highContrastTextSoftness.clamped(to: 0...1)
            )
        }

        func formattedJSONString() throws -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(sanitized())
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw JSONConfigurationError.invalidEncoding
            }
            return jsonString
        }

        static func decodeValidating(jsonString: String) throws -> Self {
            let data = Data(jsonString.utf8)
            let rawObject = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = rawObject as? [String: Any] else {
                throw JSONConfigurationError.rootMustBeObject
            }

            let allowedKeys = Set(CodingKeys.allCases.map(\.rawValue))
            let unknownKeys = Set(dictionary.keys).subtracting(allowedKeys)
            if let firstUnknownKey = unknownKeys.sorted().first {
                throw JSONConfigurationError.unknownKey(firstUnknownKey)
            }

            let decoder = JSONDecoder()
            do {
                return try decoder.decode(Self.self, from: data).sanitized()
            } catch {
                throw JSONConfigurationError.invalidStructure(error.localizedDescription)
            }
        }

        enum JSONConfigurationError: LocalizedError {
            case rootMustBeObject
            case unknownKey(String)
            case invalidStructure(String)
            case invalidEncoding

            var errorDescription: String? {
                switch self {
                case .rootMustBeObject:
                    return String(
                        localized: "JSON must be an object, for example { \"lightModeTextSoftness\": 0.16 }."
                    )
                case .unknownKey(let key):
                    let messageFormat = String(
                        localized: "Unknown key %@. Use only the supported text softness keys."
                    )
                    return String(format: messageFormat, key)
                case .invalidStructure(let message):
                    let messageFormat = String(
                        localized: "Invalid JSON structure or value type: %@"
                    )
                    return String(format: messageFormat, message)
                case .invalidEncoding:
                    return String(localized: "Could not generate configuration JSON.")
                }
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case editorFontSize
        case rememberedEditorFontSizes
        case nextEditorFontAccessSequence
        case tabBehavior
        case appLanguage
        case editorTextSoftness
    }

    var editorFontSize: CGFloat = EditorFontMetrics.defaultSize
    var rememberedEditorFontSizes: [String: RememberedEditorFontSize] = [:]
    var tabBehavior: TabBehavior = .spaces2
    var appLanguage: AppLanguage = .system
    var editorTextSoftness = EditorTextSoftnessConfiguration()
    private var nextEditorFontAccessSequence: UInt64 = 0

    init(
        editorFontSize: CGFloat = EditorFontMetrics.defaultSize,
        rememberedEditorFontSizes: [String: RememberedEditorFontSize] = [:],
        tabBehavior: TabBehavior = .spaces2,
        appLanguage: AppLanguage = .system,
        editorTextSoftness: EditorTextSoftnessConfiguration = EditorTextSoftnessConfiguration()
    ) {
        self.editorFontSize = Self.clampedEditorFontSize(editorFontSize)
        self.rememberedEditorFontSizes = rememberedEditorFontSizes
        self.tabBehavior = tabBehavior
        self.appLanguage = appLanguage
        self.editorTextSoftness = editorTextSoftness.sanitized()
        normalizeRememberedEditorFontSizes()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self()
        editorFontSize = Self.clampedEditorFontSize(try container.decodeIfPresent(
            CGFloat.self,
            forKey: .editorFontSize
        ) ?? defaults.editorFontSize)
        rememberedEditorFontSizes = try container.decodeIfPresent(
            [String: RememberedEditorFontSize].self,
            forKey: .rememberedEditorFontSizes
        ) ?? defaults.rememberedEditorFontSizes
        nextEditorFontAccessSequence = try container.decodeIfPresent(
            UInt64.self,
            forKey: .nextEditorFontAccessSequence
        ) ?? defaults.nextEditorFontAccessSequence
        tabBehavior = try container.decodeIfPresent(
            TabBehavior.self,
            forKey: .tabBehavior
        ) ?? defaults.tabBehavior
        appLanguage = try container.decodeIfPresent(
            AppLanguage.self,
            forKey: .appLanguage
        ) ?? defaults.appLanguage
        editorTextSoftness = try container.decodeIfPresent(
            EditorTextSoftnessConfiguration.self,
            forKey: .editorTextSoftness
        )?.sanitized() ?? defaults.editorTextSoftness
        normalizeRememberedEditorFontSizes()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(editorFontSize, forKey: .editorFontSize)
        try container.encode(rememberedEditorFontSizes, forKey: .rememberedEditorFontSizes)
        try container.encode(nextEditorFontAccessSequence, forKey: .nextEditorFontAccessSequence)
        try container.encode(tabBehavior, forKey: .tabBehavior)
        try container.encode(appLanguage, forKey: .appLanguage)
        try container.encode(editorTextSoftness.sanitized(), forKey: .editorTextSoftness)
    }

    static var defaultEditorFontSize: CGFloat {
        EditorFontMetrics.defaultSize
    }

    mutating func applyRememberedEditorFontSize(for fileURL: URL?) {
        let nextSize = rememberedEditorFontSize(for: fileURL) ?? Self.defaultEditorFontSize
        editorFontSize = Self.clampedEditorFontSize(nextSize)

        guard let key = rememberedEditorFontSizeKey(for: fileURL),
              rememberedEditorFontSizes[key] != nil else {
            return
        }

        touchRememberedEditorFontSize(forKey: key)
    }

    mutating func stepEditorFontSize(by delta: CGFloat, rememberingFor fileURL: URL?) -> Bool {
        let nextSize = (editorFontSize + delta).clamped(
            to: EditorFontMetrics.minimumSize...EditorFontMetrics.maximumSize
        )
        guard nextSize != editorFontSize else {
            return false
        }

        editorFontSize = nextSize
        rememberEditorFontSize(nextSize, for: fileURL)
        return true
    }

    mutating func rememberCurrentEditorFontSize(for fileURL: URL?) {
        rememberEditorFontSize(editorFontSize, for: fileURL)
    }

    mutating func moveRememberedEditorFontSize(from sourceFileURL: URL?, to destinationFileURL: URL?) {
        guard let sourceKey = rememberedEditorFontSizeKey(for: sourceFileURL),
              let destinationKey = rememberedEditorFontSizeKey(for: destinationFileURL),
              sourceKey != destinationKey,
              let rememberedSize = rememberedEditorFontSizes.removeValue(forKey: sourceKey) else {
            return
        }

        rememberedEditorFontSizes[destinationKey] = RememberedEditorFontSize(
            size: Self.clampedEditorFontSize(rememberedSize.size),
            lastAccessSequence: nextRememberedEditorFontAccessSequence()
        )
        trimRememberedEditorFontSizesIfNeeded()
    }

    private static func clampedEditorFontSize(_ editorFontSize: CGFloat) -> CGFloat {
        editorFontSize.clamped(to: EditorFontMetrics.minimumSize...EditorFontMetrics.maximumSize)
    }

    private func rememberedEditorFontSizeKey(for fileURL: URL?) -> String? {
        guard let fileURL else {
            return nil
        }

        return fileURL.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func rememberedEditorFontSize(for fileURL: URL?) -> CGFloat? {
        guard let key = rememberedEditorFontSizeKey(for: fileURL) else {
            return nil
        }

        return rememberedEditorFontSizes[key]?.size
    }

    private mutating func rememberEditorFontSize(_ fontSize: CGFloat, for fileURL: URL?) {
        guard let key = rememberedEditorFontSizeKey(for: fileURL) else {
            return
        }

        rememberedEditorFontSizes[key] = RememberedEditorFontSize(
            size: Self.clampedEditorFontSize(fontSize),
            lastAccessSequence: nextRememberedEditorFontAccessSequence()
        )
        trimRememberedEditorFontSizesIfNeeded()
    }

    private mutating func touchRememberedEditorFontSize(forKey key: String) {
        guard var rememberedSize = rememberedEditorFontSizes[key] else {
            return
        }

        rememberedSize.lastAccessSequence = nextRememberedEditorFontAccessSequence()
        rememberedEditorFontSizes[key] = rememberedSize
    }

    private mutating func nextRememberedEditorFontAccessSequence() -> UInt64 {
        if nextEditorFontAccessSequence == .max {
            reindexRememberedEditorFontSizes()
        }

        let currentSequence = nextEditorFontAccessSequence
        nextEditorFontAccessSequence += 1
        return currentSequence
    }

    private mutating func normalizeRememberedEditorFontSizes() {
        rememberedEditorFontSizes = rememberedEditorFontSizes.mapValues {
            RememberedEditorFontSize(
                size: Self.clampedEditorFontSize($0.size),
                lastAccessSequence: $0.lastAccessSequence
            )
        }
        trimRememberedEditorFontSizesIfNeeded()
        reindexRememberedEditorFontSizes()
    }

    private mutating func trimRememberedEditorFontSizesIfNeeded() {
        let overflowCount = rememberedEditorFontSizes.count - EditorFontMetrics.rememberedFileLimit
        guard overflowCount > 0 else {
            return
        }

        let keysToEvict = rememberedEditorFontSizes
            .sorted { lhs, rhs in
                lhs.value.lastAccessSequence < rhs.value.lastAccessSequence
            }
            .prefix(overflowCount)
            .map(\.key)

        for key in keysToEvict {
            rememberedEditorFontSizes.removeValue(forKey: key)
        }
    }

    private mutating func reindexRememberedEditorFontSizes() {
        let sortedEntries = rememberedEditorFontSizes
            .sorted { lhs, rhs in
                lhs.value.lastAccessSequence < rhs.value.lastAccessSequence
            }

        var reindexedEntries: [String: RememberedEditorFontSize] = [:]
        reindexedEntries.reserveCapacity(sortedEntries.count)

        for (index, entry) in sortedEntries.enumerated() {
            reindexedEntries[entry.key] = RememberedEditorFontSize(
                size: entry.value.size,
                lastAccessSequence: UInt64(index)
            )
        }

        rememberedEditorFontSizes = reindexedEntries
        nextEditorFontAccessSequence = UInt64(sortedEntries.count)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
