import Foundation
import SwiftUI
import AppKit

/// Coordinador principal en `@MainActor` que conecta la UI declarativa de SwiftUI con el motor PomodoroCoreEngine.
@Observable
@MainActor
public final class SessionCoordinator {
    // MARK: - Estado Observable para SwiftUI
    public var snapshot: PomodoroSnapshot
    public var isHovered: Bool = false
    public var isExpanded: Bool = false
    public var isQuickCapturePresented: Bool = false
    public var quickCaptureText: String = ""
    public var selectedPreset: PomodoroPreset = .standard25
    public var currentTaskInput: String = ""

    public var isIslandActive: Bool {
        snapshot.phase != .idle || isQuickCapturePresented
    }

    public func toggleIsland() {
        guard isIslandActive else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            self.isExpanded.toggle()
        }
    }

    // Ajustes de Atajos de Concentración
    public var workShortcutName: String = "Activar Modo Enfoque"
    public var defaultShortcutName: String = "Desactivar Modo Enfoque"
    public var enableFocusAutomation: Bool = true

    // MARK: - Dependencias
    public let engine: PomodoroCoreEngine
    private let focusController: SystemFocusController
    private var tickerTimer: Timer?
    private var hoverTask: Task<Void, Never>?
    private var localKeyMonitor: Any?

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

    public init(engine: PomodoroCoreEngine = PomodoroCoreEngine()) {
        self.engine = engine
        self.focusController = SystemFocusController()
        self.snapshot = PomodoroSnapshot(
            phase: .idle,
            currentPreset: .standard25,
            currentTaskTitle: nil,
            currentBlockInCycle: 1,
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
    }

    isolated deinit {
        tickerTimer?.invalidate()
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Ciclo de Vida del Temporizador
    private func setupTicker() {
        // Ticker de 4Hz en el RunLoop común para animaciones suaves sin consumo de CPU excesivo
        tickerTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.updateTick()
            }
        }
    }

    private func updateTick() async {
        let now = Date()
        let oldPhase = snapshot.phase
        let currentSnap = await engine.getSnapshot(at: now)

        // Verificar si el intervalo expiró durante una fase activa
        if !currentSnap.isPaused && currentSnap.remainingSeconds <= 0 && currentSnap.phase != .idle && currentSnap.phase != .overtime {
            // Reproducir sonido de aviso
            playPhaseTransitionSound()

            // Transición automática según secuencia canónica
            let newPhase = await engine.transitionOnExpiry(at: now)
            self.snapshot = await engine.getSnapshot(at: now)

            // Gobernanza de Modos de Concentración
            await handleFocusModeTransition(from: oldPhase, to: newPhase)
        } else {
            self.snapshot = currentSnap
        }
    }

    // MARK: - Control de Hover con Debounce (120 ms)
    public func handleHoverChange(isInside: Bool) {
        guard isIslandActive else { return }
        hoverTask?.cancel()
        self.isHovered = isInside

        if isInside {
            hoverTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000) // 120 ms
                if !Task.isCancelled && self.isHovered && self.isIslandActive {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        self.isExpanded = true
                    }
                }
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                self.isExpanded = false
            }
        }
    }

    // MARK: - Acciones de Usuario
    public func startSession() async {
        let taskName = currentTaskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        await engine.startWork(taskTitle: taskName.isEmpty ? nil : taskName, preset: selectedPreset)
        snapshot = await engine.getSnapshot()
        
        windowController?.show()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = false
        }

        await handleFocusModeTransition(from: .idle, to: .work)
        hideMainWindow()
    }

    public func pauseSession() async {
        await engine.pause()
        snapshot = await engine.getSnapshot()
    }

    public func resumeSession() async {
        await engine.resume()
        snapshot = await engine.getSnapshot()
    }

    public func cancelSession() async {
        let previousPhase = snapshot.phase
        await engine.resetToIdle()
        snapshot = await engine.getSnapshot()
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = false
        }

        if !isQuickCapturePresented {
            windowController?.hide()
        }

        await handleFocusModeTransition(from: previousPhase, to: .idle)
    }

    public func skipBreak() async {
        let previousPhase = snapshot.phase
        await engine.skipToWork()
        snapshot = await engine.getSnapshot()
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = false
        }

        await handleFocusModeTransition(from: previousPhase, to: .work)
    }

    public func addTwoMinutes() async {
        await engine.addExtraTime(2 * 60)
        snapshot = await engine.getSnapshot()
    }

    // MARK: - Captura Rápida de Interrupciones (⌘ + I)
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
        windowController?.show()
        panel?.allowsKeyInput = true
        panel?.makeKey()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = true
        }
    }

    public func submitQuickCapture() async {
        let note = quickCaptureText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            await engine.recordInterruption(type: .internal, note: note)
            snapshot = await engine.getSnapshot()
        }
        dismissQuickCapture()
    }

    public func dismissQuickCapture() {
        isQuickCapturePresented = false
        quickCaptureText = ""
        panel?.allowsKeyInput = false
        panel?.resignKey()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = isHovered && isIslandActive
        }
        if !isIslandActive {
            windowController?.hide()
        }
    }

    // MARK: - Monitoreo de Atajo ⌘ + I
    private func setupKeyboardMonitoring() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            // Comprobar ⌘ + I
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "i" {
                self.toggleQuickCapture()
                return nil
            }
            // Comprobar ⌘ + O para alternar la isla
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

    // MARK: - Audio y Efectos del Sistema
    private func playPhaseTransitionSound() {
        NSSound(named: "Glass")?.play()
    }

    private func handleFocusModeTransition(from oldPhase: PomodoroPhase, to newPhase: PomodoroPhase) async {
        guard enableFocusAutomation else { return }

        if newPhase == .work && oldPhase != .work {
            try? await focusController.execute(.activateWorkProfile(shortcutName: workShortcutName))
        } else if oldPhase == .work && newPhase != .work {
            try? await focusController.execute(.restoreDefaultProfile(shortcutName: defaultShortcutName))
        }
    }
}
