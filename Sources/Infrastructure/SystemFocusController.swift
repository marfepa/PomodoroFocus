import Foundation

/// Controlador asíncrono para gobernar Modos de Concentración mediante el comando del sistema /usr/bin/shortcuts.
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

    public init() {}

    /// Despacha asíncronamente la ejecución de un atajo de concentración en un proceso secundario.
    public func execute(_ transition: FocusTransition) async throws {
        let name = transition.shortcutName
        guard !name.isEmpty else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                process.arguments = ["run", name]

                let errorPipe = Pipe()
                process.standardError = errorPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    if process.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        let errorBuffer = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorDescription = String(data: errorBuffer, encoding: .utf8) ?? "Fallo desconocido al invocar atajo"
                        continuation.resume(throwing: NSError(
                            domain: "FocusExecutionDomain",
                            code: Int(process.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: errorDescription]
                        ))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
