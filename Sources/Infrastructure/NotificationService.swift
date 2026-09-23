import Foundation
import UserNotifications

/// Acciones interactivas ejecutables desde las notificaciones (Mac y Apple Watch).
public enum NotificationActionIdentifier: String, Sendable {
    case startBreak = "ACTION_START_BREAK"
    case startWork = "ACTION_START_WORK"
    case extendTwoMinutes = "ACTION_EXTEND_2MIN"
}

/// Categorías de notificación registradas.
public enum NotificationCategoryIdentifier: String, Sendable {
    case workEnded = "CATEGORY_WORK_ENDED"
    case breakEnded = "CATEGORY_BREAK_ENDED"
}

/// Identificador constante de la notificación de temporizador activo.
public let kPomodoroTimerNotificationIdentifier = "com.antigravity.pomodoro.timer-ended"

/// Protocolo para desacoplar el gestor de notificaciones de la UI y permitir tests.
public protocol NotificationServiceProtocol: AnyObject, Sendable {
    func requestAuthorization() async -> Bool
    func schedulePhaseCompletion(phase: PomodoroPhase, taskTitle: String?, duration: TimeInterval)
    /// Recordatorio de cierre durante el overtime: el bloque ya venció y no hay cuenta atrás que alargar.
    func scheduleOvertimeReminder(taskTitle: String?, after delay: TimeInterval)
    func cancelPendingPhaseNotification()
}

/// Servicio encargado de programar notificaciones interactivas locales con sonido y alerta háptica para el Apple Watch.
public final class NotificationService: NSObject, NotificationServiceProtocol, UNUserNotificationCenterDelegate, @unchecked Sendable {
    public static let shared = NotificationService()

    private let center: UNUserNotificationCenter

    public var onActionReceived: (@MainActor (NotificationActionIdentifier) -> Void)?

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        self.center.delegate = self
        registerCategories()
    }

    /// Solicita autorización al usuario para enviar alertas y sonidos.
    @discardableResult
    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    /// Registra las categorías de notificaciones con botones de acción rápida para Mac y Apple Watch.
    private func registerCategories() {
        let startBreakAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.startBreak.rawValue,
            title: "Iniciar Descanso",
            options: [.foreground]
        )

        let extendTwoMinutesAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.extendTwoMinutes.rawValue,
            title: "+2 minutos",
            options: []
        )

        let startWorkAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.startWork.rawValue,
            title: "Iniciar Bloque",
            options: [.foreground]
        )

        let workCategory = UNNotificationCategory(
            identifier: NotificationCategoryIdentifier.workEnded.rawValue,
            actions: [startBreakAction, extendTwoMinutesAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Sin «+2 minutos»: cuando llega el aviso, el descanso ya ha terminado y no hay nada que alargar.
        let breakCategory = UNNotificationCategory(
            identifier: NotificationCategoryIdentifier.breakEnded.rawValue,
            actions: [startWorkAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        center.setNotificationCategories([workCategory, breakCategory])
    }

    /// Programa una notificación para el momento exacto en que termina la fase en curso.
    public func schedulePhaseCompletion(phase: PomodoroPhase, taskTitle: String?, duration: TimeInterval) {
        // Cancelar cualquier notificación programada previa para no duplicar
        cancelPendingPhaseNotification()

        guard duration > 0 else { return }

        let content = UNMutableNotificationContent()
        
        // Sonido estándar del sistema para activar la vibración háptica destacada en el Apple Watch
        content.sound = .default

        switch phase {
        case .work:
            content.title = "¡Tiempo de Enfoque Completado! 🍅"
            if let task = taskTitle, !task.isEmpty {
                content.body = "Completaste: \"\(task)\". Tómate un respiro merecido."
            } else {
                content.body = "Buen trabajo. Es momento de un descanso."
            }
            content.categoryIdentifier = NotificationCategoryIdentifier.workEnded.rawValue

        case .shortBreak, .longBreak:
            content.title = "Descanso Terminado ⚡️"
            content.body = "¿Listo para volver a concentrarte?"
            content.categoryIdentifier = NotificationCategoryIdentifier.breakEnded.rawValue

        case .idle, .overtime:
            return
        }

        enqueue(content, after: duration)
    }

    public func scheduleOvertimeReminder(taskTitle: String?, after delay: TimeInterval) {
        cancelPendingPhaseNotification()
        guard delay > 0 else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.title = "¿Cerramos el bloque? 🍅"
        if let task = taskTitle, !task.isEmpty {
            content.body = "Sigues en flow con \"\(task)\". Es buen momento para descansar."
        } else {
            content.body = "Sigues en flow. Es buen momento para descansar."
        }
        content.categoryIdentifier = NotificationCategoryIdentifier.workEnded.rawValue
        content.userInfo = [Self.overtimeReminderKey: true]
        enqueue(content, after: delay)
    }

    private static let overtimeReminderKey = "overtimeReminder"

    /// Cancela notificaciones pendientes cuando se cancela o pausa la sesión.
    public func cancelPendingPhaseNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [kPomodoroTimerNotificationIdentifier])
    }

    private func enqueue(_ content: UNMutableNotificationContent, after delay: TimeInterval) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: kPomodoroTimerNotificationIdentifier,
            content: content,
            trigger: trigger
        )
        center.add(request) { _ in }
    }

    // MARK: - UNUserNotificationCenterDelegate
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Los fines de fase no suenan aquí: el coordinador ya reproduce su sonido en la transición.
        let isReminder = notification.request.content.userInfo[Self.overtimeReminderKey] as? Bool == true
        completionHandler(isReminder ? [.banner, .sound, .list] : [.banner, .list])
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionRaw = response.actionIdentifier
        if let action = NotificationActionIdentifier(rawValue: actionRaw) {
            Task { @MainActor in
                self.onActionReceived?(action)
            }
        }
        completionHandler()
    }
}
