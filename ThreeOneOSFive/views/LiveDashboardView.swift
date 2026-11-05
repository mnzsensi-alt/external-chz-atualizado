import SwiftUI
import ImageIO
import UIKit

struct LiveDashboardView: View {
    @State private var selectedGame = 0
    @State private var previewFeatures = [false, true, true, false, false]

    private let accent = Color(red: 1, green: 0.12, blue: 0.19)
    private let pageBackground = Color(red: 0.025, green: 0.025, blue: 0.03)
    private let cardBackground = Color(red: 0.075, green: 0.075, blue: 0.085)
    private let features = ["BODY HS", "NECK HS", "DRAG HS", "CHEST HS", "MAGIC BULLET"]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 17) {
                    hero
                    gameSelector
                    featureSection
                    Text("VIP MODS")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(accent)
                        .padding(.top, 1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(pageBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(accent)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { proxy in
                AnimatedGIFView(resourceName: "robot-external")
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            LinearGradient(
                colors: [.black.opacity(0.04), .black.opacity(0.58)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.white)
                        .frame(width: 7, height: 7)
                    Text("LIVE")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(accent, in: Capsule())

                Spacer()

                Text("ROBOT EXTERNAL")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .tracking(0.2)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(16)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var gameSelector: some View {
        HStack(spacing: 0) {
            gameButton("Free Fire", index: 0)
            Rectangle()
                .fill(Color.white.opacity(0.035))
                .frame(width: 1, height: 34)
            gameButton("Free Fire MAX", index: 1)
        }
        .frame(height: 48)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func gameButton(_ title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) { selectedGame = index }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(selectedGame == index ? accent : Color(white: 0.62))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedGame == index ? .isSelected : [])
    }

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("BRUTAL FEATURES")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(accent)
                .padding(.horizontal, 4)
                .padding(.bottom, 1)

            ForEach(features.indices, id: \.self) { index in
                PreviewFeatureRow(
                    title: features[index],
                    isOn: $previewFeatures[index],
                    cardBackground: cardBackground
                )
            }
        }
    }
}

private struct PreviewFeatureRow: View {
    let title: String
    @Binding var isOn: Bool
    let cardBackground: Color

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 10)
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(Color(red: 0.11, green: 0.11, blue: 0.13))
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
            .frame(height: 62)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
    @State private var selectedGame = 0
    @State private var previewToggles = [false, false, false, false, false, true]

    private let accent = Color(red: 1, green: 0.12, blue: 0.19)
    private let pageBackground = Color(red: 0.025, green: 0.025, blue: 0.03)
    private let cardBackground = Color(red: 0.075, green: 0.075, blue: 0.085)
    private let options = [
        "MENU",
        "ONLY ESP",
        "VIP MOD MENU",
        "AIM SILENT + ESP",
        "AIMBOT+ESP ALL +144 FPS",
        "AIMBOT"
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                gameSelector

                VStack(alignment: .leading, spacing: 10) {
                    Text("ESP")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 4)

                    VStack(spacing: 9) {
                        ForEach(options.indices, id: \.self) { index in
                            PreviewFeatureRow(
                                title: options[index],
                                isOn: $previewToggles[index],
                                cardBackground: cardBackground
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 22)
            .padding(.bottom, 24)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(pageBackground.ignoresSafeArea())
        .tint(accent)
    }

    private var gameSelector: some View {
        HStack(spacing: 0) {
            gameButton("Free Fire", index: 0)
            Rectangle()
                .fill(Color.white.opacity(0.035))
                .frame(width: 1, height: 34)
            gameButton("Free Fire MAX", index: 1)
        }
        .frame(height: 48)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func gameButton(_ title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) { selectedGame = index }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(selectedGame == index ? accent : Color(white: 0.62))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedGame == index ? .isSelected : [])
    }
}


private struct AnimatedGIFView: UIViewRepresentable {
    let resourceName: String

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
            imageView.startAnimating()
        } else {
            imageView.image = frames.first
        }
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if !uiView.isAnimating, uiView.animationImages?.isEmpty == false {
            uiView.startAnimating()
        }
    }
}
