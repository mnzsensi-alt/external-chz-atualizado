import SwiftUI
import UIKit

struct LiveDashboardView: View {
    @AppStorage(AppAppearance.darkModeStorageKey) private var darkModeEnabled = true
    @AppStorage(FeatureVisibility.developerModeStorageKey) private var developerModeEnabled = false
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    @State private var selectedTab = 0

    private let accent = Color(red: 1, green: 0.12, blue: 0.19)
    private let background = Color(red: 0.025, green: 0.025, blue: 0.03)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    hero
                    tabSelector
                    if selectedTab == 0 {
                        overviewSections
                    } else {
                        preferencesSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(accent)
    }

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { proxy in
                if let artwork = UIImage(named: "AppIcon") {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .overlay(Color.black.opacity(0.57))
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.24, green: 0.035, blue: 0.055), .black],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                }
            }
            LinearGradient(
                colors: [.black.opacity(0.1), .black.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Circle().fill(accent).frame(width: 7, height: 7)
                    Text("LIVE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 36)
                Text("CONTROLE\nDO DISPOSITIVO")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .tracking(-0.7)
                    .lineSpacing(-2)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .frame(height: 208)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var tabSelector: some View {
        HStack(spacing: 28) {
            tabButton("VISÃO GERAL", index: 0)
            tabButton("PREFERÊNCIAS", index: 1)
            Spacer(minLength: 0)
        }
        .padding(.top, -8)
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedTab = index }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(selectedTab == index ? accent : Color(white: 0.65))
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTab == index ? .isSelected : [])
    }

    private var overviewSections: some View {
        VStack(alignment: .leading, spacing: 27) {
            section(title: "DISPOSITIVO", rows: [
                SettingRow(title: "Modo desenvolvedor", isOn: $developerModeEnabled),
                SettingRow(title: "Ferramentas de limpeza", isOn: $cleanerEnabled)
            ])
            section(title: "APARÊNCIA", rows: [
                SettingRow(title: "Modo escuro", isOn: $darkModeEnabled)
            ])
        }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 27) {
            section(title: "INTERFACE", rows: [
                SettingRow(title: "Modo escuro", isOn: $darkModeEnabled)
            ])
            section(title: "FERRAMENTAS", rows: [
                SettingRow(title: "Modo desenvolvedor", isOn: $developerModeEnabled),
                SettingRow(title: "Ferramentas de limpeza", isOn: $cleanerEnabled)
            ])
        }
    }

    private func section(title: String, rows: [SettingRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(accent)
                .padding(.bottom, 3)
            ForEach(rows) { row in
                row
            }
        }
    }
}

private struct SettingRow: View, Identifiable {
    let id = UUID()
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundStyle(.white)
                Spacer(minLength: 12)
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? Color.white.opacity(0.2) : Color(white: 0.32))
                        .frame(width: 46, height: 27)
                    Circle()
                        .fill(isOn ? Color.white : Color(white: 0.68))
                        .frame(width: 21, height: 21)
                        .padding(3)
                }
                .frame(width: 46, height: 27)
                .accessibilityHidden(true)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "Ligado" : "Desligado")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Toque duas vezes para alternar")
    }
}
