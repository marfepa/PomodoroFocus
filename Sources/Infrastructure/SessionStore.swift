import Foundation
import os

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

    /// Un archivo ilegible se aparta como `session.corrupt-<fecha>.json` para que el siguiente guardado no lo destruya.
    public func load() -> PersistedSession? {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try Self.decoder.decode(PersistedSession.self, from: data)
        } catch {
            Self.logger.error("No se pudo leer la sesión guardada: \(error.localizedDescription, privacy: .public)")
            quarantine(fileURL)
            return nil
        }
    }

    public func save(_ session: PersistedSession) {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoder.encode(session).write(to: fileURL, options: .atomic)
        } catch {
            Self.logger.error("No se pudo guardar la sesión: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func quarantine(_ fileURL: URL) {
        let stamp = Int(Date().timeIntervalSince1970)
        let backup = fileURL.deletingLastPathComponent()
            .appendingPathComponent("session.corrupt-\(stamp).json")
        do {
            try FileManager.default.moveItem(at: fileURL, to: backup)
        } catch {
            Self.logger.error("No se pudo apartar la sesión ilegible: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static let logger = Logger(subsystem: "com.antigravity.pomodoro", category: "SessionStore")

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

/// Escribe fuera del hilo principal. Si dos guardados llegan desordenados, gana el más reciente.
public actor SessionWriter {
    private let store: SessionStore
    private var lastWrittenGeneration = 0

    public init(store: SessionStore) {
        self.store = store
    }

    public func write(_ session: PersistedSession, generation: Int) {
        guard generation > lastWrittenGeneration else { return }
        lastWrittenGeneration = generation
        store.save(session)
    }
}
