import Foundation

/// Configuraciones predefinidas de duraciones de intervalos para el método Pomodoro.
public struct PomodoroPreset: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let name: String
    public let workDuration: TimeInterval
    public let shortBreakDuration: TimeInterval
    public let longBreakDuration: TimeInterval
    public let blocksPerCycle: Int

    public init(
        id: String,
        name: String,
        workDuration: TimeInterval,
        shortBreakDuration: TimeInterval = 5 * 60,
        longBreakDuration: TimeInterval = 20 * 60,
        blocksPerCycle: Int = 4
    ) {
        self.id = id
        self.name = name
        self.workDuration = workDuration
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
        self.blocksPerCycle = blocksPerCycle
    }

    public static let standard25 = PomodoroPreset(
        id: "standard25",
        name: "25 min (Estándar Cirillo)",
        workDuration: 25 * 60,
        shortBreakDuration: 5 * 60,
        longBreakDuration: 20 * 60,
        blocksPerCycle: 4
    )

    public static let deep45 = PomodoroPreset(
        id: "deep45",
        name: "45 min (Enfoque Profundo)",
        workDuration: 45 * 60,
        shortBreakDuration: 10 * 60,
        longBreakDuration: 25 * 60,
        blocksPerCycle: 4
    )

    public static let flow50 = PomodoroPreset(
        id: "flow50",
        name: "50 min (Bloque Extendido)",
        workDuration: 50 * 60,
        shortBreakDuration: 10 * 60,
        longBreakDuration: 30 * 60,
        blocksPerCycle: 4
    )

    public static let testFast = PomodoroPreset(
        id: "testFast",
        name: "Prueba rápida (10s)",
        workDuration: 10,
        shortBreakDuration: 5,
        longBreakDuration: 8,
        blocksPerCycle: 2
    )

    public static let allPresets: [PomodoroPreset] = [
        .standard25,
        .deep45,
        .flow50
    ]
}
