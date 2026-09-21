import XCTest
@testable import Pomodoro

final class PomodoroCoreEngineTests: XCTestCase {

    func testCalculatorDeterministicRemainingTime() {
        let start = Date()
        let duration: TimeInterval = 1500 // 25 min
        let calculator = PomodoroStateCalculator(duration: duration, startTimestamp: start)

        // Comprobación diferencial al inicio
        let remainingAtStart = calculator.computeRemainingTime(at: start)
        XCTAssertEqual(remainingAtStart, 1500, accuracy: 0.001)

        // Comprobación a mitad del intervalo (10 minutos después)
        let mid = start.addingTimeInterval(600)
        let remainingAtMid = calculator.computeRemainingTime(at: mid)
        XCTAssertEqual(remainingAtMid, 900, accuracy: 0.001)

        // Comprobación del progreso
        let progress = calculator.computeProgress(at: mid)
        XCTAssertEqual(progress, 600.0 / 1500.0, accuracy: 0.001)

        // Comprobación al expirar
        let end = start.addingTimeInterval(1500)
        XCTAssertTrue(calculator.isExpired(at: end))
        XCTAssertEqual(calculator.computeRemainingTime(at: end), 0, accuracy: 0.001)

        // Comprobación de overtime / flow (2 minutos excedidos)
        let overtimeDate = end.addingTimeInterval(120)
        XCTAssertEqual(calculator.computeOvertime(at: overtimeDate), 120, accuracy: 0.001)
    }

    func testCalculatorAddingTime() {
        let start = Date()
        let calculator = PomodoroStateCalculator(duration: 300, startTimestamp: start)
        let extended = calculator.addingTime(120)

        XCTAssertEqual(extended.duration, 420, accuracy: 0.001)
        XCTAssertEqual(extended.computeRemainingTime(at: start), 420, accuracy: 0.001)
    }

    func testCoreEngineTransitionsAndCirilloCycle() async {
        let engine = PomodoroCoreEngine(preset: .testFast)

        var snap = await engine.getSnapshot()
        XCTAssertEqual(snap.phase, .idle)

        // Iniciar trabajo
        await engine.startWork(taskTitle: "Desarrollar feature")
        snap = await engine.getSnapshot()
        XCTAssertEqual(snap.phase, .work)
        XCTAssertEqual(snap.currentTaskTitle, "Desarrollar feature")
        XCTAssertEqual(snap.currentBlockInCycle, 1)

        // Registrar interrupción interna (apóstrofe ')
        await engine.recordInterruption(type: .internal, note: "Revisar email urgente")
        snap = await engine.getSnapshot()
        XCTAssertEqual(snap.internalInterruptionsCount, 1)
        XCTAssertEqual(snap.phase, .work, "La regla de Cirillo exige que la interrupción interna no detenga la fase")

        // El trabajo vencido entra en flow y cuenta el pomodoro, sin saltar al descanso.
        let expired = Date().addingTimeInterval(11)
        let overtime = await engine.enterOvertime(at: expired)
        XCTAssertEqual(overtime, .overtime)
        snap = await engine.getSnapshot(at: expired)
        XCTAssertEqual(snap.currentBlockInCycle, 1)
        XCTAssertEqual(snap.completedBlocksInCycle, 1)
        XCTAssertEqual(snap.completedPomodorosToday, 1)
        XCTAssertGreaterThan(snap.overtimeSeconds, 0)

        // Una segunda llamada no vuelve a contar el mismo bloque.
        let stillOvertime = await engine.enterOvertime(at: expired.addingTimeInterval(5))
        XCTAssertEqual(stillOvertime, .overtime)
        snap = await engine.getSnapshot(at: expired)
        XCTAssertEqual(snap.completedPomodorosToday, 1)

        // Tomar descanso abre el corto y deja el bloque 2 preparado.
        let breakPhase = await engine.beginBreak(at: expired)
        XCTAssertEqual(breakPhase, .shortBreak)
        snap = await engine.getSnapshot()
        XCTAssertEqual(snap.completedBlocksInCycle, 1)

        let phaseAfterBreak = await engine.transitionOnExpiry(at: Date().addingTimeInterval(20))
        XCTAssertEqual(phaseAfterBreak, .idle)
        snap = await engine.getSnapshot()
        XCTAssertEqual(snap.currentBlockInCycle, 2)

        // Bloque 2 de 2 cierra el ciclo con descanso largo.
        await engine.startWork(taskTitle: "Completar tarea")
        let secondExpiry = Date().addingTimeInterval(11)
        let secondOvertime = await engine.enterOvertime(at: secondExpiry)
        XCTAssertEqual(secondOvertime, .overtime)
        let longBreak = await engine.beginBreak(at: secondExpiry)
        XCTAssertEqual(longBreak, .longBreak)
        snap = await engine.getSnapshot()
        XCTAssertEqual(snap.completedPomodorosToday, 2)
        XCTAssertEqual(snap.phase, .longBreak)

        let afterLongBreak = await engine.transitionOnExpiry(at: Date().addingTimeInterval(20))
        XCTAssertEqual(afterLongBreak, .idle)
        snap = await engine.getSnapshot()
        XCTAssertEqual(snap.currentBlockInCycle, 1)
        XCTAssertEqual(snap.completedBlocksInCycle, 0)
    }

    func testBeginBreakBeforeExpiryDoesNothing() async {
        let engine = PomodoroCoreEngine(preset: .testFast)
        await engine.startWork()
        let phase = await engine.beginBreak(at: Date())
        XCTAssertEqual(phase, .work)
    }

    func testCancelResetsCycleButKeepsInterruptions() async {
        let engine = PomodoroCoreEngine(preset: .testFast)
        await engine.startWork(taskTitle: "Borrador")
        await engine.recordInterruption(type: .external, note: "Llamada")
        await engine.resetToIdle()
        let snap = await engine.getSnapshot()
        XCTAssertEqual(snap.phase, .idle)
        XCTAssertEqual(snap.currentBlockInCycle, 1)
        XCTAssertNil(snap.currentTaskTitle)
        XCTAssertEqual(snap.externalInterruptionsCount, 1)
    }

    func testDayRolloverClearsTodayCount() async {
        let engine = PomodoroCoreEngine(preset: .testFast)
        await engine.startWork()
        let later = Date().addingTimeInterval(11)
        _ = await engine.enterOvertime(at: later)
        var checkpoint = await engine.exportCheckpoint(at: later)
        XCTAssertEqual(checkpoint.completedPomodorosToday, 1)

        checkpoint.dayStamp = "1999-01-01"
        await engine.importCheckpoint(checkpoint, at: later)
        let snap = await engine.getSnapshot(at: later)
        XCTAssertEqual(snap.completedPomodorosToday, 0)
    }

    func testSessionStoreRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SessionStore(fileURL: directory.appendingPathComponent("session.json"))
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let record = InterruptionRecord(
            type: .internal,
            note: "Revisar el correo",
            timestamp: now,
            phase: .work,
            associatedTask: "Informe"
        )
        let checkpoint = EngineCheckpoint(
            phase: .work,
            presetID: PomodoroPreset.standard25.id,
            taskTitle: "Informe",
            currentBlockInCycle: 2,
            completedBlocksInCycle: 1,
            nextBlockInCycle: 3,
            completedPomodorosToday: 1,
            dayStamp: PomodoroDay.stamp(now),
            isPaused: false,
            pausedRemainingTime: 0,
            duration: 25 * 60,
            startTimestamp: now,
            targetTimestamp: now.addingTimeInterval(25 * 60),
            interruptions: [record]
        )
        let settings = PersistedSettings(
            presetID: PomodoroPreset.deep45.id,
            workShortcutName: "Trabajo",
            defaultShortcutName: "Descanso",
            enableFocusAutomation: false,
            shouldMinimizeOnStart: false
        )
        store.save(PersistedSession(settings: settings, checkpoint: checkpoint))
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.settings, settings)
        XCTAssertEqual(loaded.checkpoint.taskTitle, "Informe")
        XCTAssertEqual(loaded.checkpoint.interruptions.first?.note, "Revisar el correo")

        try? FileManager.default.removeItem(at: directory)
    }

    func testIslandGeometryMatchesHitRect() {
        let metrics = DisplayNotchMetrics(
            frame: CGRect(x: 0, y: 0, width: 180, height: 32),
            hasHardwareNotch: true,
            screenFrame: CGRect(x: 0, y: 0, width: 1400, height: 900)
        )
        let geometry = IslandGeometry.current(
            metrics: metrics,
            isExpanded: true,
            isQuickCapturePresented: false,
            phase: .overtime
        )
        XCTAssertEqual(geometry.width, 350)
        XCTAssertEqual(geometry.height, 118)
        let rect = geometry.rect(panelWidth: 660, panelHeight: 280)
        XCTAssertEqual(rect.midX, 330, accuracy: 0.001)
        XCTAssertEqual(rect.maxY, 280, accuracy: 0.001)
    }

    func testPauseAndResumeDeterminism() async {
        let engine = PomodoroCoreEngine(preset: .standard25)
        let now = Date()

        await engine.startWork()
        await engine.pause(at: now.addingTimeInterval(300)) // Pausar a los 5 minutos

        var snap = await engine.getSnapshot(at: now.addingTimeInterval(300))
        XCTAssertTrue(snap.isPaused)
        XCTAssertEqual(snap.remainingSeconds, 20 * 60, accuracy: 1.0)

        // Simular que pasan 10 minutos con el Mac en pausa o suspendido
        let resumeDate = now.addingTimeInterval(900)
        await engine.resume(at: resumeDate)

        snap = await engine.getSnapshot(at: resumeDate)
        XCTAssertFalse(snap.isPaused)
        // El tiempo restante tras reanudar debe conservarse exactamente en 20 minutos
        XCTAssertEqual(snap.remainingSeconds, 20 * 60, accuracy: 1.0)
    }

    func testDisplayNotchMetricsResolution() {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let metrics = DisplayNotchMetrics.resolve(for: screen)

        XCTAssertGreaterThan(metrics.frame.width, 0)
        XCTAssertGreaterThan(metrics.frame.height, 0)
        XCTAssertGreaterThan(metrics.screenFrame.width, 0)
    }
}
