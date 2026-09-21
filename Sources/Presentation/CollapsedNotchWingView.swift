import SwiftUI

/// Vista colapsada de la Dynamic Island que se ubica a los lados del notch de hardware o en una cápsula compacta.
public struct CollapsedNotchWingView: View {
    public let snapshot: PomodoroSnapshot
    public let hasHardwareNotch: Bool

    public init(snapshot: PomodoroSnapshot, hasHardwareNotch: Bool) {
        self.snapshot = snapshot
        self.hasHardwareNotch = hasHardwareNotch
    }

    public var body: some View {
        HStack(alignment: .center) {
            // Ala Izquierda
            leftWingView

            Spacer(minLength: hasHardwareNotch ? 190 : 14)

            // Ala Derecha
            rightWingView
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
    }

    @ViewBuilder
    private var leftWingView: some View {
        HStack(spacing: 5) {
            Image(systemName: snapshot.phase.systemImageName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(snapshot.phase.accentColor)

            if snapshot.overtimeSeconds > 0 {
                Text("+\(PomodoroTimeFormat.string(from: snapshot.overtimeSeconds))")
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.yellow)
            } else {
                Text(PomodoroTimeFormat.string(from: snapshot.remainingSeconds))
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.white)
            }
        }
    }

    @ViewBuilder
    private var rightWingView: some View {
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
            }
            .frame(width: 13, height: 13)

            // Indicador de bloques del ciclo [●●○○]
            HStack(spacing: 2.5) {
                ForEach(1...snapshot.totalBlocksInCycle, id: \.self) { index in
                    Circle()
                        .fill(index <= snapshot.currentBlockInCycle ? snapshot.phase.accentColor : Color.white.opacity(0.2))
                        .frame(width: 3.5, height: 3.5)
                }
            }
        }
    }

}
