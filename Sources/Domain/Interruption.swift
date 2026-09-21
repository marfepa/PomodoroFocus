import Foundation

/// Tipo de interferencia según la metodología de Francesco Cirillo.
public enum InterruptionType: String, CaseIterable, Sendable, Codable {
    /// Estímulo intrínseco (deseo repentino de revisar el correo, navegar o consultar el móvil).
    /// Notación clásica: Apóstrofe (').
    case `internal`
    
    /// Estímulo extrínseco (mensajes de Slack, llamadas, interrupciones presenciales).
    /// Notación clásica: Guion (-).
    case external

    public var notation: String {
        switch self {
        case .internal:
            return "'"
        case .external:
            return "-"
        }
    }

    public var title: String {
        switch self {
        case .internal:
            return "Interrupción Interna"
        case .external:
            return "Interrupción Externa"
        }
    }
}

/// Registro individual de interrupción durante una sesión de trabajo.
public struct InterruptionRecord: Identifiable, Sendable, Codable {
    public let id: UUID
    public let type: InterruptionType
    public let note: String
    public let timestamp: Date
    public let phase: PomodoroPhase
    public let associatedTask: String?

    public init(
        id: UUID = UUID(),
        type: InterruptionType,
        note: String,
        timestamp: Date = Date(),
        phase: PomodoroPhase,
        associatedTask: String? = nil
    ) {
        self.id = id
        self.type = type
        self.note = note
        self.timestamp = timestamp
        self.phase = phase
        self.associatedTask = associatedTask
    }
}
