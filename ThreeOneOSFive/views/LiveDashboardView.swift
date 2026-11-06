import SwiftUI
import ImageIO
import UIKit

struct LiveDashboardView: View {
    @StateObject private var gameMode = GameModeTransitionState()
    @State private var freeFireToggles = [false, true, true, false, false]
    @State private var freeFireMaxToggles = [false, true, true]
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
        mode == 0 ? $freeFireToggles[index] : $freeFireMaxToggles[index]
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
                    cardBackground: cardBackground
                )
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

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
                isOn.toggle()
            }
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
                }
                .frame(width: 48, height: 30)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, description == nil ? 0 : 11)
            .frame(minHeight: description == nil ? 62 : 82)
            .liquidGlassSurface(cornerRadius: 16, tint: Color(red: 1, green: 0.12, blue: 0.19))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "Ligado" : "Desligado")
        .accessibilityHint("Controle apenas visual de prévia")
    }
}


struct AimbotPreviewView: View {
    @State private var previewToggles = [false]

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
        .tint(accent)
    }

    private var featureSection: some View {
        VStack(spacing: 9) {
            ForEach(options.indices, id: \.self) { index in
                PreviewFeatureRow(
                    title: options[index],
                    description: "Painel com silent, ESP, no recoil e etc.",
                    isOn: $previewToggles[index],
                    cardBackground: cardBackground
                )
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
