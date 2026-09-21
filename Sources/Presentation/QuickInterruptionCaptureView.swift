import SwiftUI

/// Vista de baja fricción para el registro inmediato de interrupciones internas (⌘ + I).
public struct QuickInterruptionCaptureView: View {
    @Bindable public var coordinator: SessionCoordinator
    @FocusState private var isFieldFocused: Bool

    public init(coordinator: SessionCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Anotar distracción interna (⌘ + I)", systemImage: "pencil.line")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.orange)

                Spacer()

                Button {
                    coordinator.dismissQuickCapture()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                TextField("Escribe el pensamiento (ej. 'Comprobar vuelos')...", text: $coordinator.quickCaptureText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                    .focused($isFieldFocused)
                    .onSubmit {
                        Task {
                            await coordinator.submitQuickCapture()
                        }
                    }

                Button {
                    Task {
                        await coordinator.submitQuickCapture()
                    }
                } label: {
                    Text("Anotar")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.orange)
                        .foregroundColor(.black)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            Text("El pensamiento se guardará en tu lista secundaria sin detener el cronómetro.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
        .onAppear {
            isFieldFocused = true
        }
    }
}
