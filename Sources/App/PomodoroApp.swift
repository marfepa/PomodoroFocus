import SwiftUI
import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NotchWindowController?
    private var coordinator: SessionCoordinator?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Desactivar activación intrusiva en el Dock si se desea comportamiento accesorio
        NSApp.setActivationPolicy(.accessory)

        let coordinator = SessionCoordinator()
        self.coordinator = coordinator

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let metrics = DisplayNotchMetrics.resolve(for: screen)

        let surfaceView = DynamicIslandSurface(coordinator: coordinator, metrics: metrics)
        let windowController = NotchWindowController(rootView: AnyView(surfaceView))
        windowController.isExpandedProvider = { [weak coordinator] in
            coordinator?.isExpanded ?? false
        }
        self.windowController = windowController

        coordinator.panel = windowController.panel

        // Configurar menú auxiliar en la barra de menús
        setupStatusItem()

        windowController.show()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Pomodoro")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Pomodoro Dynamic Island", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Anotar distracción (⌘I)", action: #selector(triggerQuickCapture), keyEquivalent: "i"))
        menu.addItem(NSMenuItem(title: "Reiniciar posición de Isla", action: #selector(repositionIsland), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(terminateApp), keyEquivalent: "q"))

        item.menu = menu
        self.statusItem = item
    }

    @objc private func triggerQuickCapture() {
        coordinator?.toggleQuickCapture()
    }

    @objc private func repositionIsland() {
        windowController?.updatePosition()
        windowController?.show()
    }

    @objc private func terminateApp() {
        NSApp.terminate(nil)
    }
}
