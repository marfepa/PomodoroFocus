import SwiftUI

/// Vista detallada desplegada al posar el cursor (hover) o al abrir la captura rápida.
public struct ExpandedIslandView: View {
    @Bindable public var coordinator: SessionCoordinator
    private let namespace: Namespace.ID

    public init(coordinator: SessionCoordinator, namespace: Namespace.ID) {
        self.coordinator = coordinator
        self.namespace = namespace
    }

    public var body: some View {
        VStack(spacing: 8) {
            if coordinator.isQuickCapturePresented {
                QuickInterruptionCaptureView(coordinator: coordinator)
            } else {
                switch coordinator.snapshot.phase {
                case .idle:
                    idleExpandedContent
                case .work:
                    workExpandedContent
                case .shortBreak:
                    shortBreakExpandedContent
                case .longBreak:
                    longBreakExpandedContent
                case .overtime:
                    overtimeExpandedContent
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Contenido: Estado Inactivo
    private var idleExpandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Pomodoro Focus", systemImage: "timer")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                Spacer()
                mainWindowButton
            }

            TextField("¿En qué te vas a enfocar?", text: $coordinator.currentTaskInput)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(6)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            if coordinator.snapshot.completedBlocksInCycle > 0 {
                Text("Siguiente: bloque \(coordinator.snapshot.currentBlockInCycle) de \(coordinator.snapshot.totalBlocksInCycle)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            HStack {
                Picker("Preajuste", selection: $coordinator.selectedPreset) {
                    ForEach(PomodoroPreset.allPresets) { preset in
                        Text(preset.shortName).tag(preset)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(.orange)
                .onChange(of: coordinator.selectedPreset) { _, preset in
                    Task { await coordinator.selectPreset(preset) }
                }

                Spacer()

                Button {
                    Task { await coordinator.startSession() }
                } label: {
                    Label("Iniciar", systemImage: "play.fill")
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.pomodoro(.primary(.orange)))
            }
        }
    }

    // MARK: - Contenido: Enfoque Activo
    private var workExpandedContent: some View {
        VStack(spacing: 8) {
            // Fila 1: Título de tarea + Estado de ciclo + Temporizador nítido
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(coordinator.snapshot.currentTaskTitle ?? "Sesión de Enfoque")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text("Bloque \(coordinator.snapshot.currentBlockInCycle)/\(coordinator.snapshot.totalBlocksInCycle)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        ForEach(1...coordinator.snapshot.totalBlocksInCycle, id: \.self) { idx in
                            Circle()
                                .fill(blockDotColor(index: idx))
                                .frame(width: 4, height: 4)
                        }
                    }
                }

                Spacer()

                countdown(color: coordinator.snapshot.isPaused ? .secondary : .orange)
            }

            // Fila 2: Barra de progreso sutil
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(coordinator.snapshot.progress))
                        .animation(.linear(duration: 1), value: coordinator.snapshot.progress)
                }
            }
            .frame(height: 3.5)

            // Fila 3: Botones de acción integrados
            HStack(spacing: 6) {
                Button {
                    coordinator.presentQuickCapture()
                } label: {
                    Label("Anotar (⌘I)", systemImage: "pencil")
                }
                .buttonStyle(.pomodoro())
                .accessibilityLabel("Anotar distracción")

                Spacer()

                mainWindowButton

                Button {
                    Task {
                        if coordinator.snapshot.isPaused {
                            await coordinator.resumeSession()
                        } else {
                            await coordinator.pauseSession()
                        }
                    }
                } label: {
                    Image(systemName: coordinator.snapshot.isPaused ? "play.fill" : "pause.fill")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.pomodoro(size: .icon))
                .accessibilityLabel(coordinator.snapshot.isPaused ? "Reanudar" : "Pausar")

                Button {
                    Task { await coordinator.cancelSession() }
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.pomodoro(.destructive, size: .icon))
                .accessibilityLabel("Cancelar sesión")
            }
        }
    }

    // MARK: - Contenido: Descanso Corto
    private var shortBreakExpandedContent: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Descanso Corto", systemImage: PomodoroPhase.shortBreak.systemImageName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.mint)

                    if let advice = coordinator.snapshot.phase.ergonomicAdvice {
                        Text(advice)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                countdown(color: .mint)
            }

            HStack(spacing: 8) {
                Button("+2 min") {
                    Task { await coordinator.addTwoMinutes() }
                }
                .buttonStyle(.pomodoro())

                Spacer()

                Button {
                    Task { await coordinator.skipBreak() }
                } label: {
                    Label("Seguir", systemImage: "arrow.forward")
                        .padding(.horizontal, 2)
                }
                .buttonStyle(.pomodoro(.primary(.mint)))
            }
        }
    }

    // MARK: - Contenido: Descanso Largo
    private var longBreakExpandedContent: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Descanso Largo", systemImage: PomodoroPhase.longBreak.systemImageName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.cyan)

                    Text("Hoy: \(coordinator.snapshot.completedPomodorosToday) bloques • \(coordinator.snapshot.internalInterruptionsCount) interr.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                countdown(color: .cyan)
            }

            HStack(spacing: 8) {
                Button("Concluir") {
                    Task { await coordinator.cancelSession() }
                }
                .buttonStyle(.pomodoro())

                Spacer()

                Button("Nuevo Ciclo") {
                    Task { await coordinator.startNextWorkBlock() }
                }
                .buttonStyle(.pomodoro(.primary(.cyan)))
            }
        }
    }

    // MARK: - Contenido: Overtime / Flow
    private var overtimeExpandedContent: some View {
        VStack(spacing: 8) {
            HStack {
                Label("En flow", systemImage: PomodoroPhase.overtime.systemImageName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.yellow)
                    .symbolEffect(.pulse)

                Spacer()

                Text("+\(PomodoroTimeFormat.string(from: coordinator.snapshot.overtimeSeconds))")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                    .rollingDigits(coordinator.snapshot.overtimeSeconds, countsDown: false)
                    .matchedGeometryEffect(id: "timer", in: namespace)
            }

            Button {
                Task { await coordinator.takeBreak() }
            } label: {
                Label("Tomar descanso ahora", systemImage: "cup.and.saucer.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pomodoro(.primary(.yellow)))
        }
    }

    private func countdown(color: Color) -> some View {
        Text(PomodoroTimeFormat.string(from: coordinator.snapshot.remainingSeconds))
            .font(.system(size: 20, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .rollingDigits(coordinator.snapshot.remainingSeconds)
            .matchedGeometryEffect(id: "timer", in: namespace)
    }

    private var mainWindowButton: some View {
        Button {
            coordinator.showMainWindow()
        } label: {
            Image(systemName: "macwindow")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.pomodoro(size: .icon))
        .accessibilityLabel("Abrir ventana principal")
    }

    private func blockDotColor(index: Int) -> Color {
        let snapshot = coordinator.snapshot
        switch snapshot.blockState(at: index) {
        case .completed:
            return PomodoroPhase.work.accentColor
        case .current:
            return snapshot.phase.accentColor.opacity(0.45)
        case .pending:
            return Color.white.opacity(0.2)
        }
    }
}
