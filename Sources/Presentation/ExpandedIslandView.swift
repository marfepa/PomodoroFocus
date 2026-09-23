import SwiftUI

/// Vista detallada desplegada al posar el cursor (hover) o al abrir la captura rápida.
public struct ExpandedIslandView: View {
    @Bindable public var coordinator: SessionCoordinator

    public init(coordinator: SessionCoordinator) {
        self.coordinator = coordinator
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
        .frame(width: 330)
    }

    // MARK: - Contenido: Estado Inactivo
    private var idleExpandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Pomodoro Focus", systemImage: "timer")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                Spacer()
                Button {
                    coordinator.showMainWindow()
                } label: {
                    Image(systemName: "macwindow")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            TextField("¿En qué te vas a enfocar?", text: $coordinator.currentTaskInput)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(6)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)

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
                    Task {
                        await coordinator.startSession()
                    }
                } label: {
                    Label("Iniciar", systemImage: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.orange)
                        .foregroundColor(.black)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
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

                Text(PomodoroTimeFormat.string(from: coordinator.snapshot.remainingSeconds))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.orange)
            }

            // Fila 2: Barra de progreso sutil
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 3.5)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(coordinator.snapshot.progress), height: 3.5)
                }
            }
            .frame(height: 3.5)

            // Fila 3: Botones de acción integrados
            HStack(spacing: 6) {
                Button {
                    coordinator.presentQuickCapture()
                } label: {
                    Label("Anotar (⌘I)", systemImage: "pencil")
                        .font(.system(size: 10.5, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Anotar distracción")

                Spacer()

                Button {
                    coordinator.showMainWindow()
                } label: {
                    Image(systemName: "macwindow")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Abrir ventana principal")

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
                        .font(.system(size: 10.5))
                        .padding(5)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(coordinator.snapshot.isPaused ? "Reanudar" : "Pausar")

                Button {
                    Task {
                        await coordinator.cancelSession()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10.5))
                        .foregroundColor(.red.opacity(0.9))
                        .padding(5)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancelar sesión")
            }
        }
    }

    // MARK: - Contenido: Descanso Corto
    private var shortBreakExpandedContent: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Descanso Corto", systemImage: "cup.and.saucer.fill")
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

                Text(PomodoroTimeFormat.string(from: coordinator.snapshot.remainingSeconds))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.mint)
            }

            HStack(spacing: 8) {
                Button {
                    Task {
                        await coordinator.addTwoMinutes()
                    }
                } label: {
                    Text("+2 min")
                        .font(.system(size: 10.5, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    Task {
                        await coordinator.skipBreak()
                    }
                } label: {
                    Label("Seguir", systemImage: "arrow.forward.fill")
                        .font(.system(size: 10.5, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.mint)
                        .foregroundColor(.black)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Contenido: Descanso Largo
    private var longBreakExpandedContent: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Descanso Largo", systemImage: "figure.walk")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.cyan)

                    Text("Hoy: \(coordinator.snapshot.completedPomodorosToday) bloques • \(coordinator.snapshot.internalInterruptionsCount) interr.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(PomodoroTimeFormat.string(from: coordinator.snapshot.remainingSeconds))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.cyan)
            }

            HStack(spacing: 8) {
                Button {
                    Task {
                        await coordinator.cancelSession()
                    }
                } label: {
                    Text("Concluir")
                        .font(.system(size: 10.5, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    Task {
                        await coordinator.startNextWorkBlock()
                    }
                } label: {
                    Text("Nuevo Ciclo")
                        .font(.system(size: 10.5, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.cyan)
                        .foregroundColor(.black)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Contenido: Overtime / Flow
    private var overtimeExpandedContent: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Flow Excedido", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.yellow)

                Spacer()

                Text("+\(PomodoroTimeFormat.string(from: coordinator.snapshot.overtimeSeconds))")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.yellow)
            }

            Button {
                Task {
                    await coordinator.takeBreak()
                }
            } label: {
                Text("Tomar Descanso Ahora")
                    .font(.system(size: 11, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
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
