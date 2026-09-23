import SwiftUI

/// Silueta de la isla. Con notch físico el borde superior es recto y se funde con el bisel mediante
/// dos orejas cóncavas; sin notch (`earRadius == 0`) es una cápsula flotante.
struct IslandShape: Shape {
    var earRadius: CGFloat
    var cornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(earRadius, cornerRadius) }
        set {
            earRadius = newValue.first
            cornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        guard earRadius > 0 else {
            return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
        }

        let ear = min(earRadius, rect.width / 4, rect.height / 2)
        let bodyMinX = rect.minX + ear
        let bodyMaxX = rect.maxX - ear
        let radius = min(cornerRadius, (bodyMaxX - bodyMinX) / 2, rect.height - ear)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: bodyMaxX, y: rect.minY + ear),
            control: CGPoint(x: bodyMaxX, y: rect.minY)
        )
        path.addArc(
            tangent1End: CGPoint(x: bodyMaxX, y: rect.maxY),
            tangent2End: CGPoint(x: bodyMinX, y: rect.maxY),
            radius: radius
        )
        path.addArc(
            tangent1End: CGPoint(x: bodyMinX, y: rect.maxY),
            tangent2End: CGPoint(x: bodyMinX, y: rect.minY + ear),
            radius: radius
        )
        path.addLine(to: CGPoint(x: bodyMinX, y: rect.minY + ear))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: bodyMinX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
