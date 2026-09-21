import Foundation

/// Cómputo diferencial absoluto para temporizadores en macOS, inmune a App Nap y sleep del sistema.
public final class PomodoroStateCalculator: Sendable {
    public let duration: TimeInterval
    public let targetTimestamp: Date
    public let startTimestamp: Date

    public init(duration: TimeInterval, startTimestamp: Date = Date()) {
        self.duration = duration
        self.startTimestamp = startTimestamp
        self.targetTimestamp = startTimestamp.addingTimeInterval(duration)
    }

    public init(duration: TimeInterval, targetTimestamp: Date, startTimestamp: Date) {
        self.duration = duration
        self.targetTimestamp = targetTimestamp
        self.startTimestamp = startTimestamp
    }

    /// Calcula los segundos restantes deterministas respecto a la marca temporal destino.
    public func computeRemainingTime(at now: Date = Date()) -> TimeInterval {
        let delta = targetTimestamp.timeIntervalSince(now)
        return max(0, delta)
    }

    /// Calcula el tiempo transcurrido desde el inicio.
    public func computeElapsedTime(at now: Date = Date()) -> TimeInterval {
        let elapsed = now.timeIntervalSince(startTimestamp)
        return max(0, min(duration, elapsed))
    }

    /// Calcula los segundos excedidos cuando el temporizador ha sobrepasado la duración planificada (Overtime / Flow).
    public func computeOvertime(at now: Date = Date()) -> TimeInterval {
        let delta = now.timeIntervalSince(targetTimestamp)
        return max(0, delta)
    }

    /// Porcentaje de progreso completado normalizado en el rango [0.0, 1.0].
    public func computeProgress(at now: Date = Date()) -> Double {
        guard duration > 0 else { return 1.0 }
        let remaining = computeRemainingTime(at: now)
        let progress = 1.0 - (remaining / duration)
        return min(max(0.0, progress), 1.0)
    }

    /// Comprueba si el intervalo ha expirado.
    public func isExpired(at now: Date = Date()) -> Bool {
        return now >= targetTimestamp
    }

    /// Crea un nuevo calculador con tiempo adicional sumado al objetivo.
    public func addingTime(_ additionalSeconds: TimeInterval) -> PomodoroStateCalculator {
        let newTarget = targetTimestamp.addingTimeInterval(additionalSeconds)
        let newDuration = duration + additionalSeconds
        return PomodoroStateCalculator(duration: newDuration, targetTimestamp: newTarget, startTimestamp: startTimestamp)
    }
}
