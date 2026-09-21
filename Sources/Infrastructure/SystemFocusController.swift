import Foundation

/// Controlador asíncrono para gobernar Modos de Concentración mediante `/usr/bin/shortcuts`.
public actor SystemFocusController {
    public enum FocusTransition: Sendable {
        case activateWorkProfile(shortcutName: String)
        case restoreDefaultProfile(shortcutName: String)

        public var shortcutName: String {
            switch self {
            case .activateWorkProfile(let name):
                return name
            case .restoreDefaultProfile(let name):
                return name
            }
        }
    }

    public enum FocusError: Error, LocalizedError, Sendable {
        case failed(String)
        case timedOut

        public var errorDescription: String? {
            switch self {
            case .failed(let message):
                return message
            case .timedOut:
                return "El atajo de Concentración no respondió a tiempo."
            }
        }
    }

    public init() {}

    /// Ejecuta el atajo y falla de forma visible si no existe o si se cuelga.
    public func execute(_ transition: FocusTransition) async throws {
        let name = transition.shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()

        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            let box = ResumeBox(continuation)
            process.terminationHandler = { process in
                box.resume(with: process.terminationStatus)
            }
            Task {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                if process.isRunning {
                    process.terminate()
                    box.resume(throwing: FocusError.timedOut)
                }
            }
        }

        guard status == 0 else {
            let errorBuffer = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorDescription = String(data: errorBuffer, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let message = (errorDescription?.isEmpty == false ? errorDescription! : "No se pudo ejecutar el atajo «\(name)».")
            throw FocusError.failed(message)
        }
    }
}

/// Evita reanudar dos veces la continuación si el proceso termina y el temporizador dispara a la vez.
private final class ResumeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Int32, Error>?

    init(_ continuation: CheckedContinuation<Int32, Error>) {
        self.continuation = continuation
    }

    func resume(with status: Int32) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: status)
    }

    func resume(throwing error: Error) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(throwing: error)
    }
}
