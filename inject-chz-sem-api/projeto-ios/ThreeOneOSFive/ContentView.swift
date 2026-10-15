import SwiftUI
import UIKit

private enum LocalTab: Int, CaseIterable, Identifiable {
    case home, injector, textures
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .home: return "Início"
        case .injector: return "Injetor"
        case .textures: return "Texturas"
        }
    }
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .injector: return "syringe"
        case .textures: return "paintpalette.fill"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @State private var tab: LocalTab = .home
    @State private var showSettings = false
    @State private var showLogs = false

    var body: some View {
        page
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(spacing: 5) {
                    ForEach(LocalTab.allCases) { item in
                        Button { tab = item } label: {
                            VStack(spacing: 5) {
                                Image(systemName: item.icon).font(.system(size: 21, weight: .semibold))
                                Text(item.title).font(.system(size: 11, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .foregroundStyle(tab == item ? Color.red : Color.gray)
                            .background(tab == item ? Color.red.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 14))
                        }.buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(red: 0.055, green: 0.035, blue: 0.04), in: RoundedRectangle(cornerRadius: 19))
                .overlay(RoundedRectangle(cornerRadius: 19).stroke(Color.red.opacity(0.5), lineWidth: 1))
                .padding(.horizontal, 16).padding(.vertical, 6).background(Color.black)
            }
            .tint(.red)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showLogs) { LogView() }
            .patchStorePresentation(patchStore)
            .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
            .onChange(of: patchDraftCoordinator.request?.id) { id in
                if id != nil { tab = .injector }
            }
            .onChange(of: patchDraftCoordinator.importRequest?.id) { id in
                if id != nil { tab = .injector }
            }
    }
    @ViewBuilder
    private var page: some View {
        switch tab {
        case .home: InjectLocalHomeView()
        case .injector:
            PatchProjectsView(onOpenSettings: { showSettings = true }, onOpenLogs: { showLogs = true })
        case .textures:
            LocalCatalogNotice(title: tab.title, onOpenInjector: { tab = .injector })
        }
    }
}

private struct LocalCatalogNotice: View {
    let title: String
    let onOpenInjector: () -> Void
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "folder.fill").font(.system(size: 44)).foregroundStyle(.red)
                Text(title).font(.title.bold()).foregroundStyle(.white)
                Text("Esta versão não integra a API nem consulta o catálogo online. Importe seus arquivos .3105 pela aba Injetor.")
                    .foregroundStyle(.gray).multilineTextAlignment(.center)
                Button("Ir para Injetor", action: onOpenInjector)
                    .buttonStyle(.borderedProminent).tint(.red)
            }.padding(28)
        }
    }
}

private struct InjectLocalHomeView: View {
    @EnvironmentObject private var store: PatchProjectStore
    private let red = Color(red: 0.96, green: 0.12, blue: 0.20)
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.105, green: 0.006, blue: 0.020), .black, .black], startPoint: .topTrailing, endPoint: .bottomLeading).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Image("InjectCHZLogo").resizable().scaledToFit().frame(width: 176, height: 116)
                        .frame(maxWidth: .infinity).padding(.top, 32).padding(.bottom, 14)
                        .accessibilityLabel("inject chz")
                    card {
                        HStack {
                            Text("MODO DE ACESSO").font(.system(size: 12)).tracking(1.5).foregroundStyle(.gray)
                            Spacer()
                            Text("SEM API").font(.system(size: 11, weight: .bold)).foregroundStyle(red)
                        }.padding(.bottom, 16)
                        Text("LOCAL").font(.system(size: 48, weight: .bold)).foregroundStyle(.white)
                        Text("sem login por key").font(.system(size: 14)).foregroundStyle(.gray)
                        Rectangle().fill(red).frame(height: 3).padding(.vertical, 12)
                        Text("Não há licença ou contagem de dias nesta versão.").font(.system(size: 12)).foregroundStyle(.gray)
                    }
                    heading("INFORMAÇÕES DO APLICATIVO")
                    card {
                        row("Produto", "inject chz")
                        Divider()
                        row("Modo", "SEM API")
                        Divider()
                        row("Arquivos locais", String(store.items.count))
                        Divider()
                        row("Importação", ".3105")
                    }
                    heading("DISPOSITIVO")
                    card {
                        row("Modelo", AppInfo.displayMachineName)
                        Divider()
                        row("Versão iOS", "\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                    }
                    Text("Recursos locais preservados. Catálogos e licenças remotos não estão integrados.")
                        .font(.system(size: 12)).foregroundStyle(.gray).multilineTextAlignment(.center)
                }.padding(.horizontal, 16).padding(.bottom, 22)
            }
        }
    }
    private func heading(_ title: String) -> some View {
        Text(title).font(.system(size: 12, weight: .bold)).tracking(1.4).foregroundStyle(.white)
    }
    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 15)).foregroundStyle(.white)
            Spacer(minLength: 12)
            Text(value).font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.72))
        }.padding(.vertical, 14)
    }
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8, content: content)
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(Color(red: 0.075, green: 0.030, blue: 0.039), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(red.opacity(0.55), lineWidth: 1))
    }
}
