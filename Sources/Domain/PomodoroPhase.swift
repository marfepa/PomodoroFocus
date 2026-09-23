import SwiftUI
import AppKit

/// Representa las fases temporales del ciclo Pomodoro.
public enum PomodoroPhase: String, CaseIterable, Sendable, Codable, Equatable {
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
            return "En flow"
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
            return "flame.fill"
        }
    }

    public var nsAccentColor: NSColor {
        switch self {
        case .idle:
            return .secondaryLabelColor
        case .work:
            return .systemOrange
        case .shortBreak:
            return .systemMint
        case .longBreak:
            return .systemCyan
        case .overtime:
            return .systemYellow
        }
    }

    public var accentColor: Color {
        Color(nsColor: nsAccentColor)
    }

    /// Acento para texto sobre fondos claros: el amarillo y el menta puros no se leen en modo claro.
    public var legibleAccentColor: Color {
        let phase = self
        return Color(nsColor: NSColor(name: nil) { appearance in
            let base = phase.nsAccentColor
            guard appearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua else { return base }
            return base.blended(withFraction: 0.35, of: .black) ?? base
        })
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
