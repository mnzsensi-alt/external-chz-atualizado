import SwiftUI
import ImageIO
import UIKit

enum PreviewOptionSelection {
    static let storageKey = "preview.selectedOption"
    static let defaultOption = ""
    private static let emptySelectionMigrationKey = "preview.migration.resetSelectionOnInstall.v1"

    static func resetSavedSelectionOnceForThisVersion() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: emptySelectionMigrationKey) else { return }
        defaults.set(defaultOption, forKey: storageKey)
        defaults.set(true, forKey: emptySelectionMigrationKey)
    }
}

struct LiveDashboardView: View {
    @StateObject private var gameMode = GameModeTransitionState()
    @State private var activationNotice: FeatureActivationNotice?
    @AppStorage(PreviewOptionSelection.storageKey)
    private var selectedPreviewOption = PreviewOptionSelection.defaultOption
    private let accent = Color(red: 1, green: 0.12, blue: 0.19)
    private let cardBackground = Color(red: 0.075, green: 0.075, blue: 0.085)
    private let freeFireFeatures = [
        DashboardFeature(title: "AIMBOT HEAD", description: "aimbot legit para a cabeça"),
        DashboardFeature(title: "HS PESCOÇO", description: "hitbox da cabeça expandida para o pescoço"),
        DashboardFeature(title: "HS ALTO", description: "hitbox da cabeça expandida pra cima"),
        DashboardFeature(title: "CHEST HS", description: "hitbox da cabeça expandida para o peito"),
        DashboardFeature(title: "HS PESCOÇO + ANTENA", description: "hitbox da cabeça expandida para o pescoço + antena")
    ]
    private let freeFireMaxFeatures = [
        DashboardFeature(title: "HS PESCOÇO E ALTO", description: "hitbox da cabeça expandida para o pescoço e pra cima"),
        DashboardFeature(title: "HS PESCOÇO", description: "hitbox da cabeça expandida para o pescoço"),
        DashboardFeature(title: "HS ALTO", description: "hitbox da cabeça expandida pra cima")
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 17) {
                    hero
                    gameSelector
                    featureSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background { LiquidGlassBackdrop() }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(accent)
        .overlay(alignment: .top) {
            if let activationNotice {
                FeatureActivationToast(notice: activationNotice)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
    }

    private var hero: some View {
        AnimatedGIFBanner()
    }

    private var gameSelector: some View {
        GameModeSelector(state: gameMode, accent: accent, cardBackground: cardBackground)
    }

    private var featureSection: some View {
        let visibleCount = max(
            features(for: gameMode.selectedGame).count,
            gameMode.outgoingGame.map { features(for: $0).count } ?? 0
        )
        return GameModeContentTransition(state: gameMode) { mode in
            featureList(for: mode)
        }
        .frame(height: CGFloat(visibleCount * 82 + max(visibleCount - 1, 0) * 9))
    }

    private func features(for mode: Int) -> [DashboardFeature] {
        mode == 0 ? freeFireFeatures : freeFireMaxFeatures
    }

    private func toggleBinding(for mode: Int, index: Int) -> Binding<Bool> {
        let optionID = "function-\(mode)-\(index)"
        return Binding(
            get: { selectedPreviewOption == optionID },
            set: { isOn in
                if isOn {
                    selectedPreviewOption = optionID
                } else if selectedPreviewOption == optionID {
                    selectedPreviewOption = ""
                }
            }
        )
    }

    @ViewBuilder
    private func featureList(for mode: Int) -> some View {
        let modeFeatures = features(for: mode)
        VStack(spacing: 9) {
            ForEach(modeFeatures.indices, id: \.self) { index in
                PreviewFeatureRow(
                    title: modeFeatures[index].title,
                    description: modeFeatures[index].description,
                    isOn: toggleBinding(for: mode, index: index),
                    cardBackground: cardBackground,
                    onToggle: { isActive in
                        showActivationNotice(modeFeatures[index].title, isActive: isActive)
                    }
                )
            }
        }
    }

    private func showActivationNotice(_ title: String, isActive: Bool) {
        let notice = FeatureActivationNotice(title: title, isActive: isActive)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            activationNotice = notice
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            guard activationNotice?.id == notice.id else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                activationNotice = nil
            }
        }
    }
}

private struct DashboardFeature {
    let title: String
    let description: String
}

private final class GameModeTransitionState: ObservableObject {
    @Published private(set) var selectedGame = 0
    @Published private(set) var outgoingGame: Int?
    @Published private(set) var progress: CGFloat = 1
    @Published private(set) var direction: CGFloat = 1
    private var transitionToken = UUID()

    func select(_ game: Int) {
        guard game != selectedGame, outgoingGame == nil else { return }
        let source = selectedGame
        direction = game > source ? 1 : -1
        outgoingGame = source
        selectedGame = game
        progress = 0

        let token = UUID()
        transitionToken = token
        DispatchQueue.main.async {
            guard self.transitionToken == token else { return }
            withAnimation(.easeInOut(duration: 0.34)) {
                self.progress = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                guard self.transitionToken == token else { return }
                self.outgoingGame = nil
            }
        }
    }
}

private struct GameModeContentTransition<Content: View>: View {
    @ObservedObject var state: GameModeTransitionState
    let content: (Int) -> Content

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if let outgoingGame = state.outgoingGame {
                    content(outgoingGame)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                        .offset(x: -state.direction * proxy.size.width * state.progress)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .zIndex(0)
                }

                content(state.selectedGame)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                    .offset(x: state.outgoingGame == nil ? 0 : state.direction * proxy.size.width * (1 - state.progress))
                    .zIndex(1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }
}

private struct GameModeSelector: View {
    @ObservedObject var state: GameModeTransitionState
    let accent: Color
    let cardBackground: Color

    private var selectedGame: Int { state.selectedGame }

    var body: some View {
        HStack(spacing: 0) {
            gameButton("Free Fire", index: 0)
            Rectangle()
                .fill(Color.white.opacity(0.035))
                .frame(width: 1, height: 34)
            gameButton("Free Fire MAX", index: 1)
        }
        .frame(height: 48)
        .background {
            GeometryReader { proxy in
                Capsule()
                    .fill(accent)
                    .frame(width: 30, height: 2.5)
                    .position(
                        x: proxy.size.width * (selectedGame == 0 ? 0.25 : 0.75),
                        y: proxy.size.height - 3
                    )
                    .animation(.easeInOut(duration: 0.34), value: selectedGame)
            }
        }
        .liquidGlassSurface(cornerRadius: 16, tint: accent)
        .disabled(state.outgoingGame != nil)
    }

    private func gameButton(_ title: String, index: Int) -> some View {
        Button {
            state.select(index)
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(selectedGame == index ? accent : Color(white: 0.62))
                .animation(.easeInOut(duration: 0.34), value: selectedGame)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedGame == index ? .isSelected : [])
    }
}

struct AnimatedGIFBanner: View {
    var body: some View {
        GeometryReader { proxy in
            AnimatedGIFView(resourceName: "robot-external")
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        .liquidGlassSurface(cornerRadius: 21, tint: Color(red: 1, green: 0.12, blue: 0.19))
        .accessibilityLabel("Animação do banner")
    }
}

private struct PreviewFeatureRow: View {
    let title: String
    let description: String?
    @Binding var isOn: Bool
    let cardBackground: Color
    let onToggle: (Bool) -> Void

    var body: some View {
        Button {
            let nextState = !isOn
            withAnimation(.spring(response: 0.34, dampingFraction: 0.66)) {
                isOn = nextState
            }
            onToggle(nextState)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    if let description {
                        Text(description)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.07))
                        .overlay {
                            Capsule().fill(isOn ? cardBackground.opacity(0.3) : Color.white.opacity(0.045))
                        }
                        .overlay {
                            Capsule().strokeBorder(Color.white.opacity(0.34), lineWidth: 0.7)
                        }
                        .frame(width: 48, height: 30)
                    Circle()
                        .fill(isOn ? Color.white : Color(white: 0.61))
                        .frame(width: 24, height: 24)
                        .padding(3)
                        .scaleEffect(isOn ? 1.08 : 1)
                        .shadow(color: isOn ? Color.white.opacity(0.28) : .clear, radius: 5)
                }
                .frame(width: 48, height: 30)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, description == nil ? 0 : 11)
            .frame(minHeight: description == nil ? 62 : 82)
            .liquidGlassSurface(
                cornerRadius: 16,
                tint: isOn ? Color(red: 1, green: 0.12, blue: 0.19) : .clear
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "Ligado" : "Desligado")
        .accessibilityHint("Controle apenas visual de prévia")
    }
}

struct FeatureActivationNotice: Identifiable {
    let id = UUID()
    let title: String
    let isActive: Bool
}

struct FeatureActivationToast: View {
    let notice: FeatureActivationNotice

    private var accent: Color {
        notice.isActive ? Color(red: 0.28, green: 0.82, blue: 0.48) : Color(white: 0.72)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notice.isActive ? "checkmark.circle.fill" : "minus.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(notice.title) \(notice.isActive ? "ativado" : "desativado")")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(notice.isActive ? "FUNÇÃO ATIVADA" : "FUNÇÃO DESATIVADA")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(accent)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(accent.opacity(0.34), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.28), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
    }
}

struct AimbotPreviewView: View {
    @AppStorage(PreviewOptionSelection.storageKey)
    private var selectedPreviewOption = PreviewOptionSelection.defaultOption
    @State private var activationNotice: FeatureActivationNotice?

    private let accent = Color(red: 1, green: 0.12, blue: 0.19)
    private let cardBackground = Color(red: 0.075, green: 0.075, blue: 0.085)
    private let options = ["MENU"]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 17) {
                    AnimatedGIFBanner()
                    featureSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background { LiquidGlassBackdrop() }
            .toolbar(.hidden, for: .navigationBar)
        }
        .overlay(alignment: .top) {
            if let activationNotice {
                FeatureActivationToast(notice: activationNotice)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .tint(accent)
    }

    private var featureSection: some View {
        VStack(spacing: 9) {
            ForEach(options.indices, id: \.self) { index in
                PreviewFeatureRow(
                    title: options[index],
                    description: "Painel com silent, ESP, no recoil e etc.",
                    isOn: Binding(
                        get: { selectedPreviewOption == "aimbot-menu" },
                        set: { isOn in
                            selectedPreviewOption = isOn ? "aimbot-menu" : ""
                        }
                    ),
                    cardBackground: cardBackground,
                    onToggle: { isActive in
                        showActivationNotice(options[index], isActive: isActive)
                    }
                )
            }
        }
    }

    private func showActivationNotice(_ title: String, isActive: Bool) {
        let notice = FeatureActivationNotice(title: title, isActive: isActive)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            activationNotice = notice
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            guard activationNotice?.id == notice.id else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                activationNotice = nil
            }
        }
    }
}
struct AnimatedGIFView: UIViewRepresentable {
    let resourceName: String
    @Environment(\.isTabContentActive) private var isTabContentActive

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "gif"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return imageView
        }

        var frames: [UIImage] = []
        var totalDuration: TimeInterval = 0
        let frameCount = CGImageSourceGetCount(source)

        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage))

            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gifProperties = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let unclampedDelay = gifProperties?[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval
            let clampedDelay = gifProperties?[kCGImagePropertyGIFDelayTime] as? TimeInterval
            totalDuration += max(unclampedDelay ?? clampedDelay ?? 0.035, 0.02)
        }

        if frames.count > 1 {
            imageView.animationImages = frames
            imageView.animationDuration = max(totalDuration, 0.1)
            imageView.animationRepeatCount = 0
            if isTabContentActive {
                imageView.startAnimating()
            }
        } else {
            imageView.image = frames.first
        }
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if isTabContentActive,
           !uiView.isAnimating,
           uiView.animationImages?.isEmpty == false {
            uiView.startAnimating()
        } else if !isTabContentActive, uiView.isAnimating {
            uiView.stopAnimating()
        }
    }
}
