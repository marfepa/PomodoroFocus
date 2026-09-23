import SwiftUI
import AppKit

/// Lienzo de superficie principal para la Dynamic Island de macOS.
/// Gestiona la morfología elástica continua de resorte y el paso de eventos a ventanas inferiores.
public struct DynamicIslandSurface: View {
    @Bindable public var coordinator: SessionCoordinator
    @Namespace private var islandNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(coordinator: SessionCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                islandShape
                    .fill(Color.black)
                    .overlay(islandShape.stroke(borderColor, lineWidth: isOvertime ? 1.5 : 0.6))
                    .overlay { overtimeBreathingBorder }
                    .shadow(color: shadowColor, radius: coordinator.isExpanded ? 16 : 4, y: coordinator.isExpanded ? 8 : 2)

                // Contenido interno conmutado
                Group {
                    if coordinator.isExpanded {
                        ExpandedIslandView(coordinator: coordinator, namespace: islandNamespace)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .top)),
                                removal: .opacity
                            ))
                    } else {
                        CollapsedNotchWingView(
                            snapshot: coordinator.snapshot,
                            notchWidth: coordinator.notchMetrics.hasHardwareNotch ? coordinator.notchMetrics.frame.width : nil,
                            namespace: islandNamespace
                        )
                        .transition(.opacity)
                    }
                }
                .padding(.top, geometry.topInset)
                .padding(.horizontal, geometry.earRadius)
                .frame(width: geometry.width, height: geometry.height, alignment: .top)
                .clipShape(islandShape)
            }
            .frame(width: geometry.width, height: geometry.height)
            .contentShape(islandShape)
            .keyframeAnimator(initialValue: PhaseCue(), trigger: coordinator.snapshot.phase) { content, cue in
                content
                    .overlay(
                        islandShape
                            .stroke(coordinator.snapshot.phase.accentColor, lineWidth: 2)
                            .blur(radius: 3)
                            .opacity(cue.glow)
                    )
                    .scaleEffect(reduceMotion ? 1 : cue.scale, anchor: .top)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.05, duration: 0.16, spring: .snappy)
                    SpringKeyframe(1.0, duration: 0.45, spring: .bouncy)
                }
                KeyframeTrack(\.glow) {
                    LinearKeyframe(0.9, duration: 0.12)
                    LinearKeyframe(0, duration: 0.9)
                }
            }
            .onHover { isInside in
                coordinator.handleHoverChange(isInside: isInside)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
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

    private var islandShape: IslandShape {
        IslandShape(earRadius: geometry.earRadius, cornerRadius: geometry.cornerRadius)
    }

    private var isOvertime: Bool {
        coordinator.snapshot.phase == .overtime || coordinator.snapshot.overtimeSeconds > 0
    }

    /// En flow el borde late despacio para recordar que el bloque ya terminó, sin exigir atención.
    @ViewBuilder
    private var overtimeBreathingBorder: some View {
        if isOvertime && !reduceMotion {
            islandShape
                .stroke(Color.yellow, lineWidth: 1.5)
                .blur(radius: 2)
                .phaseAnimator([0.15, 0.7]) { border, opacity in
                    border.opacity(opacity)
                } animation: { _ in
                    .easeInOut(duration: 1.8)
                }
        }
    }

    private var borderColor: Color {
        if isOvertime {
            return Color.yellow.opacity(0.8)
        }
        if coordinator.snapshot.phase == .work {
            return Color.orange.opacity(0.35)
        }
        return Color.white.opacity(0.12)
    }

    private var shadowColor: Color {
        if isOvertime {
            return Color.yellow.opacity(0.25)
        }
        return Color.black.opacity(coordinator.isExpanded ? 0.45 : 0.2)
    }
}

/// Valores del aviso visual al cambiar de fase: un pequeño rebote y un destello del nuevo color.
private struct PhaseCue {
    var scale: CGFloat = 1
    var glow: Double = 0
}
