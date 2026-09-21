import Foundation

/// Snapshot inmutable del estado del motor en un instante dado.
public struct PomodoroSnapshot: Sendable, Codable {
    public let phase: PomodoroPhase
    public let currentPreset: PomodoroPreset
    public let currentTaskTitle: String?
    public let currentBlockInCycle: Int
    public let completedBlocksInCycle: Int
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
        completedBlocksInCycle: Int,
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
        self.completedBlocksInCycle = completedBlocksInCycle
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

/// Estado serializable del motor. El tiempo vive en marcas absolutas, no en un contador.
public struct EngineCheckpoint: Codable, Sendable, Equatable {
    public var phase: PomodoroPhase
    public var presetID: String
    public var taskTitle: String?
    public var currentBlockInCycle: Int
    public var completedBlocksInCycle: Int
    public var nextBlockInCycle: Int
    public var completedPomodorosToday: Int
    public var dayStamp: String
    public var isPaused: Bool
    public var pausedRemainingTime: TimeInterval
    public var duration: TimeInterval?
    public var startTimestamp: Date?
    public var targetTimestamp: Date?
    public var interruptions: [InterruptionRecord]

    public init(
        phase: PomodoroPhase,
        presetID: String,
        taskTitle: String?,
        currentBlockInCycle: Int,
        completedBlocksInCycle: Int,
        nextBlockInCycle: Int,
        completedPomodorosToday: Int,
        dayStamp: String,
        isPaused: Bool,
        pausedRemainingTime: TimeInterval,
        duration: TimeInterval?,
        startTimestamp: Date?,
        targetTimestamp: Date?,
        interruptions: [InterruptionRecord]
    ) {
        self.phase = phase
        self.presetID = presetID
        self.taskTitle = taskTitle
        self.currentBlockInCycle = currentBlockInCycle
        self.completedBlocksInCycle = completedBlocksInCycle
        self.nextBlockInCycle = nextBlockInCycle
        self.completedPomodorosToday = completedPomodorosToday
        self.dayStamp = dayStamp
        self.isPaused = isPaused
        self.pausedRemainingTime = pausedRemainingTime
        self.duration = duration
        self.startTimestamp = startTimestamp
        self.targetTimestamp = targetTimestamp
        self.interruptions = interruptions
    }
}

/// Actor de dominio responsable de la lógica del temporizador y las transiciones del ciclo Pomodoro.
public actor PomodoroCoreEngine {
    private var phase: PomodoroPhase = .idle
    private var preset: PomodoroPreset = .standard25
    private var currentTaskTitle: String?
    private var currentBlockInCycle: Int = 1
    private var completedBlocksInCycle: Int = 0
    private var nextBlockInCycle: Int = 1
    private var calculator: PomodoroStateCalculator?
    private var isPaused: Bool = false
    private var pausedRemainingTime: TimeInterval = 0
    private var interruptions: [InterruptionRecord] = []
    private var completedPomodorosToday: Int = 0
    private var dayStamp: String = PomodoroDay.stamp(Date())

    public init(preset: PomodoroPreset = .standard25) {
        self.preset = preset
    }

    /// Cambia el preajuste visible mientras no hay una sesión en curso.
    public func selectPreset(_ preset: PomodoroPreset) {
        guard phase == .idle else { return }
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

    /// Inicia un descanso largo (Long Break) tras completar el ciclo.
    public func startLongBreak() {
        self.phase = .longBreak
        self.isPaused = false
        self.calculator = PomodoroStateCalculator(duration: self.preset.longBreakDuration)
    }

    /// Cancela el intervalo y el ciclo. El diario de interrupciones se conserva.
    public func resetToIdle() {
        self.phase = .idle
        self.calculator = nil
        self.isPaused = false
        self.pausedRemainingTime = 0
        self.currentBlockInCycle = 1
        self.completedBlocksInCycle = 0
        self.nextBlockInCycle = 1
        self.currentTaskTitle = nil
    }

    /// Pausa de emergencia del temporizador conservando el tiempo restante.
    public func pause(at now: Date = Date()) {
        guard !isPaused, let calc = calculator, phase != .idle else { return }
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

    /// El bloque de trabajo ha llegado a cero: entra en flow y cuenta el pomodoro una sola vez.
    @discardableResult
    public func enterOvertime(at now: Date = Date()) -> PomodoroPhase {
        guard phase == .work, !isPaused, let calc = calculator, calc.isExpired(at: now) else {
            return phase
        }
        phase = .overtime
        completedPomodorosToday += 1
        completedBlocksInCycle = currentBlockInCycle
        nextBlockInCycle = currentBlockInCycle >= preset.blocksPerCycle ? 1 : currentBlockInCycle + 1
        return phase
    }

    /// Pasa del flow al descanso que corresponde al bloque recién cerrado.
    @discardableResult
    public func beginBreak(at now: Date = Date()) -> PomodoroPhase {
        if phase == .work {
            enterOvertime(at: now)
        }
        guard phase == .overtime else { return phase }
        if completedBlocksInCycle >= preset.blocksPerCycle {
            startLongBreak()
        } else {
            startShortBreak()
        }
        return phase
    }

    /// Cierra un descanso vencido y deja preparado el siguiente bloque.
    @discardableResult
    public func transitionOnExpiry(at now: Date = Date()) -> PomodoroPhase {
        switch phase {
        case .work:
            return enterOvertime(at: now)
        case .shortBreak:
            guard !isPaused, calculator?.isExpired(at: now) == true else { return phase }
            finishBreak(wasLong: false)
            return .idle
        case .longBreak:
            guard !isPaused, calculator?.isExpired(at: now) == true else { return phase }
            finishBreak(wasLong: true)
            return .idle
        case .overtime, .idle:
            return phase
        }
    }

    /// Salta el descanso y abre el siguiente bloque de trabajo con la misma tarea.
    public func skipToWork(taskTitle: String? = nil) {
        if phase == .shortBreak || phase == .longBreak {
            let wasLong = phase == .longBreak
            currentBlockInCycle = nextBlockInCycle
            if wasLong {
                completedBlocksInCycle = 0
            }
        }
        startWork(taskTitle: taskTitle ?? self.currentTaskTitle)
    }

    /// Obtiene una captura del estado actual del motor.
    public func getSnapshot(at now: Date = Date()) -> PomodoroSnapshot {
        noteDay(at: now)

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
            overtime = phase == .overtime || calc.isExpired(at: now) ? calc.computeOvertime(at: now) : 0
            progress = phase == .overtime ? 1 : calc.computeProgress(at: now)
        } else {
            remaining = preset.workDuration
            overtime = 0
            progress = 0
        }

        let todays = interruptions.filter { PomodoroDay.isSameDay($0.timestamp, as: now) }
        let internalCount = todays.filter { $0.type == .internal }.count
        let externalCount = todays.filter { $0.type == .external }.count

        return PomodoroSnapshot(
            phase: phase,
            currentPreset: preset,
            currentTaskTitle: currentTaskTitle,
            currentBlockInCycle: currentBlockInCycle,
            completedBlocksInCycle: completedBlocksInCycle,
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

    /// Lista de todas las interrupciones registradas, recientes primero.
    public func getInterruptions() -> [InterruptionRecord] {
        interruptions.sorted { $0.timestamp > $1.timestamp }
    }

    public func exportCheckpoint(at now: Date = Date()) -> EngineCheckpoint {
        noteDay(at: now)
        let cutoff = now.addingTimeInterval(-30 * 24 * 60 * 60)
        let kept = interruptions.filter { $0.timestamp >= cutoff }
        return EngineCheckpoint(
            phase: phase,
            presetID: preset.id,
            taskTitle: currentTaskTitle,
            currentBlockInCycle: currentBlockInCycle,
            completedBlocksInCycle: completedBlocksInCycle,
            nextBlockInCycle: nextBlockInCycle,
            completedPomodorosToday: completedPomodorosToday,
            dayStamp: dayStamp,
            isPaused: isPaused,
            pausedRemainingTime: pausedRemainingTime,
            duration: calculator?.duration,
            startTimestamp: calculator?.startTimestamp,
            targetTimestamp: calculator?.targetTimestamp,
            interruptions: kept
        )
    }

    /// Restaura un checkpoint. Si el trabajo venció con la app cerrada, entra en overtime una sola vez.
    public func importCheckpoint(_ checkpoint: EngineCheckpoint, at now: Date = Date()) {
        let resolved = PomodoroPreset.matching(id: checkpoint.presetID) ?? .standard25
        preset = resolved
        phase = checkpoint.phase
        currentTaskTitle = checkpoint.taskTitle
        currentBlockInCycle = max(1, checkpoint.currentBlockInCycle)
        completedBlocksInCycle = max(0, checkpoint.completedBlocksInCycle)
        nextBlockInCycle = max(1, checkpoint.nextBlockInCycle)
        completedPomodorosToday = max(0, checkpoint.completedPomodorosToday)
        dayStamp = checkpoint.dayStamp
        isPaused = checkpoint.isPaused
        pausedRemainingTime = checkpoint.pausedRemainingTime
        interruptions = checkpoint.interruptions

        if let duration = checkpoint.duration,
           let start = checkpoint.startTimestamp,
           let target = checkpoint.targetTimestamp {
            calculator = PomodoroStateCalculator(duration: duration, targetTimestamp: target, startTimestamp: start)
        } else {
            calculator = nil
        }

        noteDay(at: now)

        if isPaused || phase == .idle {
            return
        }

        if phase == .work, let calc = calculator, calc.isExpired(at: now) {
            enterOvertime(at: now)
        } else if phase == .shortBreak, calculator?.isExpired(at: now) == true {
            finishBreak(wasLong: false)
        } else if phase == .longBreak, calculator?.isExpired(at: now) == true {
            finishBreak(wasLong: true)
        }
    }

    private func finishBreak(wasLong: Bool) {
        phase = .idle
        calculator = nil
        isPaused = false
        pausedRemainingTime = 0
        currentBlockInCycle = nextBlockInCycle
        if wasLong {
            completedBlocksInCycle = 0
        }
    }

    private func noteDay(at now: Date) {
        let stamp = PomodoroDay.stamp(now)
        guard stamp != dayStamp else { return }
        dayStamp = stamp
        completedPomodorosToday = 0
    }
}
