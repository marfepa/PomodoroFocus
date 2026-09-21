import SwiftUI
import AppKit

/// Lienzo de superficie principal para la Dynamic Island de macOS.
/// Gestiona la morfología elástica continua de resorte y el paso de eventos a ventanas inferiores.
public struct DynamicIslandSurface: View {
    @Bindable public var coordinator: SessionCoordinator

    public init(coordinator: SessionCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    // Fondo oscuro continuo tipo Dynamic Island
                    RoundedRectangle(
                        cornerRadius: geometry.cornerRadius,
                        style: .continuous
                    )
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: geometry.cornerRadius,
                            style: .continuous
                        )
                        .stroke(borderColor, lineWidth: coordinator.snapshot.phase == .overtime || coordinator.snapshot.overtimeSeconds > 0 ? 1.5 : 0.6)
                    )
                    .shadow(color: shadowColor, radius: coordinator.isExpanded ? 16 : 4, y: coordinator.isExpanded ? 8 : 2)

                    // Contenido interno conmutado
                    Group {
                        if coordinator.isExpanded {
                            ExpandedIslandView(coordinator: coordinator)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.94)),
                                    removal: .opacity
                                ))
                        } else {
                            CollapsedNotchWingView(
                                snapshot: coordinator.snapshot,
                                hasHardwareNotch: coordinator.notchMetrics.hasHardwareNotch
                            )
                            .transition(.opacity)
                        }
                    }
                }
                .frame(width: geometry.width, height: geometry.height)
                .contentShape(RoundedRectangle(cornerRadius: geometry.cornerRadius, style: .continuous))
                .onHover { isInside in
                    coordinator.handleHoverChange(isInside: isInside)
                }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.36, dampingFraction: 0.72), value: coordinator.isExpanded)
        .animation(.spring(response: 0.36, dampingFraction: 0.72), value: coordinator.snapshot.phase)
    }

    private var geometry: IslandGeometry {
        IslandGeometry.current(
            metrics: coordinator.notchMetrics,
            isExpanded: coordinator.isExpanded,
            isQuickCapturePresented: coordinator.isQuickCapturePresented,
            phase: coordinator.snapshot.phase
        )
    }

    private var borderColor: Color {
        if coordinator.snapshot.phase == .overtime || coordinator.snapshot.overtimeSeconds > 0 {
            return Color.yellow.opacity(0.8)
        }
        if coordinator.snapshot.phase == .work {
            return Color.orange.opacity(0.35)
        }
        return Color.white.opacity(0.12)
    }

    private var shadowColor: Color {
        if coordinator.snapshot.phase == .overtime || coordinator.snapshot.overtimeSeconds > 0 {
            return Color.yellow.opacity(0.25)
        }
        return Color.black.opacity(coordinator.isExpanded ? 0.45 : 0.2)
    }
}
