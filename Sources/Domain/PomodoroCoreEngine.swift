import Foundation

/// Snapshot inmutable del estado del motor en un instante dado.
public struct PomodoroSnapshot: Sendable, Codable {
    public let phase: PomodoroPhase
    public let currentPreset: PomodoroPreset
    public let currentTaskTitle: String?
    public let currentBlockInCycle: Int
    public let totalBlocksInCycle: Int
    public let remainingSeconds: TimeInterval
    public let overtimeSeconds: TimeInterval
    public let progress: Double
    public let isPaused: Bool
    public let completedPomodorosToday: Int
    public let internalInterruptionsCount: Int
    public let externalInterruptionsCount: Int

    public init(
        phase: PomodoroPhase,
        currentPreset: PomodoroPreset,
        currentTaskTitle: String?,
        currentBlockInCycle: Int,
        totalBlocksInCycle: Int,
        remainingSeconds: TimeInterval,
        overtimeSeconds: TimeInterval,
        progress: Double,
        isPaused: Bool,
        completedPomodorosToday: Int,
        internalInterruptionsCount: Int,
        externalInterruptionsCount: Int
    ) {
        self.phase = phase
        self.currentPreset = currentPreset
        self.currentTaskTitle = currentTaskTitle
        self.currentBlockInCycle = currentBlockInCycle
        self.totalBlocksInCycle = totalBlocksInCycle
        self.remainingSeconds = remainingSeconds
        self.overtimeSeconds = overtimeSeconds
        self.progress = progress
        self.isPaused = isPaused
        self.completedPomodorosToday = completedPomodorosToday
        self.internalInterruptionsCount = internalInterruptionsCount
        self.externalInterruptionsCount = externalInterruptionsCount
    }
}

/// Actor de dominio responsable de la lógica del temporizador y las transiciones del ciclo Pomodoro.
public actor PomodoroCoreEngine {
    private var phase: PomodoroPhase = .idle
    private var preset: PomodoroPreset = .standard25
    private var currentTaskTitle: String?
    private var currentBlockInCycle: Int = 1
    private var calculator: PomodoroStateCalculator?
    private var isPaused: Bool = false
    private var pausedRemainingTime: TimeInterval = 0
    private var interruptions: [InterruptionRecord] = []
    private var completedPomodorosToday: Int = 0

    public init(preset: PomodoroPreset = .standard25) {
        self.preset = preset
    }

    /// Inicia un bloque de trabajo (Pomodoro).
    public func startWork(taskTitle: String? = nil, preset: PomodoroPreset? = nil) {
        if let preset {
            self.preset = preset
        }
        self.phase = .work
        self.currentTaskTitle = taskTitle
        self.isPaused = false
        self.calculator = PomodoroStateCalculator(duration: self.preset.workDuration)
    }

    /// Inicia un descanso corto (Short Break).
    public func startShortBreak() {
        self.phase = .shortBreak
        self.isPaused = false
        self.calculator = PomodoroStateCalculator(duration: self.preset.shortBreakDuration)
    }

    /// Inicia un descanso largo (Long Break) tras completar 4 bloques.
    public func startLongBreak() {
        self.phase = .longBreak
        self.isPaused = false
        self.calculator = PomodoroStateCalculator(duration: self.preset.longBreakDuration)
    }

    /// Cancela o detiene el intervalo en curso volviendo al estado inactivo.
    public func resetToIdle() {
        self.phase = .idle
        self.calculator = nil
        self.isPaused = false
        self.pausedRemainingTime = 0
    }

    /// Pausa de emergencia del temporizador conservando el tiempo restante.
    public func pause(at now: Date = Date()) {
        guard !isPaused, let calc = calculator else { return }
        self.isPaused = true
        self.pausedRemainingTime = calc.computeRemainingTime(at: now)
    }

    /// Reanuda el temporizador calculando un nuevo timestamp objetivo determinista.
    public func resume(at now: Date = Date()) {
        guard isPaused else { return }
        self.isPaused = false
        self.calculator = PomodoroStateCalculator(duration: pausedRemainingTime, startTimestamp: now)
    }

    /// Añade tiempo extra al intervalo actual (por ejemplo, +2 min en descansos).
    public func addExtraTime(_ additionalSeconds: TimeInterval) {
        if isPaused {
            pausedRemainingTime += additionalSeconds
        } else if let calc = calculator {
            self.calculator = calc.addingTime(additionalSeconds)
        }
    }

    /// Registra una interrupción sin detener el avance del tiempo (Regla de Cirillo).
    public func recordInterruption(type: InterruptionType, note: String, at now: Date = Date()) {
        let record = InterruptionRecord(
            type: type,
            note: note,
            timestamp: now,
            phase: phase,
            associatedTask: currentTaskTitle
        )
        interruptions.append(record)
    }

    /// Avanza de fase al expirar el tiempo según la secuencia canónica.
    public func transitionOnExpiry(at now: Date = Date()) -> PomodoroPhase {
        switch phase {
        case .work:
            completedPomodorosToday += 1
            if currentBlockInCycle >= preset.blocksPerCycle {
                // Completado el ciclo de 4 bloques -> descanso largo
                currentBlockInCycle = 1
                startLongBreak()
            } else {
                currentBlockInCycle += 1
                startShortBreak()
            }
            return phase

        case .shortBreak, .longBreak, .overtime:
            resetToIdle()
            return .idle

        case .idle:
            return .idle
        }
    }

    /// Forzar cambio manual de fase (p. ej. saltar descanso para volver al trabajo).
    public func skipToWork(taskTitle: String? = nil) {
        startWork(taskTitle: taskTitle ?? self.currentTaskTitle)
    }

    /// Obtiene una captura del estado actual del motor.
    public func getSnapshot(at now: Date = Date()) -> PomodoroSnapshot {
        let remaining: TimeInterval
        let overtime: TimeInterval
        let progress: Double

        if isPaused {
            remaining = pausedRemainingTime
            overtime = 0
            let duration = calculator?.duration ?? preset.workDuration
            progress = duration > 0 ? (1.0 - (remaining / duration)) : 0
        } else if let calc = calculator {
            remaining = calc.computeRemainingTime(at: now)
            overtime = calc.isExpired(at: now) ? calc.computeOvertime(at: now) : 0
            progress = calc.computeProgress(at: now)
        } else {
            remaining = preset.workDuration
            overtime = 0
            progress = 0
        }

        let internalCount = interruptions.filter { $0.type == .internal }.count
        let externalCount = interruptions.filter { $0.type == .external }.count

        return PomodoroSnapshot(
            phase: phase,
            currentPreset: preset,
            currentTaskTitle: currentTaskTitle,
            currentBlockInCycle: currentBlockInCycle,
            totalBlocksInCycle: preset.blocksPerCycle,
            remainingSeconds: remaining,
            overtimeSeconds: overtime,
            progress: progress,
            isPaused: isPaused,
            completedPomodorosToday: completedPomodorosToday,
            internalInterruptionsCount: internalCount,
            externalInterruptionsCount: externalCount
        )
    }

    /// Lista de todas las interrupciones registradas.
    public func getInterruptions() -> [InterruptionRecord] {
        return interruptions
    }
}
