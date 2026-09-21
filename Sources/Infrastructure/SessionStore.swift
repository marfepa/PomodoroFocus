import Foundation

/// Ajustes que sobreviven al cierre de la app.
public struct PersistedSettings: Codable, Sendable, Equatable {
    public var presetID: String
    public var workShortcutName: String
    public var defaultShortcutName: String
    public var enableFocusAutomation: Bool
    public var shouldMinimizeOnStart: Bool

    public init(
        presetID: String,
        workShortcutName: String,
        defaultShortcutName: String,
        enableFocusAutomation: Bool,
        shouldMinimizeOnStart: Bool
    ) {
        self.presetID = presetID
        self.workShortcutName = workShortcutName
        self.defaultShortcutName = defaultShortcutName
        self.enableFocusAutomation = enableFocusAutomation
        self.shouldMinimizeOnStart = shouldMinimizeOnStart
    }
}

/// Sesión, diario y ajustes en un único JSON de Application Support.
public struct PersistedSession: Codable, Sendable, Equatable {
    public var settings: PersistedSettings
    public var checkpoint: EngineCheckpoint

    public init(settings: PersistedSettings, checkpoint: EngineCheckpoint) {
        self.settings = settings
        self.checkpoint = checkpoint
    }
}

/// Lectura y escritura atómica del estado. Sin URL, no toca el disco (tests).
public struct SessionStore: Sendable {
    public let fileURL: URL?

    public init(fileURL: URL?) {
        self.fileURL = fileURL
    }

    public static let ephemeral = SessionStore(fileURL: nil)

    public static func production() -> SessionStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = base.appendingPathComponent("Pomodoro", isDirectory: true)
        return SessionStore(fileURL: directory.appendingPathComponent("session.json"))
    }

    public func load() -> PersistedSession? {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? Self.decoder.decode(PersistedSession.self, from: data)
    }

    public func save(_ session: PersistedSession) {
        guard let fileURL else { return }
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try Self.encoder.encode(session)
            let temporary = directory.appendingPathComponent("session-\(UUID().uuidString).json")
            try data.write(to: temporary, options: .atomic)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: fileURL)
            }
        } catch {
            return
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
