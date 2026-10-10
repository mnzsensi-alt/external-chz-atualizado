import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage(FeatureVisibility.developerModeStorageKey)
    private var developerModeEnabled = false
    @AppStorage(AppAppearance.darkModeStorageKey)
    private var darkModeEnabled = true
    @State private var tabNavigation: AppTabNavigationState
    @State private var compactSlideDirection: CompactTabSlideDirection = .forward
    @State private var showSettings = false
    @State private var showLogs = false

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-new-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-sources-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-installed-tab")
                    || arguments.contains("--simulate-patch-tab")
                    || arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-files-tab") {
            initialTab = 4
        } else if arguments.contains("--simulate-search-tab") {
            initialTab = 5
        } else {
            initialTab = AppSection.installed.rawValue
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
        _showSettings = State(
            initialValue: arguments.contains("--simulate-settings")
        )
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.installed.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.installed.rawValue) }
        }
        .onChange(of: developerModeEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onAppear {
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLogs) { LogView() }
        .patchStorePresentation(patchStore)
        .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
    }

    private var compactLayout: some View {
        ZStack {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
                .transition(compactTabTransition)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .animation(.easeInOut(duration: 0.28), value: tabNavigation.selectedTab)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            compactTabBar
        }
    }

    private var compactTabBar: some View {
        HStack(spacing: 0) {
            ForEach(featureVisibility.visibleSections) { section in
                let isSelected = section.rawValue == tabNavigation.selectedTab
                Button {
                    selectCompactTab(section)
                } label: {
                    CompactTabLabel(
                        title: section.displayTitle(language: language),
                        systemImage: section.systemImage,
                        isReticle: section == .installed,
                        isProfile: section == .deviceInfo
                    )
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.displayTitle(language: language))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 5)
        .padding(.top, 3)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(height: 0.5)
        }
    }

    private var compactTabTransition: AnyTransition {
        switch compactSlideDirection {
        case .forward:
            return .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
        case .backward:
            return .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
        }
    }

    private func selectCompactTab(_ section: AppSection) {
        let sections = featureVisibility.visibleSections
        let currentIndex = sections.firstIndex { $0.rawValue == tabNavigation.selectedTab } ?? 0
        let nextIndex = sections.firstIndex(of: section) ?? currentIndex
        guard nextIndex != currentIndex else { return }
        compactSlideDirection = nextIndex > currentIndex ? .forward : .backward
        withAnimation(.easeInOut(duration: 0.28)) {
            tabNavigation.select(section.rawValue)
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label {
                            Text(section.displayTitle(language: language))
                        } icon: {
                            if section == .installed {
                                Image(uiImage: ReticleTabIconImage.image)
                            } else if section == .deviceInfo {
                                ProfileTabIcon()
                            } else {
                                Image(systemName: section.systemImage)
                            }
                        }
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .navigationTitle("3105")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
                .transition(.move(edge: .trailing))
                .animation(.easeInOut(duration: 0.28), value: tabNavigation.selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            RepositoryHomeView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .new:
            RepositoryNewView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .sources:
            RepositorySourcesView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .installed:
            AvatarCacheTabView(groupIndex: 0)
        case .patchesSecond:
            AvatarCacheTabView(groupIndex: 1)
        case .deviceInfo:
            LiquidGlassDeviceInfoTabView()
        case .files:
            AppDataBrowserView(
                tabSession: filesTabSession,
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .search:
            RepositorySearchView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        }
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(developerModeEnabled: developerModeActive)
    }

    private var developerModeActive: Bool {
#if targetEnvironment(simulator)
        developerModeEnabled
            || ProcessInfo.processInfo.arguments.contains("--simulate-developer-mode")
            || ProcessInfo.processInfo.arguments.contains("--simulate-files-tab")
#else
        developerModeEnabled
#endif
    }

    private var selectedVisibleSection: AppSection {
        guard let selection = AppSection(rawValue: tabNavigation.selectedTab),
              featureVisibility.visibleSections.contains(selection) else {
            return .installed
        }
        return selection
    }

    private func openSettings() {
        showSettings = true
    }

    private func openLogs() {
        showLogs = true
    }
}

private enum CompactTabSlideDirection {
    case forward
    case backward
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String
    let isReticle: Bool
    let isProfile: Bool

    @ViewBuilder
    var body: some View {
        VStack(spacing: 4) {
            Group {
                if isReticle {
                    Image(uiImage: ReticleTabIconImage.image)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                } else if isProfile {
                    ProfileTabIcon()
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .medium))
                }
            }
            .frame(width: 23, height: 23)

            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct ProfileTabIcon: View {
    var body: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 12, weight: .black))
            .foregroundStyle(Color.black)
            .frame(width: 23, height: 23)
            .background(Circle().fill(Color.white))
            .accessibilityHidden(true)
    }
}

private enum ReticleTabIconImage {
    static let image: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        let rendered = renderer.image { _ in
            UIColor.white.setStroke()
            let ring = UIBezierPath(ovalIn: CGRect(x: 3.5, y: 3.5, width: 17, height: 17))
            ring.lineWidth = 2.0
            ring.stroke()

            let marks = UIBezierPath()
            marks.move(to: CGPoint(x: 12, y: 0.8))
            marks.addLine(to: CGPoint(x: 12, y: 2.3))
            marks.move(to: CGPoint(x: 12, y: 21.7))
            marks.addLine(to: CGPoint(x: 12, y: 23.2))
            marks.move(to: CGPoint(x: 0.8, y: 12))
            marks.addLine(to: CGPoint(x: 2.3, y: 12))
            marks.move(to: CGPoint(x: 21.7, y: 12))
            marks.addLine(to: CGPoint(x: 23.2, y: 12))
            marks.lineWidth = 1.7
            marks.lineCapStyle = .round
            marks.stroke()

            let innerRing = UIBezierPath(ovalIn: CGRect(x: 8.4, y: 8.4, width: 7.2, height: 7.2))
            innerRing.lineWidth = 1.4
            innerRing.stroke()

            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 11.15, y: 11.15, width: 1.7, height: 1.7)).fill()
        }
        return rendered.withRenderingMode(.alwaysTemplate)
    }()
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .new: return "tab.new"
        case .sources: return "tab.sources"
        case .installed: return "tab.installed"
        case .files: return "tab.files"
        case .search: return "tab.search"
        case .patchesSecond: return "tab.installed"
        case .deviceInfo: return "common.device"
        }
    }

    func displayTitle(language: AppLanguage) -> String {
        switch self {
        case .installed: return "AVATAR"
        case .patchesSecond: return "CACHE"
        case .deviceInfo: return "PERFIL"
        default: return language.text(titleKey)
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .new: return "clock.fill"
        case .sources: return "shippingbox.fill"
        case .installed: return "viewfinder"
        case .files: return "folder.fill"
        case .search: return "magnifyingglass"
        case .patchesSecond: return "externaldrive.fill"
        case .deviceInfo: return "person.fill"
        }
    }
}
