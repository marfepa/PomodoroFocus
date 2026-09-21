import SwiftUI

/// Representa las fases temporales del ciclo Pomodoro.
public enum PomodoroPhase: String, CaseIterable, Sendable, Codable {
    case idle
    case work
    case shortBreak
    case longBreak
    case overtime

    public var title: String {
        switch self {
        case .idle:
            return "En espera"
        case .work:
            return "Enfoque"
        case .shortBreak:
            return "Descanso Corto"
        case .longBreak:
            return "Descanso Largo"
        case .overtime:
            return "Tiempo Excedido"
        }
    }

    public var systemImageName: String {
        switch self {
        case .idle:
            return "play.circle.fill"
        case .work:
            return "brain.head.profile"
        case .shortBreak:
            return "cup.and.saucer.fill"
        case .longBreak:
            return "figure.walk"
        case .overtime:
            return "exclamationmark.triangle.fill"
        }
    }

    public var accentColor: Color {
        switch self {
        case .idle:
            return Color(nsColor: .secondaryLabelColor)
        case .work:
            return Color.orange
        case .shortBreak:
            return Color.mint
        case .longBreak:
            return Color.cyan
        case .overtime:
            return Color.yellow
        }
    }

    public var ergonomicAdvice: String? {
        switch self {
        case .shortBreak:
            return "Respira profundo, bebe un vaso de agua y relaja la vista mirando a lo lejos (regla 20-20-20)."
        case .longBreak:
            return "¡Excelente trabajo! Has completado un macro-ciclo de 4 pomodoros. Camina y desconecta del monitor."
        case .overtime:
            return "El tiempo planificado ha concluido. Puedes cerrar el flujo y tomar tu descanso."
        default:
            return nil
        }
    }
}
