import XCTest
@testable import Pomodoro

final class MockNotificationService: NotificationServiceProtocol, @unchecked Sendable {
    var scheduledCalls: [(phase: PomodoroPhase, taskTitle: String?, duration: TimeInterval)] = []
    var cancelCallsCount: Int = 0

    func requestAuthorization() async -> Bool {
        return true
    }

    func schedulePhaseCompletion(phase: PomodoroPhase, taskTitle: String?, duration: TimeInterval) {
        scheduledCalls.append((phase, taskTitle, duration))
    }

    func cancelPendingPhaseNotification() {
        cancelCallsCount += 1
    }
}

final class NotificationIntegrationTests: XCTestCase {
    @MainActor
    func testNotificationLifecycleWithSessionCoordinator() async {
        let mockService = MockNotificationService()
        let engine = PomodoroCoreEngine(preset: .testFast)
        let coordinator = SessionCoordinator(
            engine: engine,
            notificationService: mockService,
            store: .ephemeral
        )

        // 1. Iniciar sesión -> debe programar notificación de trabajo
        coordinator.currentTaskInput = "Feature de Watch"
        await coordinator.startSession()

        XCTAssertEqual(mockService.scheduledCalls.count, 1)
        XCTAssertEqual(mockService.scheduledCalls.first?.phase, .work)
        XCTAssertEqual(mockService.scheduledCalls.first?.taskTitle, "Feature de Watch")

        // 2. Pausar sesión -> debe cancelar notificación pendiente
        await coordinator.pauseSession()
        XCTAssertEqual(mockService.cancelCallsCount, 1)

        // 3. Reanudar sesión -> debe reprogramar con el tiempo restante
        await coordinator.resumeSession()
        XCTAssertEqual(mockService.scheduledCalls.count, 2)
        XCTAssertEqual(mockService.scheduledCalls.last?.phase, .work)

        // 4. Añadir dos minutos -> reprograma con nuevo tiempo
        await coordinator.addTwoMinutes()
        XCTAssertEqual(mockService.scheduledCalls.count, 3)

        // 5. Cancelar sesión -> cancela notificaciones
        await coordinator.cancelSession()
        XCTAssertEqual(mockService.cancelCallsCount, 2)
        XCTAssertEqual(coordinator.snapshot.phase, .idle)
    }
}
