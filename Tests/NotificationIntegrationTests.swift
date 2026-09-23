import XCTest
@testable import Pomodoro

final class MockNotificationService: NotificationServiceProtocol, @unchecked Sendable {
    var scheduledCalls: [(phase: PomodoroPhase, taskTitle: String?, duration: TimeInterval)] = []
    var reminderCalls: [(taskTitle: String?, delay: TimeInterval)] = []
    var cancelCallsCount: Int = 0

    func requestAuthorization() async -> Bool {
        return true
    }

    func schedulePhaseCompletion(phase: PomodoroPhase, taskTitle: String?, duration: TimeInterval) {
        scheduledCalls.append((phase, taskTitle, duration))
    }

    func scheduleOvertimeReminder(taskTitle: String?, after delay: TimeInterval) {
        reminderCalls.append((taskTitle, delay))
    }

    func cancelPendingPhaseNotification() {
        cancelCallsCount += 1
    }
}

final class NotificationIntegrationTests: XCTestCase {
    /// Sin automatización de Concentración: los tests no deben lanzar atajos reales del usuario.
    @MainActor
    private func makeCoordinator(
        engine: PomodoroCoreEngine = PomodoroCoreEngine(preset: .testFast),
        notificationService: MockNotificationService = MockNotificationService()
    ) -> SessionCoordinator {
        let coordinator = SessionCoordinator(engine: engine, notificationService: notificationService, store: .ephemeral)
        coordinator.enableFocusAutomation = false
        return coordinator
    }

    @MainActor
    func testNotificationLifecycleWithSessionCoordinator() async {
        let mockService = MockNotificationService()
        let coordinator = makeCoordinator(notificationService: mockService)

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

    @MainActor
    func testAddTwoMinutesDuringOvertimeSchedulesReminder() async {
        let mockService = MockNotificationService()
        let engine = PomodoroCoreEngine(preset: .testFast)
        let coordinator = makeCoordinator(engine: engine, notificationService: mockService)

        await engine.startWork(taskTitle: "Informe")
        _ = await engine.enterOvertime(at: Date().addingTimeInterval(11))

        await coordinator.addTwoMinutes()

        XCTAssertEqual(coordinator.snapshot.phase, .overtime)
        XCTAssertTrue(mockService.scheduledCalls.isEmpty)
        XCTAssertEqual(mockService.reminderCalls.count, 1)
        XCTAssertEqual(mockService.reminderCalls.first?.taskTitle, "Informe")
        XCTAssertEqual(mockService.reminderCalls.first?.delay, 120)

        // Pausar en overtime no hace nada y no debe borrar el recordatorio.
        await coordinator.pauseSession()
        XCTAssertFalse(coordinator.snapshot.isPaused)
        XCTAssertEqual(mockService.cancelCallsCount, 0)
    }

    @MainActor
    func testAddTwoMinutesWhilePausedDoesNotScheduleNotification() async {
        let mockService = MockNotificationService()
        let coordinator = makeCoordinator(notificationService: mockService)
        await coordinator.startSession()
        await coordinator.pauseSession()
        let scheduledBefore = mockService.scheduledCalls.count

        await coordinator.addTwoMinutes()

        XCTAssertEqual(mockService.scheduledCalls.count, scheduledBefore)
        XCTAssertTrue(coordinator.snapshot.isPaused)
    }

    @MainActor
    func testTickerOnlyRunsWithActiveSession() async {
        let coordinator = makeCoordinator()
        await coordinator.selectPreset(.standard25)
        XCTAssertFalse(coordinator.isTickerRunning)

        await coordinator.startSession()
        XCTAssertTrue(coordinator.isTickerRunning)

        await coordinator.pauseSession()
        XCTAssertFalse(coordinator.isTickerRunning)

        await coordinator.resumeSession()
        XCTAssertTrue(coordinator.isTickerRunning)

        await coordinator.cancelSession()
        XCTAssertFalse(coordinator.isTickerRunning)
    }
}
