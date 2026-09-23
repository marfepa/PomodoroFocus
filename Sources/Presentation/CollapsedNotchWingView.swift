import SwiftUI

/// Vista colapsada de la Dynamic Island que se ubica a los lados del notch de hardware o en una cápsula compacta.
public struct CollapsedNotchWingView: View {
    public let snapshot: PomodoroSnapshot
    /// Ancho del notch físico; `nil` en la cápsula flotante.
    public let notchWidth: CGFloat?
    private let namespace: Namespace.ID

    public init(snapshot: PomodoroSnapshot, notchWidth: CGFloat?, namespace: Namespace.ID) {
        self.snapshot = snapshot
        self.notchWidth = notchWidth
        self.namespace = namespace
    }

    public var body: some View {
        HStack(alignment: .center) {
            // Ala Izquierda
            leftWingView

            Spacer(minLength: notchWidth.map { $0 + 8 } ?? 10)

            // Ala Derecha
            rightWingView
        }
        .padding(.horizontal, snapshot.phase == .idle ? 12 : 14)
        .frame(height: 34)
    }

    @ViewBuilder
    private var leftWingView: some View {
        HStack(spacing: 5) {
            Image(systemName: snapshot.phase == .idle ? "timer" : snapshot.phase.systemImageName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(snapshot.phase.accentColor)
                .symbolEffect(.bounce, value: snapshot.phase)
                .symbolEffect(.pulse, isActive: snapshot.phase == .overtime)
                .contentTransition(.symbolEffect(.replace))

            if snapshot.phase != .idle {
                timerText
                    .matchedGeometryEffect(id: "timer", in: namespace)
            }
        }
    }

    private var timerText: some View {
        Group {
            if snapshot.overtimeSeconds > 0 {
                Text("+\(PomodoroTimeFormat.string(from: snapshot.overtimeSeconds))")
                    .foregroundColor(.yellow)
                    .rollingDigits(snapshot.overtimeSeconds, countsDown: false)
            } else {
                Text(PomodoroTimeFormat.string(from: snapshot.remainingSeconds))
                    .foregroundColor(snapshot.isPaused ? .secondary : .white)
                    .rollingDigits(snapshot.remainingSeconds)
            }
        }
        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
    }

    @ViewBuilder
    private var rightWingView: some View {
        if snapshot.phase == .idle {
            Text("\(Int(snapshot.currentPreset.workDuration / 60))′")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
        } else {
            activeRightWing
        }
    }

    private var activeRightWing: some View {
        HStack(spacing: 6) {
            // Nombre de la tarea o fase abreviada
            if let taskTitle = snapshot.currentTaskTitle, !taskTitle.isEmpty {
                Text(taskTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 85, alignment: .trailing)
            }

            // Anillo de progreso radial compacto
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: CGFloat(snapshot.progress))
                    .stroke(
                        snapshot.phase.accentColor,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: snapshot.progress)
            }
            .frame(width: 13, height: 13)

            // Indicador de bloques del ciclo [●●○○]
            HStack(spacing: 2.5) {
                ForEach(1...snapshot.totalBlocksInCycle, id: \.self) { index in
                    Circle()
                        .fill(blockDotColor(index: index))
                        .frame(width: 3.5, height: 3.5)
                }
            }
        }
    }

    private func blockDotColor(index: Int) -> Color {
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
