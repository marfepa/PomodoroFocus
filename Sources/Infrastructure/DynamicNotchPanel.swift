import AppKit

/// Panel de ventana especializado para la Dynamic Island en macOS.
/// Opera por encima de la barra de menús sin arrebatar el foco del teclado.
public final class DynamicNotchPanel: NSPanel {
    /// Controla si el panel puede convertirse temporalmente en Key Window (p. ej. para escribir en el campo de texto de interrupciones).
    public var allowsKeyInput: Bool = false

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Posicionar la ventana por encima del menú del sistema y sobre Espacios a pantalla completa
        self.level = .mainMenu + 1
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        // Transparencia visual absoluta del lienzo contenedor
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false

        // Preservar el foco de teclado en la aplicación activa en primer plano
        self.becomesKeyOnlyIfNeeded = true
        self.isMovable = false
        self.isMovableByWindowBackground = false
        self.acceptsMouseMovedEvents = true
    }

    public override var canBecomeKey: Bool {
        return allowsKeyInput
    }

    public override var canBecomeMain: Bool {
        return false
    }

    public override func sendEvent(_ event: NSEvent) {
        // Manejar escape para cerrar modales de interrupción si está activo
        if event.type == .keyDown && event.keyCode == 53 { // ESC
            NotificationCenter.default.post(name: .pomodoroDismissQuickCapture, object: nil)
            return
        }
        super.sendEvent(event)
    }
}

public extension Notification.Name {
    static let pomodoroDismissQuickCapture = Notification.Name("pomodoroDismissQuickCapture")
    static let pomodoroFocusModeEngaged = Notification.Name("pomodoroFocusModeEngaged")
}
