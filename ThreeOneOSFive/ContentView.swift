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
    @State private var tabSlideDirection: TabSlideDirection = .forward
    @State private var tabTransitionProgress: CGFloat = 1
    @State private var tabTransitionToken = UUID()
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
            if requestID != nil { selectTab(AppSection.installed.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { selectTab(AppSection.installed.rawValue) }
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
        GeometryReader { geometry in
            TabView(selection: tabSelection) {
                ForEach(featureVisibility.visibleSections) { section in
                    sectionContent(
                        section,
                        transitionProgress: tabTransitionProgress,
                        slideDirection: tabSlideDirection == .forward ? 1 : -1,
                        transitionWidth: geometry.size.width,
                        isSelected: section.rawValue == tabNavigation.selectedTab
                    )
                    .tabItem {
                        CompactTabLabel(
                            title: section.displayTitle(language: language),
                            systemImage: section.systemImage,
                            isReticle: section == .installed,
                            isProfile: section == .deviceInfo
                        )
                    }
                    .tag(section.rawValue)
                }
            }
            .toolbarBackground(.hidden, for: .tabBar)
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        selectTab(section.rawValue)
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
            sectionContent(
                selectedVisibleSection,
                transitionProgress: tabTransitionProgress,
                slideDirection: tabSlideDirection == .forward ? 1 : -1,
                transitionWidth: 500,
                isSelected: true
            )
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(
        _ section: AppSection,
        transitionProgress: CGFloat = 1,
        slideDirection: CGFloat = 1,
        transitionWidth: CGFloat = 0,
        isSelected: Bool = true
    ) -> some View {
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
            AvatarCacheTabView(
                groupIndex: 0,
                transitionProgress: transitionProgress,
                slideDirection: slideDirection,
                transitionWidth: transitionWidth,
                isSelected: isSelected
            )
        case .patchesSecond:
            AvatarCacheTabView(
                groupIndex: 1,
                transitionProgress: transitionProgress,
                slideDirection: slideDirection,
                transitionWidth: transitionWidth,
                isSelected: isSelected
            )
        case .deviceInfo:
            LiquidGlassDeviceInfoTabView(
                transitionProgress: transitionProgress,
                slideDirection: slideDirection,
                transitionWidth: transitionWidth,
                isSelected: isSelected
            )
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

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { selectTab($0) }
        )
    }

    private func selectTab(_ selectedTab: Int) {
        guard selectedTab != tabNavigation.selectedTab else { return }
        let sections = featureVisibility.visibleSections
        let currentIndex = sections.firstIndex { $0.rawValue == tabNavigation.selectedTab } ?? 0
        let nextIndex = sections.firstIndex { $0.rawValue == selectedTab } ?? currentIndex
        tabSlideDirection = nextIndex >= currentIndex ? .forward : .backward

        let token = UUID()
        tabTransitionToken = token
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            tabTransitionProgress = 0
            tabNavigation.select(selectedTab)
        }

        DispatchQueue.main.async {
            guard tabTransitionToken == token else { return }
            withAnimation(.easeInOut(duration: 0.272)) {
                tabTransitionProgress = 1
            }
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

private enum TabSlideDirection {
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
        if isReticle {
            Image(uiImage: ReticleTabIconImage.image)
        } else if isProfile {
            ProfileTabIcon()
        } else if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
            .font(.system(size: 10, weight: .black, design: .rounded))
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
