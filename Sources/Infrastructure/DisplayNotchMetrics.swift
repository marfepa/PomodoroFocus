import AppKit

/// Resuelve la geometría física del notch de Apple Silicon o calcula el marco de fallback para pantallas externas.
public struct DisplayNotchMetrics: Sendable {
    public let frame: CGRect
    public let hasHardwareNotch: Bool
    public let screenFrame: CGRect

    public init(frame: CGRect, hasHardwareNotch: Bool, screenFrame: CGRect) {
        self.frame = frame
        self.hasHardwareNotch = hasHardwareNotch
        self.screenFrame = screenFrame
    }

    /// Determina las dimensiones físicas del notch en la pantalla indicada.
    public static func resolve(for screen: NSScreen = NSScreen.main ?? NSScreen.screens.first!) -> DisplayNotchMetrics {
        let topInset = screen.safeAreaInsets.top
        let screenHeight = screen.frame.height

        if topInset > 0,
           let leftUnobscured = screen.auxiliaryTopLeftArea,
           let rightUnobscured = screen.auxiliaryTopRightArea {
            
            let notchX = leftUnobscured.maxX
            let notchWidth = rightUnobscured.minX - leftUnobscured.maxX
            let notchHeight = topInset

            // En AppKit las coordenadas Y comienzan en la parte inferior de la pantalla.
            let notchRect = CGRect(
                x: notchX,
                y: screenHeight - notchHeight,
                width: notchWidth,
                height: notchHeight
            )
            return DisplayNotchMetrics(frame: notchRect, hasHardwareNotch: true, screenFrame: screen.frame)
        }

        // Modo de compatibilidad para monitores externos, iMac o Mac mini
        let fallbackWidth: CGFloat = 210.0
        let fallbackHeight: CGFloat = 32.0
        let fallbackRect = CGRect(
            x: (screen.frame.width - fallbackWidth) / 2.0,
            y: screenHeight - fallbackHeight - 6.0,
            width: fallbackWidth,
            height: fallbackHeight
        )
        return DisplayNotchMetrics(frame: fallbackRect, hasHardwareNotch: false, screenFrame: screen.frame)
    }
}
