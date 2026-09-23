import SwiftUI
import AppKit

@main
struct PomodoroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var coordinator = SessionCoordinator()

    var body: some Scene {
        Window("Pomodoro", id: "main") {
            MainWindowView(coordinator: coordinator)
                .background(WindowAccessor { window in
                    coordinator.mainWindow = window
                    appDelegate.setup(coordinator: coordinator)
                })
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Pomodoro") {
                Button("🎯 Alternar Dynamic Island") {
                    coordinator.toggleIsland()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("📝 Anotar distracción") {
                    coordinator.presentQuickCapture()
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("🖥️ Mostrar Ventana Principal") {
                    coordinator.showMainWindow()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}

/// Helper para capturar la referencia NSWindow de la ventana principal de SwiftUI.
struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.callback(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            self.callback(nsView.window)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NotchWindowController?
    private weak var coordinator: SessionCoordinator?
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var statusPhase: PomodoroPhase?
    private var isConfigured: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        Task {
            _ = await NotificationService.shared.requestAuthorization()
        }
    }

    func setup(coordinator: SessionCoordinator) {
        guard !isConfigured else { return }
        self.coordinator = coordinator
        self.isConfigured = true

        let surfaceView = DynamicIslandSurface(coordinator: coordinator)
        let windowController = NotchWindowController(rootView: AnyView(surfaceView))
        windowController.geometryProvider = { [weak coordinator] in
            guard let coordinator else {
                return IslandGeometry(width: 230, height: 34, cornerRadius: 17)
            }
            return IslandGeometry.current(
                metrics: coordinator.notchMetrics,
                isExpanded: coordinator.isExpanded,
                isQuickCapturePresented: coordinator.isQuickCapturePresented,
                phase: coordinator.snapshot.phase
            )
        }
        windowController.onMetricsChange = { [weak coordinator] metrics in
            coordinator?.notchMetrics = metrics
        }
        self.windowController = windowController
        coordinator.panel = windowController.panel
        coordinator.windowController = windowController
        coordinator.notchMetrics = windowController.currentMetrics
        coordinator.onSnapshotChange = { [weak self] snapshot in
            self?.updateStatusItem(with: snapshot)
        }

        setupStatusItem()
        updateStatusItem(with: coordinator.snapshot)
        windowController.show()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Pomodoro")
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Pomodoro macOS", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "🖥️ Abrir Ventana Principal", action: #selector(openMainWindowAction), keyEquivalent: "0"))
        menu.addItem(NSMenuItem(title: "🎯 Alternar Dynamic Island (⌘O)", action: #selector(toggleIslandAction), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "📝 Anotar distracción (⌘I)", action: #selector(triggerQuickCapture), keyEquivalent: "i"))
        menu.addItem(NSMenuItem(title: "⚙️ Centrar en pantalla", action: #selector(repositionIsland), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(terminateApp), keyEquivalent: "q"))

        self.statusMenu = menu
        self.statusItem = item
    }

    private func updateStatusItem(with snapshot: PomodoroSnapshot) {
        guard let button = statusItem?.button else { return }
        let time = snapshot.phase == .overtime
            ? "+\(PomodoroTimeFormat.string(from: snapshot.overtimeSeconds))"
            : PomodoroTimeFormat.string(from: snapshot.remainingSeconds)
        let title = " \(time)"
        if button.title != title {
            button.title = title
        }
        guard statusPhase != snapshot.phase else { return }
        statusPhase = snapshot.phase
        button.image = NSImage(systemSymbolName: snapshot.phase.systemImageName, accessibilityDescription: snapshot.phase.title)
        button.contentTintColor = statusTint(for: snapshot.phase)
    }

    private func statusTint(for phase: PomodoroPhase) -> NSColor {
        switch phase {
        case .idle:
            return .secondaryLabelColor
        case .work:
            return .systemOrange
        case .shortBreak:
            return .systemMint
        case .longBreak:
            return .systemCyan
        case .overtime:
            return .systemYellow
        }
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
            // Clic izquierdo: si la ventana principal está minimizada u oculta, traerla al frente; si no, alternar la isla
            if let window = coordinator?.mainWindow, window.isMiniaturized || !window.isVisible {
                coordinator?.showMainWindow()
            } else {
                toggleIslandAction()
            }
        }
    }

    @objc private func openMainWindowAction() {
        coordinator?.showMainWindow()
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        coordinator?.showMainWindow()
        return true
    }
}
