import Foundation

/// Formato compartido `MM:SS` para el temporizador, la isla y la barra de menús.
public enum PomodoroTimeFormat {
    public static func string(from seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

/// Día civil local, usado para el contador «hoy» y el diario de interrupciones.
public enum PomodoroDay {
    public static func stamp(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func isSameDay(_ date: Date, as other: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, inSameDayAs: other)
    }
}
