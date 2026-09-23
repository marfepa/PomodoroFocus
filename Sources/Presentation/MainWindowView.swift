import SwiftUI

/// Ventana de escritorio tradicional para las métricas y el control del Pomodoro.
public struct MainWindowView: View {
    @Bindable public var coordinator: SessionCoordinator
    @State private var internalDistractionNote: String = ""
    @State private var distractionType: InterruptionType = .internal

    public init(coordinator: SessionCoordinator) {
        self.coordinator = coordinator
    }

    private var phase: PomodoroPhase {
        coordinator.snapshot.phase
    }

    private var isShowingOvertime: Bool {
        phase == .overtime || coordinator.snapshot.overtimeSeconds > 0
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
            .background(phaseAtmosphere)

            Divider()

            // Panel Lateral Derecho: Cockpit de Cirillo e Historial
            VStack(alignment: .leading, spacing: 18) {
                Text("Cockpit de Cirillo")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)

                cycleProgressCard

                metricsCard

                distractionCaptureCard

                if let focusStatusMessage = coordinator.focusStatusMessage {
                    Label(focusStatusMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                HStack {
                    SettingsLink {
                        Label("Ajustes", systemImage: "gearshape")
                    }
                    .buttonStyle(.pomodoro())

                    Spacer()

                    Button {
                        coordinator.toggleIsland()
                    } label: {
                        Label("Dynamic Island", systemImage: "sparkles")
                    }
                    .buttonStyle(.pomodoro())
                    .help("Alternar la Dynamic Island (⌘O)")
                }
            }
            .padding(24)
            .frame(width: 320)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        }
        .frame(minWidth: 780, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.6), value: phase)
        .onChange(of: coordinator.shouldMinimizeOnStart) { _, _ in
            coordinator.persistSettings()
        }
    }

    /// Halo tenue del color de la fase detrás del anillo: identifica el estado de un vistazo.
    private var phaseAtmosphere: some View {
        RadialGradient(
            colors: [phase.accentColor.opacity(phase == .idle ? 0.04 : 0.12), .clear],
            center: .center,
            startRadius: 40,
            endRadius: 340
        )
        .allowsHitTesting(false)
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
                Image(systemName: phase.systemImageName)
                    .font(.system(size: 10, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
                Text(phase.title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(phase.legibleAccentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(phase.accentColor.opacity(0.14), in: Capsule())
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
                        phase.accentColor,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: phase.accentColor.opacity(0.35), radius: 6)
                    .animation(.linear(duration: 1), value: coordinator.snapshot.progress)

                VStack(spacing: 6) {
                    if isShowingOvertime {
                        Text("+\(PomodoroTimeFormat.string(from: coordinator.snapshot.overtimeSeconds))")
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(PomodoroPhase.overtime.legibleAccentColor)
                            .rollingDigits(coordinator.snapshot.overtimeSeconds, countsDown: false)
                        Text("EN FLOW")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(.secondary)
                    } else {
                        Text(PomodoroTimeFormat.string(from: coordinator.snapshot.remainingSeconds))
                            .font(.system(size: 52, weight: .bold, design: .monospaced))
                            .foregroundColor(coordinator.snapshot.isPaused ? .secondary : .primary)
                            .rollingDigits(coordinator.snapshot.remainingSeconds)

                        Text(phase == .idle ? "Listo para comenzar" : (coordinator.snapshot.currentTaskTitle ?? "Sesión de Enfoque"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(width: 240, height: 240)

            // Selectores de duración (solo cuando está inactivo)
            if phase == .idle {
                HStack(spacing: 10) {
                    ForEach(PomodoroPreset.allPresets) { preset in
                        let isSelected = coordinator.selectedPreset == preset
                        Button(preset.shortName) {
                            Task { await coordinator.selectPreset(preset) }
                        }
                        .buttonStyle(.pomodoro(isSelected ? .primary(.orange) : .secondary))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    // MARK: - Controles y Campo de Objetivo
    private var controlsView: some View {
        VStack(spacing: 12) {
            if phase == .idle {
                HStack {
                    Image(systemName: "target")
                        .foregroundColor(.secondary)
                    TextField("¿En qué tarea te vas a enfocar?", text: $coordinator.currentTaskInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            // Botón de acción principal
            HStack(spacing: 12) {
                if phase == .idle {
                    Button {
                        Task { await coordinator.startSession() }
                    } label: {
                        Label("Iniciar Enfoque", systemImage: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 2)
                    }
                    .buttonStyle(.pomodoro(.primary(.orange), size: .regular))
                    .keyboardShortcut(.defaultAction)
                } else {
                    // Controles durante sesión activa (el overtime no se pausa)
                    if phase != .overtime {
                        Button {
                            Task {
                                if coordinator.snapshot.isPaused {
                                    await coordinator.resumeSession()
                                } else {
                                    await coordinator.pauseSession()
                                }
                            }
                        } label: {
                            Label(
                                coordinator.snapshot.isPaused ? "Reanudar" : "Pausar",
                                systemImage: coordinator.snapshot.isPaused ? "play.fill" : "pause.fill"
                            )
                            .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.pomodoro(size: .regular))
                    }

                    if phase == .overtime {
                        Button {
                            Task { await coordinator.takeBreak() }
                        } label: {
                            Label("Tomar descanso", systemImage: "cup.and.saucer.fill")
                        }
                        .buttonStyle(.pomodoro(.primary(.yellow), size: .regular))
                    }

                    if phase == .shortBreak || phase == .longBreak {
                        Button {
                            Task { await coordinator.skipBreak() }
                        } label: {
                            Label("Volver a Trabajar", systemImage: "arrow.forward")
                        }
                        .buttonStyle(.pomodoro(.primary(.mint), size: .regular))
                    }

                    Spacer()

                    Button {
                        Task { await coordinator.cancelSession() }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(.pomodoro(.destructive, size: .regular))
                    .help("Cancelar sesión")
                    .accessibilityLabel("Cancelar sesión")
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
                Text(cycleLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(1...coordinator.snapshot.totalBlocksInCycle, id: \.self) { idx in
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(blockFill(index: idx))
                            .frame(height: 24)
                        Text("\(idx)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(coordinator.snapshot.blockState(at: idx) == .completed ? .black : .secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var metricsCard: some View {
        HStack(spacing: 12) {
            metric(value: coordinator.snapshot.completedPomodorosToday, label: "Pomodoros hoy", color: .primary)

            Divider().frame(height: 32)

            metric(value: coordinator.snapshot.internalInterruptionsCount, label: "Internas (')", color: PomodoroPhase.work.legibleAccentColor)

            Divider().frame(height: 32)

            metric(value: coordinator.snapshot.externalInterruptionsCount, label: "Externas (-)", color: PomodoroPhase.longBreak.legibleAccentColor)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func metric(value: Int, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
                .contentTransition(.numericText(value: Double(value)))
                .animation(.snappy, value: value)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var distractionCaptureCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Diario de interrupciones", systemImage: "pencil.line")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(PomodoroPhase.work.legibleAccentColor)

            Picker("Tipo", selection: $distractionType) {
                Text("Interna (')").tag(InterruptionType.internal)
                Text("Externa (-)").tag(InterruptionType.external)
            }
            .pickerStyle(.segmented)
            .controlSize(.small)

            HStack(spacing: 6) {
                TextField("Anota un pensamiento rápido...", text: $internalDistractionNote)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(6)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .onSubmit {
                        submitNote()
                    }

                Button {
                    submitNote()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.pomodoro(.primary(.orange), size: .icon))
                .disabled(internalDistractionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Guardar interrupción")
            }

            if coordinator.interruptions.isEmpty {
                Text("Todavía no hay interrupciones hoy. ⌘I las anota sin parar el tiempo.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(coordinator.interruptions) { record in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(record.type.notation)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(record.type == .internal ? PomodoroPhase.work.legibleAccentColor : PomodoroPhase.longBreak.legibleAccentColor)
                                    .frame(width: 12)
                                Text(record.note)
                                    .font(.system(size: 11))
                                    .lineLimit(2)
                                Spacer(minLength: 4)
                                Text(record.timestamp, format: .dateTime.hour().minute())
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.snappy, value: coordinator.interruptions.map(\.id))
                }
                .frame(maxHeight: 120)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var cycleLabel: String {
        let snapshot = coordinator.snapshot
        switch snapshot.phase {
        case .work, .overtime:
            return "Bloque \(snapshot.currentBlockInCycle) de \(snapshot.totalBlocksInCycle)"
        case .shortBreak, .longBreak, .idle:
            if snapshot.completedBlocksInCycle > 0 {
                return "Siguiente: bloque \(snapshot.currentBlockInCycle) de \(snapshot.totalBlocksInCycle)"
            }
            return "Bloque \(snapshot.currentBlockInCycle) de \(snapshot.totalBlocksInCycle)"
        }
    }

    private func blockFill(index: Int) -> Color {
        let snapshot = coordinator.snapshot
        switch snapshot.blockState(at: index) {
        case .completed:
            return PomodoroPhase.work.accentColor
        case .current:
            return snapshot.phase.accentColor.opacity(0.45)
        case .pending:
            return Color.secondary.opacity(0.15)
        }
    }

    private func submitNote() {
        let note = internalDistractionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return }
        let type = distractionType
        Task {
            await coordinator.recordInterruption(type: type, note: note)
            internalDistractionNote = ""
        }
    }
}
