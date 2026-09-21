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

    private var statusMenu: NSMenu?

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Pomodoro")
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Pomodoro Dynamic Island", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "🎯 Alternar Isla (⌘O)", action: #selector(toggleIslandAction), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "📝 Anotar distracción (⌘I)", action: #selector(triggerQuickCapture), keyEquivalent: "i"))
        menu.addItem(NSMenuItem(title: "⚙️ Centrar en pantalla", action: #selector(repositionIsland), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(terminateApp), keyEquivalent: "q"))

        self.statusMenu = menu
        self.statusItem = item
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            if let statusMenu {
                statusItem?.menu = statusMenu
                statusItem?.button?.performClick(nil)
                statusItem?.menu = nil
            }
        } else {
            toggleIslandAction()
        }
    }

    @objc private func toggleIslandAction() {
        coordinator?.toggleIsland()
        windowController?.show()
    }

    @objc private func triggerQuickCapture() {
        coordinator?.presentQuickCapture()
        windowController?.show()
    }

    @objc private func repositionIsland() {
        windowController?.updatePosition()
        windowController?.show()
    }

    @objc private func terminateApp() {
        NSApp.terminate(nil)
    }
}
