import SwiftUI

enum AppAppearance {
    static let darkModeStorageKey = "app.appearance.darkMode"
}

enum AppTheme {
    static let accent = Color(uiColor: .label)
    static let pageBackground = Color(uiColor: .systemBackground)
    static let consoleBackground = Color(uiColor: .secondarySystemBackground)
    static let liquidGlassAccent = Color(red: 1, green: 0.12, blue: 0.19)
    static let liquidGlassEdge = Color.white.opacity(0.36)
    static let liquidGlassFill = Color.white.opacity(0.055)
    static let pageInset: CGFloat = 16
    static let rowIconSize: CGFloat = 17
    static let rowIconFrame: CGFloat = 28
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 30
    static let fileRowHeight: CGFloat = 60
    static let appIconSize: CGFloat = 32
    static let emptyIconSize: CGFloat = 30
    static let selectionIconSize: CGFloat = 18
    static let contentCardCornerRadius: CGFloat = 20
    static let contentCardInset: CGFloat = 16
    static let contentCardPadding: CGFloat = 16
}

struct AppCardBorder: View {
    var body: some View {
        RoundedRectangle(
            cornerRadius: AppTheme.contentCardCornerRadius,
            style: .continuous
        )
        .strokeBorder(
            LinearGradient(
                colors: [AppTheme.liquidGlassEdge, Color.white.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 0.7
        )
        .accessibilityHidden(true)
    }
}

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(tint.opacity(0.12))
                }
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: frameSize, height: frameSize)
        .accessibilityHidden(true)
    }
}

struct AppSearchField: View {
    @Binding var text: String
    let prompt: String
    let clearLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 36)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(AppTheme.liquidGlassEdge.opacity(0.52), lineWidth: 0.6)
        }
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let icon = UIImage(named: "AppIcon60x60")
                ?? Bundle.main.path(forResource: "AppIcon60x60@2x", ofType: "png").flatMap(UIImage.init(contentsOfFile:))
                ?? UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct DashboardToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.66)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.07))
                    .overlay {
                        Capsule().fill(configuration.isOn ? AppTheme.liquidGlassAccent.opacity(0.34) : Color.white.opacity(0.055))
                    }
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(0.34), lineWidth: 0.7)
                    }
                    .frame(width: 48, height: 30)
                Circle()
                    .fill(configuration.isOn ? Color.white : Color(white: 0.61))
                    .frame(width: 24, height: 24)
                    .padding(3)
                    .scaleEffect(configuration.isOn ? 1.08 : 1)
                    .shadow(
                        color: configuration.isOn ? Color.white.opacity(0.28) : .clear,
                        radius: 5
                    )
            }
            .frame(width: 48, height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "Ligado" : "Desligado")
        .accessibilityAddTraits(.isButton)
    }
}


struct LiquidGlassBackdrop: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            LinearGradient(
                colors: [
                    AppTheme.liquidGlassAccent.opacity(0.11),
                    Color.clear,
                    Color.cyan.opacity(0.035)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct LiquidGlassSurface: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.contentCardCornerRadius
    var tint: Color = .clear

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                ZStack {
                    if cornerRadius >= 19 {
                        shape.fill(.ultraThinMaterial)
                    } else {
                        shape.fill(Color.white.opacity(0.045))
                    }
                    shape.fill(AppTheme.liquidGlassFill)
                    shape.fill(tint.opacity(0.06))
                    shape.fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .overlay {
                shape.strokeBorder(Color.white.opacity(0.22), lineWidth: 0.65)
            }
    }
}

extension View {
    func liquidGlassSurface(
        cornerRadius: CGFloat = AppTheme.contentCardCornerRadius,
        tint: Color = .clear
    ) -> some View {
        modifier(LiquidGlassSurface(cornerRadius: cornerRadius, tint: tint))
    }
}

private struct TabContentActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var isTabContentActive: Bool {
        get { self[TabContentActiveKey.self] }
        set { self[TabContentActiveKey.self] = newValue }
    }
}
