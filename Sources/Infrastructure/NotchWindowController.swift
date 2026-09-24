import AppKit
import SwiftUI

/// NSHostingView especializado que descarta eventos de ratón fuera de la geometría visible de la Dynamic Island.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    var hitTestCheck: ((NSPoint) -> Bool)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let hitTestCheck, !hitTestCheck(point) {
            return nil
        }
        return super.hitTest(point)
    }
}

/// Controlador de infraestructura para el ciclo de vida y posicionamiento del NSPanel de la Dynamic Island.
@MainActor
public final class NotchWindowController: NSObject {
    public let panel: DynamicNotchPanel
    public private(set) var currentMetrics: DisplayNotchMetrics

    private let maxPanelWidth: CGFloat = 660.0
    private let maxPanelHeight: CGFloat = 280.0
    public var isExpandedProvider: (() -> Bool)?
    public var isActiveProvider: (() -> Bool)?

    public init(rootView: AnyView) {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let metrics = DisplayNotchMetrics.resolve(for: screen)
        self.currentMetrics = metrics

        // Calcular posición inicial fija
        let initialRect = Self.calculatePanelFrame(
            screen: screen,
            panelWidth: maxPanelWidth,
            panelHeight: maxPanelHeight
        )

        let panel = DynamicNotchPanel(contentRect: initialRect)
        self.panel = panel
        super.init()

        let hostingView = NotchHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: initialRect.size)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.hitTestCheck = { [weak self] point in
            guard let self else { return true }
            return self.isPointInsideCapsule(point)
        }
        panel.contentView = hostingView

        // Observar reconfiguraciones de pantallas (desconectar/conectar monitor externo)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        updatePosition()
    }

    private func isPointInsideCapsule(_ point: NSPoint) -> Bool {
        let isActive = isActiveProvider?() ?? true
        guard isActive else { return false }

        let isExpanded = isExpandedProvider?() ?? false
        let capsuleWidth: CGFloat = isExpanded ? 350.0 : (currentMetrics.hasHardwareNotch ? 440.0 : 230.0)
        let capsuleHeight: CGFloat = isExpanded ? 130.0 : (currentMetrics.hasHardwareNotch ? 38.0 : 34.0)

        let x = (maxPanelWidth - capsuleWidth) / 2.0
        let y = maxPanelHeight - capsuleHeight

        let capsuleRect = NSRect(x: x, y: y, width: capsuleWidth, height: capsuleHeight)
        return capsuleRect.insetBy(dx: -8, dy: -8).contains(point)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Muestra el panel en pantalla de forma no intrusiva.
    public func show() {
        panel.orderFrontRegardless()
    }

    /// Oculta el panel.
    public func hide() {
        panel.orderOut(nil)
    }

    /// Actualiza la posición del panel centrado con respecto a la pantalla activa.
    public func updatePosition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        currentMetrics = DisplayNotchMetrics.resolve(for: screen)
        let frame = Self.calculatePanelFrame(
            screen: screen,
            panelWidth: maxPanelWidth,
            panelHeight: maxPanelHeight
        )
        panel.setFrame(frame, display: true, animate: false)
    }

    @objc private func handleScreenChange() {
        updatePosition()
    }

    private static func calculatePanelFrame(screen: NSScreen, panelWidth: CGFloat, panelHeight: CGFloat) -> NSRect {
        let screenFrame = screen.frame
        let x = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2.0
        let y = screenFrame.origin.y + screenFrame.height - panelHeight

        return NSRect(x: x, y: y, width: panelWidth, height: panelHeight)
    }
}
