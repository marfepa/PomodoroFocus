import Foundation
import SwiftUI
import AppKit

/// Coordinador principal en `@MainActor` que conecta la UI declarativa de SwiftUI con el motor PomodoroCoreEngine.
@Observable
@MainActor
public final class SessionCoordinator {
    public var snapshot: PomodoroSnapshot
    public var isHovered: Bool = false
    public var isExpanded: Bool = false
    public var isQuickCapturePresented: Bool = false
    public var quickCaptureText: String = ""
    public var quickCaptureType: InterruptionType = .internal
    public var selectedPreset: PomodoroPreset = .standard25
    public var currentTaskInput: String = ""
    public var interruptions: [InterruptionRecord] = []
    public var focusStatusMessage: String?
    public var notchMetrics: DisplayNotchMetrics

    public var isIslandActive: Bool {
        true
    }

    public func toggleIsland() {
        guard !isQuickCapturePresented else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            self.isExpanded.toggle()
        }
    }

    public var workShortcutName: String = "Activar Modo Enfoque"
    public var defaultShortcutName: String = "Desactivar Modo Enfoque"
    public var enableFocusAutomation: Bool = true

    public let engine: PomodoroCoreEngine
    private let focusController: SystemFocusController
    public let notificationService: NotificationServiceProtocol
    private let store: SessionStore
    private var tickerTimer: Timer?
    private var hoverTask: Task<Void, Never>?
    private var localKeyMonitor: Any?
    private var restoreTask: Task<Void, Never>?
    private var didRestore = false

    public var onSnapshotChange: ((PomodoroSnapshot) -> Void)?

    public weak var panel: DynamicNotchPanel?
    public weak var windowController: NotchWindowController?
    public weak var mainWindow: NSWindow?
    public var shouldMinimizeOnStart: Bool = true

    public func showMainWindow() {
        if let window = mainWindow {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    public func hideMainWindow() {
        if shouldMinimizeOnStart, let window = mainWindow {
            window.miniaturize(nil)
        }
    }

    public init(
        engine: PomodoroCoreEngine = PomodoroCoreEngine(),
        notificationService: NotificationServiceProtocol = NotificationService.shared,
        store: SessionStore = .production()
    ) {
        self.engine = engine
        self.focusController = SystemFocusController()
        self.notificationService = notificationService
        self.store = store
        let screen = NSScreen.main ?? NSScreen.screens.first
        self.notchMetrics = screen.map { DisplayNotchMetrics.resolve(for: $0) }
            ?? DisplayNotchMetrics(frame: CGRect(x: 0, y: 0, width: 210, height: 32), hasHardwareNotch: false, screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900))
        self.snapshot = PomodoroSnapshot(
            phase: .idle,
            currentPreset: .standard25,
            currentTaskTitle: nil,
            currentBlockInCycle: 1,
            completedBlocksInCycle: 0,
            totalBlocksInCycle: 4,
            remainingSeconds: 25 * 60,
            overtimeSeconds: 0,
            progress: 0,
            isPaused: false,
            completedPomodorosToday: 0,
            internalInterruptionsCount: 0,
            externalInterruptionsCount: 0
        )

        setupTicker()
        setupKeyboardMonitoring()
        setupNotificationObservers()
        setupNotificationActions()
        restoreTask = Task { await self.restorePersistedState() }
    }

    isolated deinit {
        tickerTimer?.invalidate()
        hoverTask?.cancel()
        restoreTask?.cancel()
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func setupTicker() {
        tickerTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.updateTick()
            }
        }
    }

    private func ensureRestored() async {
        await restoreTask?.value
    }

    private func updateTick() async {
        await ensureRestored()
        let now = Date()
        let oldPhase = snapshot.phase
        let currentSnap = await engine.getSnapshot(at: now)

        if !currentSnap.isPaused && currentSnap.remainingSeconds <= 0 && currentSnap.phase == .work {
            playPhaseTransitionSound()
            _ = await engine.enterOvertime(at: now)
            await publish(at: now)
            await handleFocusModeTransition(from: oldPhase, to: snapshot.phase)
            await persist()
        } else if !currentSnap.isPaused && currentSnap.remainingSeconds <= 0 && (currentSnap.phase == .shortBreak || currentSnap.phase == .longBreak) {
            playPhaseTransitionSound()
            _ = await engine.transitionOnExpiry(at: now)
            await publish(at: now)
            await handleFocusModeTransition(from: oldPhase, to: snapshot.phase)
            await persist()
        } else {
            snapshot = currentSnap
            onSnapshotChange?(snapshot)
        }
    }

    public func handleHoverChange(isInside: Bool) {
        hoverTask?.cancel()
        self.isHovered = isInside
        guard !isQuickCapturePresented else { return }

        if isInside {
            hoverTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled, self.isHovered else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    self.isExpanded = true
                }
            }
        } else {
            hoverTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 220_000_000)
                guard !Task.isCancelled, !self.isHovered, !self.isQuickCapturePresented else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    self.isExpanded = false
                }
            }
        }
    }

    public func selectPreset(_ preset: PomodoroPreset) async {
        await ensureRestored()
        selectedPreset = preset
        await engine.selectPreset(preset)
        await publish()
        await persist()
    }

    public func startSession() async {
        await ensureRestored()
        let taskName = currentTaskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        await engine.startWork(taskTitle: taskName.isEmpty ? nil : taskName, preset: selectedPreset)
        await publish()

        notificationService.schedulePhaseCompletion(
            phase: .work,
            taskTitle: snapshot.currentTaskTitle,
            duration: snapshot.remainingSeconds
        )

        windowController?.show()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = false
        }
        await handleFocusModeTransition(from: .idle, to: .work)
        hideMainWindow()
        await persist()
    }

    /// Abre el siguiente bloque conservando la tarea que ya estaba en el motor.
    public func startNextWorkBlock() async {
        await ensureRestored()
        let previous = snapshot.phase
        await engine.skipToWork()
        await publish()
        if let title = snapshot.currentTaskTitle {
            currentTaskInput = title
        }
        notificationService.schedulePhaseCompletion(
            phase: .work,
            taskTitle: snapshot.currentTaskTitle,
            duration: snapshot.remainingSeconds
        )
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = false
        }
        await handleFocusModeTransition(from: previous, to: .work)
        await persist()
    }

    public func pauseSession() async {
        await ensureRestored()
        await engine.pause()
        await publish()
        notificationService.cancelPendingPhaseNotification()
        await persist()
    }

    public func resumeSession() async {
        await ensureRestored()
        await engine.resume()
        await publish()
        notificationService.schedulePhaseCompletion(
            phase: snapshot.phase,
            taskTitle: snapshot.currentTaskTitle,
            duration: snapshot.remainingSeconds
        )
        await persist()
    }

    public func cancelSession() async {
        await ensureRestored()
        let previousPhase = snapshot.phase
        await engine.resetToIdle()
        await publish()
        notificationService.cancelPendingPhaseNotification()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = false
        }
        await handleFocusModeTransition(from: previousPhase, to: .idle)
        await persist()
    }

    public func skipBreak() async {
        await startNextWorkBlock()
    }

    public func takeBreak() async {
        await ensureRestored()
        let previousPhase = snapshot.phase
        let newPhase = await engine.beginBreak()
        await publish()
        guard snapshot.phase == .shortBreak || snapshot.phase == .longBreak else { return }
        notificationService.schedulePhaseCompletion(
            phase: newPhase,
            taskTitle: snapshot.currentTaskTitle,
            duration: snapshot.remainingSeconds
        )
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = false
        }
        await handleFocusModeTransition(from: previousPhase, to: snapshot.phase)
        await persist()
    }

    public func addTwoMinutes() async {
        await ensureRestored()
        await engine.addExtraTime(2 * 60)
        await publish()
        notificationService.schedulePhaseCompletion(
            phase: snapshot.phase,
            taskTitle: snapshot.currentTaskTitle,
            duration: snapshot.remainingSeconds
        )
        await persist()
    }

    public func recordInterruption(type: InterruptionType, note: String) async {
        await ensureRestored()
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await engine.recordInterruption(type: type, note: trimmed)
        await publish()
        await persist()
    }

    public func toggleQuickCapture() {
        if isQuickCapturePresented {
            dismissQuickCapture()
        } else {
            presentQuickCapture()
        }
    }

    public func presentQuickCapture() {
        isQuickCapturePresented = true
        quickCaptureText = ""
        quickCaptureType = .internal
        windowController?.show()
        panel?.allowsKeyInput = true
        panel?.makeKey()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = true
        }
    }

    public func submitQuickCapture() async {
        await recordInterruption(type: quickCaptureType, note: quickCaptureText)
        dismissQuickCapture()
    }

    public func dismissQuickCapture() {
        isQuickCapturePresented = false
        quickCaptureText = ""
        panel?.allowsKeyInput = false
        panel?.resignKey()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = isHovered
        }
    }

    public func persistSettings() {
        Task { await self.persist() }
    }

    private func setupKeyboardMonitoring() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "i" {
                self.toggleQuickCapture()
                return nil
            }
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "o" {
                self.toggleIsland()
                return nil
            }
            return event
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .pomodoroDismissQuickCapture,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.dismissQuickCapture()
            }
        }
    }

    private func playPhaseTransitionSound() {
        NSSound(named: "Glass")?.play()
    }

    private func keepsWorkFocus(_ phase: PomodoroPhase) -> Bool {
        phase == .work || phase == .overtime
    }

    private func handleFocusModeTransition(from oldPhase: PomodoroPhase, to newPhase: PomodoroPhase) async {
        guard enableFocusAutomation else { return }
        guard keepsWorkFocus(oldPhase) != keepsWorkFocus(newPhase) else { return }

        do {
            if keepsWorkFocus(newPhase) {
                try await focusController.execute(.activateWorkProfile(shortcutName: workShortcutName))
            } else {
                try await focusController.execute(.restoreDefaultProfile(shortcutName: defaultShortcutName))
            }
            focusStatusMessage = nil
        } catch {
            focusStatusMessage = error.localizedDescription
        }
    }

    private func setupNotificationActions() {
        if let service = notificationService as? NotificationService {
            service.onActionReceived = { [weak self] action in
                guard let self else { return }
                Task { @MainActor in
                    switch action {
                    case .startBreak:
                        await self.takeBreak()
                    case .startWork:
                        await self.skipBreak()
                    case .extendTwoMinutes:
                        await self.addTwoMinutes()
                    }
                }
            }
        }
    }

    private func publish(at now: Date = Date()) async {
        snapshot = await engine.getSnapshot(at: now)
        let records = await engine.getInterruptions()
        interruptions = records.filter { PomodoroDay.isSameDay($0.timestamp, as: now) }
        onSnapshotChange?(snapshot)
    }

    private func persist() async {
        guard didRestore else { return }
        let checkpoint = await engine.exportCheckpoint()
        let payload = PersistedSession(settings: currentSettings(), checkpoint: checkpoint)
        store.save(payload)
    }

    private func currentSettings() -> PersistedSettings {
        PersistedSettings(
            presetID: selectedPreset.id,
            workShortcutName: workShortcutName,
            defaultShortcutName: defaultShortcutName,
            enableFocusAutomation: enableFocusAutomation,
            shouldMinimizeOnStart: shouldMinimizeOnStart
        )
    }

    private func restorePersistedState() async {
        guard let payload = store.load() else {
            didRestore = true
            return
        }
        workShortcutName = payload.settings.workShortcutName
        defaultShortcutName = payload.settings.defaultShortcutName
        enableFocusAutomation = payload.settings.enableFocusAutomation
        shouldMinimizeOnStart = payload.settings.shouldMinimizeOnStart
        if let preset = PomodoroPreset.matching(id: payload.settings.presetID) {
            selectedPreset = preset
        }
        await engine.importCheckpoint(payload.checkpoint)
        didRestore = true
        await publish()
        if currentTaskInput.isEmpty, let title = snapshot.currentTaskTitle {
            currentTaskInput = title
        }
        if snapshot.phase != .idle {
            windowController?.show()
        }
    }
}
