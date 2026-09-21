import SwiftUI

/// Vista detallada desplegada al posar el cursor (hover) o al abrir la captura rápida.
public struct ExpandedIslandView: View {
    @Bindable public var coordinator: SessionCoordinator

    public init(coordinator: SessionCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(spacing: 12) {
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
        .padding(14)
        .frame(width: 380)
    }

    // MARK: - Contenido: Estado Inactivo
    private var idleExpandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Nuevo Bloque Pomodoro", systemImage: "timer")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("Francesco Cirillo")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Selector de preajustes
            Picker("Duración", selection: $coordinator.selectedPreset) {
                ForEach(PomodoroPreset.allPresets) { preset in
                    Text(preset.name).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            // Campo de objetivo
            TextField("Objetivo de la sesión (opcional)...", text: $coordinator.currentTaskInput)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(8)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)

            HStack {
                Toggle("Modo Enfoque automático", isOn: $coordinator.enableFocusAutomation)
                    .font(.system(size: 11))
                    .toggleStyle(.checkbox)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    Task {
                        await coordinator.startSession()
                    }
                } label: {
                    Label("Iniciar Enfoque", systemImage: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.orange)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Contenido: Enfoque Activo
    private var workExpandedContent: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(coordinator.snapshot.currentTaskTitle ?? "Sesión de Enfoque Activo")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text("Bloque \(coordinator.snapshot.currentBlockInCycle) de \(coordinator.snapshot.totalBlocksInCycle)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        ForEach(1...coordinator.snapshot.totalBlocksInCycle, id: \.self) { idx in
                            Circle()
                                .fill(idx <= coordinator.snapshot.currentBlockInCycle ? Color.orange : Color.white.opacity(0.2))
                                .frame(width: 5, height: 5)
                        }
                    }
                }

                Spacer()

                Text(formatSeconds(coordinator.snapshot.remainingSeconds))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.orange)
            }

            // Barra de progreso lineal
            ProgressView(value: coordinator.snapshot.progress)
                .progressViewStyle(.linear)
                .tint(.orange)

            HStack(spacing: 8) {
                Button {
                    coordinator.presentQuickCapture()
                } label: {
                    Label("Anotar distracción (⌘I)", systemImage: "pencil")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button {
                    coordinator.showMainWindow()
                } label: {
                    Image(systemName: "macwindow")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

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
                        .font(.system(size: 11))
                        .padding(6)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await coordinator.cancelSession()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .padding(6)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Contenido: Descanso Corto
    private var shortBreakExpandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Descanso Corto", systemImage: "cup.and.saucer.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.mint)

                Spacer()

                Text(formatSeconds(coordinator.snapshot.remainingSeconds))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.mint)
            }

            if let advice = coordinator.snapshot.phase.ergonomicAdvice {
                Text(advice)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button {
                    Task {
                        await coordinator.addTwoMinutes()
                    }
                } label: {
                    Text("+2 min")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    Task {
                        await coordinator.skipBreak()
                    }
                } label: {
                    Label("Volver a Trabajar", systemImage: "arrow.forward.fill")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Descanso Largo (Macro-ciclo)", systemImage: "figure.walk")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.cyan)

                Spacer()

                Text(formatSeconds(coordinator.snapshot.remainingSeconds))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.cyan)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Métricas de la sesión:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                HStack(spacing: 16) {
                    Text("Pomodoros hoy: \(coordinator.snapshot.completedPomodorosToday)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Interrupciones internas: \(coordinator.snapshot.internalInterruptionsCount)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Button {
                    Task {
                        await coordinator.cancelSession()
                    }
                } label: {
                    Text("Concluir Jornada")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    Task {
                        await coordinator.startSession()
                    }
                } label: {
                    Text("Nuevo Ciclo")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
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
        VStack(spacing: 10) {
            HStack {
                Label("Tiempo Excedido (Flow)", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.yellow)

                Spacer()

                Text("+\(formatSeconds(coordinator.snapshot.overtimeSeconds))")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.yellow)
            }

            Text("El intervalo planificado terminó sin interrumpir tu concentración.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Button {
                Task {
                    await coordinator.skipBreak()
                }
            } label: {
                Text("Tomar Descanso Ahora")
                    .font(.system(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }

    private func formatSeconds(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
