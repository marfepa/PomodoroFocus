import CoreGraphics

/// Tamaño único de la cápsula. Lo usan el lienzo SwiftUI y el hit-test del panel.
public struct IslandGeometry: Sendable, Equatable {
    public let width: CGFloat
    public let height: CGFloat
    public let cornerRadius: CGFloat

    public init(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public static func current(
        metrics: DisplayNotchMetrics,
        isExpanded: Bool,
        isQuickCapturePresented: Bool,
        phase: PomodoroPhase
    ) -> IslandGeometry {
        if isExpanded {
            return IslandGeometry(
                width: 350,
                height: expandedHeight(isQuickCapturePresented: isQuickCapturePresented, phase: phase),
                cornerRadius: 22
            )
        }
        if metrics.hasHardwareNotch {
            return IslandGeometry(
                width: max(metrics.frame.width + 250, 440),
                height: max(metrics.frame.height + 4, 36),
                cornerRadius: 16
            )
        }
        return IslandGeometry(width: 230, height: 34, cornerRadius: 17)
    }

    /// Rectángulo de la cápsula dentro del panel (origen AppKit, abajo-izquierda).
    public func rect(panelWidth: CGFloat, panelHeight: CGFloat) -> CGRect {
        CGRect(
            x: (panelWidth - width) / 2,
            y: panelHeight - height,
            width: width,
            height: height
        )
    }

    private static func expandedHeight(isQuickCapturePresented: Bool, phase: PomodoroPhase) -> CGFloat {
        if isQuickCapturePresented {
            return 176
        }
        switch phase {
        case .idle:
            return 158
        case .work:
            return 118
        case .shortBreak:
            return 115
        case .longBreak:
            return 125
        case .overtime:
            return 118
        }
    }
}
