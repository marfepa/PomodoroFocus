import SwiftUI

/// Ventana de escritorio tradicional para la configuración, métricas y control del Pomodoro.
public struct MainWindowView: View {
    @Bindable public var coordinator: SessionCoordinator
    @State private var internalDistractionNote: String = ""
    @State private var showSettings: Bool = false

    public init(coordinator: SessionCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Panel Principal Izquierdo: Cronómetro y Control
            VStack(spacing: 20) {
                headerView

                Spacer()

                timerDisplayView

                controlsView

                Spacer()

                footerActionView
            }
            .padding(28)
            .frame(minWidth: 460, maxWidth: 520)

            Divider()

            // Panel Lateral Derecho: Cockpit de Cirillo e Historial
            VStack(alignment: .leading, spacing: 18) {
                Text("Cockpit de Cirillo")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)

                cycleProgressCard

                metricsCard

                distractionCaptureCard

                if showSettings {
                    settingsCard
                }

                Spacer()

                HStack {
                    Button {
                        showSettings.toggle()
                    } label: {
                        Label(showSettings ? "Ocultar Ajustes" : "Ajustes de Enfoque", systemImage: "gearshape")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        coordinator.toggleIsland()
                    } label: {
                        Label("Notch Dynamic Island", systemImage: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundColor(.accentColor)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .frame(width: 320)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        }
        .frame(minWidth: 780, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Cabecera
    private var headerView: some View {
        HStack {
            Image(systemName: "timer")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.orange)

            Text("Pomodoro")
                .font(.system(size: 18, weight: .bold))

            Spacer()

            // Badge de fase actual
            HStack(spacing: 6) {
                Circle()
                    .fill(coordinator.snapshot.phase.accentColor)
                    .frame(width: 8, height: 8)
                Text(coordinator.snapshot.phase.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(coordinator.snapshot.phase.accentColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(coordinator.snapshot.phase.accentColor.opacity(0.12))
            .cornerRadius(12)
        }
    }

    // MARK: - Visualización del Temporizador
    private var timerDisplayView: some View {
        VStack(spacing: 16) {
            ZStack {
                // Anillo de fondo
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 14)

                // Anillo de progreso
                Circle()
                    .trim(from: 0, to: CGFloat(coordinator.snapshot.progress))
                    .stroke(
                        coordinator.snapshot.phase.accentColor,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: coordinator.snapshot.progress)

                VStack(spacing: 6) {
                    if coordinator.snapshot.overtimeSeconds > 0 {
                        Text("+\(formatSeconds(coordinator.snapshot.overtimeSeconds))")
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundColor(.yellow)
                        Text("TIEMPO EXCEDIDO")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    } else {
                        Text(formatSeconds(coordinator.snapshot.remainingSeconds))
                            .font(.system(size: 52, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundColor(.primary)

                        Text(coordinator.snapshot.phase == .idle ? "Listo para comenzar" : (coordinator.snapshot.currentTaskTitle ?? "Sesión de Enfoque"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(width: 240, height: 240)

            // Selectores de duración (solo cuando está inactivo)
            if coordinator.snapshot.phase == .idle {
                HStack(spacing: 10) {
                    ForEach(PomodoroPreset.allPresets) { preset in
                        Button {
                            coordinator.selectedPreset = preset
                        } label: {
                            Text(preset.name)
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(coordinator.selectedPreset == preset ? Color.orange : Color.secondary.opacity(0.12))
                                .foregroundColor(coordinator.selectedPreset == preset ? .black : .primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Controles y Campo de Objetivo
    private var controlsView: some View {
        VStack(spacing: 12) {
            if coordinator.snapshot.phase == .idle {
                HStack {
                    Image(systemName: "target")
                        .foregroundColor(.secondary)
                    TextField("¿En qué tarea te vas a enfocar?", text: $coordinator.currentTaskInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(10)
            }

            // Botón de acción principal
            HStack(spacing: 12) {
                if coordinator.snapshot.phase == .idle {
                    Button {
                        Task {
                            await coordinator.startSession()
                        }
                    } label: {
                        Label("Iniciar Enfoque", systemImage: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange)
                            .foregroundColor(.black)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Controles durante sesión activa
                    Button {
                        Task {
                            if coordinator.snapshot.isPaused {
                                await coordinator.resumeSession()
                            } else {
                                await coordinator.pauseSession()
                            }
                        }
                    } label: {
                        Label(coordinator.snapshot.isPaused ? "Reanudar" : "Pausar", systemImage: coordinator.snapshot.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.secondary.opacity(0.15))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    if coordinator.snapshot.phase == .shortBreak || coordinator.snapshot.phase == .longBreak {
                        Button {
                            Task {
                                await coordinator.skipBreak()
                            }
                        } label: {
                            Label("Volver a Trabajar", systemImage: "arrow.forward.fill")
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.mint)
                                .foregroundColor(.black)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Button {
                        Task {
                            await coordinator.cancelSession()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .padding(10)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var footerActionView: some View {
        HStack {
            Toggle("Pasar a Dynamic Island al iniciar", isOn: $coordinator.shouldMinimizeOnStart)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    // MARK: - Panel Lateral: Tarjetas de Productividad
    private var cycleProgressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Macro-Ciclo")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text("Bloque \(coordinator.snapshot.currentBlockInCycle) de \(coordinator.snapshot.totalBlocksInCycle)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(1...coordinator.snapshot.totalBlocksInCycle, id: \.self) { idx in
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(idx <= coordinator.snapshot.currentBlockInCycle ? Color.orange : Color.secondary.opacity(0.15))
                            .frame(height: 24)
                        Text("\(idx)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(idx <= coordinator.snapshot.currentBlockInCycle ? .black : .secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(10)
    }

    private var metricsCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(coordinator.snapshot.completedPomodorosToday)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Text("Pomodoros hoy")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().frame(height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(coordinator.snapshot.internalInterruptionsCount)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.orange)
                Text("Interrupciones (')")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(10)
    }

    private var distractionCaptureCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Distracción interna (⌘I)", systemImage: "pencil.line")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.orange)
            }

            HStack(spacing: 6) {
                TextField("Anota un pensamiento rápido...", text: $internalDistractionNote)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(6)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(6)
                    .onSubmit {
                        submitNote()
                    }

                Button {
                    submitNote()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }

            Text("Guarda la distracción en la lista sin detener el cronómetro.")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(10)
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ajustes de Concentración")
                .font(.system(size: 11, weight: .bold))

            Toggle("Automatizar Modos de Concentración", isOn: $coordinator.enableFocusAutomation)
                .font(.system(size: 10))

            TextField("Nombre de atajo al trabajar", text: $coordinator.workShortcutName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 10))

            TextField("Nombre de atajo al descansar", text: $coordinator.defaultShortcutName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 10))
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(10)
    }

    private func submitNote() {
        let note = internalDistractionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return }
        Task {
            await coordinator.engine.recordInterruption(type: .internal, note: note)
            coordinator.snapshot = await coordinator.engine.getSnapshot()
            internalDistractionNote = ""
        }
    }

    private func formatSeconds(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
