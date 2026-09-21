import AppIntents
import Foundation

/// Filtro de Concentración nativo para la Mac App Store mediante el framework AppIntents.
public struct PomodoroFocusFilter: SetFocusFilterIntent {
    public static let title: LocalizedStringResource = "Filtro de Modo Pomodoro"
    public static let description = LocalizedStringResource("Ajusta la supresión de notificaciones durante los intervalos de trabajo activo.")

    @Parameter(title: "Silenciar Notificaciones", default: true)
    public var silenceAllAlerts: Bool

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: Self.title)
    }

    public var appContext: FocusFilterAppContext {
        FocusFilterAppContext(notificationFilterPredicate: NSPredicate(value: !silenceAllAlerts))
    }

    public init() {
        self.silenceAllAlerts = true
    }

    public func perform() async throws -> some IntentResult {
        // Notificar a los coordinadores sobre el cambio de estado del filtro
        await MainActor.run {
            NotificationCenter.default.post(name: .pomodoroFocusModeEngaged, object: nil)
        }
        return .result()
    }
}
