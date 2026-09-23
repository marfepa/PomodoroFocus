import SwiftUI

/// Ventana de Ajustes (⌘,): automatización de Modos de Concentración.
public struct SettingsView: View {
    @Bindable public var coordinator: SessionCoordinator

    public init(coordinator: SessionCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        Form {
            Section {
                Toggle("Automatizar Modos de Concentración", isOn: $coordinator.enableFocusAutomation)
                TextField("Atajo al trabajar", text: $coordinator.workShortcutName)
                    .disabled(!coordinator.enableFocusAutomation)
                TextField("Atajo al descansar", text: $coordinator.defaultShortcutName)
                    .disabled(!coordinator.enableFocusAutomation)

                if let focusStatusMessage = coordinator.focusStatusMessage {
                    Label(focusStatusMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text("Concentración")
            } footer: {
                Text("Se ejecutan con la app Atajos al entrar y salir del trabajo.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: coordinator.enableFocusAutomation) { _, _ in
            coordinator.persistSettings()
        }
        .onChange(of: coordinator.workShortcutName) { _, _ in
            coordinator.persistSettings()
        }
        .onChange(of: coordinator.defaultShortcutName) { _, _ in
            coordinator.persistSettings()
        }
    }
}
