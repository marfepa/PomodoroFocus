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
        HStack {
            // Ala Izquierda
            leftWingView

            Spacer(minLength: hasHardwareNotch ? 195 : 16)

            // Ala Derecha
            rightWingView
        }
        .padding(.horizontal, 18)
        .frame(height: 40)
    }

    @ViewBuilder
    private var leftWingView: some View {
        HStack(spacing: 6) {
            Image(systemName: snapshot.phase.systemImageName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(snapshot.phase.accentColor)

            if snapshot.phase == .idle {
                Text("Pomodoro")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            } else if snapshot.overtimeSeconds > 0 {
                Text("+\(formatSeconds(snapshot.overtimeSeconds))")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.yellow)
            } else {
                Text(formatSeconds(snapshot.remainingSeconds))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.white)
            }
        }
    }

    @ViewBuilder
    private var rightWingView: some View {
        HStack(spacing: 6) {
            if snapshot.phase == .work || snapshot.phase == .shortBreak || snapshot.phase == .longBreak {
                // Anillo de progreso radial compacto
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: CGFloat(snapshot.progress))
                        .stroke(
                            snapshot.phase.accentColor,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 14, height: 14)

                // Indicador de bloque del ciclo [● ● ○ ○]
                HStack(spacing: 3) {
                    ForEach(1...snapshot.totalBlocksInCycle, id: \.self) { index in
                        Circle()
                            .fill(index <= snapshot.currentBlockInCycle ? snapshot.phase.accentColor : Color.white.opacity(0.2))
                            .frame(width: 4, height: 4)
                    }
                }
            } else {
                Text(snapshot.currentPreset.name.prefix(6))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatSeconds(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
