import SwiftUI
import AppKit

/// Lienzo de superficie principal para la Dynamic Island de macOS.
/// Gestiona la morfología elástica continua de resorte y el paso de eventos a ventanas inferiores.
public struct DynamicIslandSurface: View {
    @Bindable public var coordinator: SessionCoordinator
    public let metrics: DisplayNotchMetrics

    public init(coordinator: SessionCoordinator, metrics: DisplayNotchMetrics) {
        self.coordinator = coordinator
        self.metrics = metrics
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Contenedor orgánico de la cápsula
            ZStack(alignment: .top) {
                // Fondo oscuro continuo tipo Dynamic Island
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: cornerRadius,
                        style: .continuous
                    )
                    .stroke(borderColor, lineWidth: coordinator.snapshot.overtimeSeconds > 0 ? 1.5 : 0.6)
                )
                .shadow(color: shadowColor, radius: coordinator.isExpanded ? 16 : 4, y: coordinator.isExpanded ? 8 : 2)

                // Contenido interno conmutado
                Group {
                    if coordinator.isExpanded {
                        ExpandedIslandView(coordinator: coordinator)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    } else {
                        CollapsedNotchWingView(
                            snapshot: coordinator.snapshot,
                            hasHardwareNotch: metrics.hasHardwareNotch
                        )
                        .transition(.opacity)
                    }
                }
            }
            .frame(width: capsuleWidth, height: capsuleHeight)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onHover { isInside in
                coordinator.handleHoverChange(isInside: isInside)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: coordinator.isExpanded)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Geometría Dinámica
    private var capsuleWidth: CGFloat {
        if coordinator.isExpanded {
            return 390
        }
        if metrics.hasHardwareNotch {
            return max(metrics.frame.width + 120, 240)
        }
        return 220
    }

    private var capsuleHeight: CGFloat {
        if coordinator.isExpanded {
            if coordinator.isQuickCapturePresented {
                return 150
            }
            switch coordinator.snapshot.phase {
            case .idle:
                return 170
            case .work:
                return 155
            case .shortBreak:
                return 150
            case .longBreak:
                return 165
            case .overtime:
                return 140
            }
        }
        return metrics.hasHardwareNotch ? max(metrics.frame.height + 4, 34) : 34
    }

    private var cornerRadius: CGFloat {
        if coordinator.isExpanded {
            return 22
        }
        return metrics.hasHardwareNotch ? 10 : 17
    }

    private var borderColor: Color {
        if coordinator.snapshot.overtimeSeconds > 0 {
            return Color.yellow.opacity(0.8)
        }
        if coordinator.snapshot.phase == .work {
            return Color.orange.opacity(0.35)
        }
        return Color.white.opacity(0.12)
    }

    private var shadowColor: Color {
        if coordinator.snapshot.overtimeSeconds > 0 {
            return Color.yellow.opacity(0.25)
        }
        return Color.black.opacity(coordinator.isExpanded ? 0.45 : 0.2)
    }
}
