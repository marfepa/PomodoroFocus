import CoreGraphics

/// Tamaño único de la cápsula. Lo usan el lienzo SwiftUI y el hit-test del panel.
public struct IslandGeometry: Sendable, Equatable {
    public let width: CGFloat
    public let height: CGFloat
    public let cornerRadius: CGFloat
    /// Orejas cóncavas que funden la isla con el bisel; 0 en la cápsula flotante.
    public let earRadius: CGFloat
    /// Franja superior tapada por el notch físico, donde no se puede dibujar contenido.
    public let topInset: CGFloat

    public init(width: CGFloat, height: CGFloat, cornerRadius: CGFloat, earRadius: CGFloat = 0, topInset: CGFloat = 0) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.earRadius = earRadius
        self.topInset = topInset
    }

    public static func current(
        metrics: DisplayNotchMetrics,
        isExpanded: Bool,
        isQuickCapturePresented: Bool,
        phase: PomodoroPhase
    ) -> IslandGeometry {
        let ear: CGFloat = metrics.hasHardwareNotch ? (isExpanded ? 12 : 8) : 0

        if isExpanded {
            let topInset = metrics.hasHardwareNotch ? metrics.frame.height : 0
            return IslandGeometry(
                width: 350 + ear * 2,
                height: expandedHeight(isQuickCapturePresented: isQuickCapturePresented, phase: phase) + topInset,
                cornerRadius: 22,
                earRadius: ear,
                topInset: topInset
            )
        }

        let wingWidth: CGFloat = phase == .idle ? 90 : 250
        if metrics.hasHardwareNotch {
            return IslandGeometry(
                width: max(metrics.frame.width + wingWidth, phase == .idle ? 0 : 440) + ear * 2,
                height: max(metrics.frame.height + 4, 36),
                cornerRadius: 16,
                earRadius: ear
            )
        }
        return IslandGeometry(width: phase == .idle ? 110 : 230, height: 34, cornerRadius: 17)
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
            return 134
        case .work:
            return 94
        case .shortBreak:
            return 86
        case .longBreak:
            return 86
        case .overtime:
            return 78
        }
    }
}
