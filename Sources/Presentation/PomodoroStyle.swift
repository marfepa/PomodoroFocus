import SwiftUI

/// Botón común de la isla y la ventana: mismo radio y tipografía, hover visible y respuesta al pulsar.
public struct PomodoroButtonStyle: ButtonStyle {
    public enum Kind {
        case primary(Color)
        case secondary
        case destructive
    }

    public enum Size {
        case compact
        case regular
        case icon
    }

    private let kind: Kind
    private let size: Size

    public init(_ kind: Kind = .secondary, size: Size = .compact) {
        self.kind = kind
        self.size = size
    }

    public func makeBody(configuration: Configuration) -> some View {
        StyledButtonBody(configuration: configuration, kind: kind, size: size)
    }
}

private struct StyledButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: PomodoroButtonStyle.Kind
    let size: PomodoroButtonStyle.Size

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .brightness(isHovered && !configuration.isPressed ? 0.06 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onHover { isHovered = $0 }
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var fontSize: CGFloat {
        size == .regular ? 13 : 10.5
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .compact: return 8
        case .regular: return 16
        case .icon: return 5
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .compact, .icon: return 5
        case .regular: return 10
        }
    }

    private var cornerRadius: CGFloat {
        size == .regular ? 8 : 6
    }

    private var foreground: Color {
        switch kind {
        case .primary: return .black
        case .secondary: return .primary
        case .destructive: return .red
        }
    }

    private var background: Color {
        switch kind {
        case .primary(let color): return color
        case .secondary: return Color.primary.opacity(isHovered ? 0.16 : 0.1)
        case .destructive: return Color.red.opacity(isHovered ? 0.22 : 0.15)
        }
    }
}

extension ButtonStyle where Self == PomodoroButtonStyle {
    static func pomodoro(_ kind: PomodoroButtonStyle.Kind = .secondary, size: PomodoroButtonStyle.Size = .compact) -> PomodoroButtonStyle {
        PomodoroButtonStyle(kind, size: size)
    }
}

/// Dígitos que ruedan al cambiar cada segundo, en lugar de sustituirse de golpe.
private struct RollingDigits: ViewModifier {
    let seconds: TimeInterval
    let countsDown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .monospacedDigit()
            .contentTransition(reduceMotion ? .identity : .numericText(countsDown: countsDown))
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: Int(seconds))
    }
}

extension View {
    func rollingDigits(_ seconds: TimeInterval, countsDown: Bool = true) -> some View {
        modifier(RollingDigits(seconds: seconds, countsDown: countsDown))
    }
}
