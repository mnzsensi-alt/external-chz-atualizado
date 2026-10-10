import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum PatchPackagePickerPolicy {
    static let packageType = UTType(filenameExtension: "3105") ?? .data
    static let allowedContentTypes: [UTType] = [packageType, .data]
    static let copiesSelectedDocument = true
}

private enum WallpaperPackagePickerPolicy {
    static let packageType = UTType(filenameExtension: "tendies") ?? .data
    static let allowedContentTypes: [UTType] = [packageType, .data]
}

private struct PendingBundledPatchAction: Identifiable {
    let option: BundledPatchOption
    let itemID: UUID
    let activate: Bool

    var id: String { "\(itemID.uuidString)-\(activate)" }
}

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var store: PatchProjectStore
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    @State private var showCreate = false
    @State private var showImporter = false
    @State private var showWallpaperImporter = false
    @State private var selectedBundledTab = 0
    @State private var pendingBundledAction: PendingBundledPatchAction?
    @State private var showCleaner = false
    @State private var searchText = ""
    @State private var wallpaperPackages: [WallpaperStagedPackage] = []
    @State private var wallpaperImportFeedback: WallpaperImportFeedback?
    @State private var wallpaperPendingDeletion: WallpaperStagedPackage?
    @State private var isImportingWallpapers = false
    @State private var showSimulatedWallpaperDetail = false
    @State private var simulatedWallpaperDetailGate = OneShotPresentationGate()
    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    private var filteredItems: [PatchLibraryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let userItems = store.items.filter { !store.isBundledPatch($0.id) }
        guard !query.isEmpty else { return userItems }
        return userItems.filter { item in
            if item.packageURL.lastPathComponent.localizedCaseInsensitiveContains(query) {
                return true
            }
            guard let project = item.project else { return false }
            if project.name.localizedCaseInsensitiveContains(query)
                || project.author.localizedCaseInsensitiveContains(query) {
                return true
            }
            guard item.canInspectContents else { return false }
            return project.allBundleIdentifiers.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
                || project.directories.contains {
                    $0.relativePath.localizedCaseInsensitiveContains(query)
                }
                || project.rules.contains {
                    $0.relativePath.localizedCaseInsensitiveContains(query)
                        || $0.replacementFilename.localizedCaseInsensitiveContains(query)
                }
        }
    }

    private var filteredWallpaperPackages: [WallpaperStagedPackage] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return wallpaperPackages }
        return wallpaperPackages.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    private var visibleBundledOptions: [BundledPatchOption] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return BundledPatchCatalog.options.filter { option in
            option.tabIndex == selectedBundledTab
                && (query.isEmpty
                    || option.filename.localizedCaseInsensitiveContains(query)
                    || "Opção \(option.number)".localizedCaseInsensitiveContains(query))
        }
    }

    private var hasLocalContent: Bool {
        !store.items.isEmpty || !wallpaperPackages.isEmpty
    }

    private var hasSearchResults: Bool {
        !filteredItems.isEmpty
            || !filteredWallpaperPackages.isEmpty
            || !visibleBundledOptions.isEmpty
    }

    init(
        onOpenSettings: @escaping () -> Void = {},
        onOpenLogs: @escaping () -> Void = {}
    ) {
        self.onOpenSettings = onOpenSettings
        self.onOpenLogs = onOpenLogs
#if targetEnvironment(simulator)
        _showCreate = State(
            initialValue: ProcessInfo.processInfo.arguments.contains("--simulate-patch-editor")
        )
#endif
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppSearchField(
                    text: $searchText,
                    prompt: language.text("installed.search"),
                    clearLabel: language.text("common.clear")
                )
                Divider()
                List {
                    listRows
                }
                .listStyle(.insetGrouped)
                .sheet(isPresented: $showCreate) {
                    PatchProjectEditorView(
                        existingProject: nil,
                        passwordIsProtected: false
                    ) { project, password in
                        store.create(project: project, password: password)
                    }
                }
            }
            .navigationTitle(language.text("tab.installed"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showCreate = true
                        } label: {
                            Label(language.text("patch.new"), systemImage: "doc.badge.plus")
                        }
                        Button {
                            showImporter = true
                        } label: {
                            Label(language.text("patch.import"), systemImage: "square.and.arrow.down")
                        }
                        Button {
                            showWallpaperImporter = true
                        } label: {
                            Label(
                                language.text("wallpaper.import"),
                                systemImage: "photo.badge.plus"
                            )
                        }
                    } label: {
                        if store.isBusy || isImportingWallpapers {
                            ProgressView()
                        } else {
                            Image(systemName: "plus")
                        }
                    }
                    .disabled(store.isBusy || isImportingWallpapers)
                    .accessibilityLabel(language.text("patch.add"))
                }
                AppUtilityToolbar(
                    language: language,
                    onOpenSettings: onOpenSettings,
                    onOpenLogs: onOpenLogs
                )
            }
            .sheet(isPresented: $showImporter) {
                FileDocumentPicker(
                    allowedContentTypes: PatchPackagePickerPolicy.allowedContentTypes,
                    copiesSelectedDocument: PatchPackagePickerPolicy.copiesSelectedDocument,
                    allowsMultipleSelection: false,
                    onSelection: { result in
                        showImporter = false
                        if case .success(let urls) = result, let url = urls.first {
                            store.importPackage(at: url)
                        }
                    },
                    onCancel: {
                        showImporter = false
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showCleaner) {
                CleanerView()
            }
            .sheet(item: $draftCoordinator.request) { request in
                PatchProjectEditorView(
                    existingProject: nil,
                    passwordIsProtected: false,
                    initialDraft: request.draft
                ) { project, password in
                    store.create(project: project, password: password)
                    draftCoordinator.clear()
                }
            }
            .sheet(isPresented: $showWallpaperImporter) {
                FileDocumentPicker(
                    allowedContentTypes: WallpaperPackagePickerPolicy.allowedContentTypes,
                    copiesSelectedDocument: true,
                    allowsMultipleSelection: true,
                    onSelection: { result in
                        showWallpaperImporter = false
                        if case .success(let urls) = result, !urls.isEmpty {
                            importWallpaperPackages(urls)
                        }
                    },
                    onCancel: {
                        showWallpaperImporter = false
                    }
                )
                .ignoresSafeArea()
            }
            .alert(item: $wallpaperImportFeedback) { feedback in
                Alert(
                    title: Text(language.text(feedback.titleKey)),
                    message: Text(feedback.message),
                    dismissButton: .default(Text(language.text("common.ok")))
                )
            }
            .alert(item: $wallpaperPendingDeletion) { package in
                Alert(
                    title: Text(language.text("wallpaper.delete_title")),
                    message: Text(language.text(
                        "wallpaper.delete_message",
                        package.displayName
                    )),
                    primaryButton: .destructive(
                        Text(language.text("common.delete"))
                    ) {
                        deleteWallpaperPackage(package)
                    },
                    secondaryButton: .cancel(Text(language.text("common.cancel")))
                )
            }
            .onAppear {
                reloadWallpaperPackages()
                consumeExternalImport()
#if targetEnvironment(simulator)
                if ProcessInfo.processInfo.arguments.contains(
                    "--simulate-wallpaper-detail"
                ), !wallpaperPackages.isEmpty,
                   simulatedWallpaperDetailGate.claim() {
                    DispatchQueue.main.async {
                        showSimulatedWallpaperDetail = true
                    }
                }
#endif
            }
            .navigationDestination(isPresented: $showSimulatedWallpaperDetail) {
                if let package = wallpaperPackages.first {
                    InstalledWallpaperPackageDetailView(
                        package: package,
                        onApplied: reloadWallpaperPackages
                    )
                }
            }
            .onChange(of: draftCoordinator.importRequest?.id) { _ in
                consumeExternalImport()
            }
            .confirmationDialog(
                pendingBundledAction?.activate == true
                    ? "Ativar patch?"
                    : "Desativar patch?",
                isPresented: Binding(
                    get: { pendingBundledAction != nil },
                    set: { if !$0 { pendingBundledAction = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let action = pendingBundledAction {
                    Button(
                        action.activate ? "Ativar" : "Desativar",
                        role: action.activate ? nil : .destructive
                    ) {
                        store.setBundledPatch(action.itemID, active: action.activate)
                        pendingBundledAction = nil
                    }
                    Button("Cancelar", role: .cancel) {
                        pendingBundledAction = nil
                    }
                }
            } message: {
                if let action = pendingBundledAction {
                    Text(action.activate
                        ? "Ativar \(action.option.filename). Outra opção pré-instalada ativa será desativada primeiro."
                        : "Desativar \(action.option.filename) e restaurar o arquivo original.")
                }
            }
        }
    }

    @ViewBuilder
    private var listRows: some View {
        bundledPatchTabSection
        bundledPatchOptionsSection
        if !hasLocalContent && (store.isBusy || isImportingWallpapers) {
            loadingState
                .listRowSeparator(.hidden)
        } else if !hasLocalContent {
            emptyState
                .listRowSeparator(.hidden)
        } else if !hasSearchResults && !store.isBusy {
            searchEmptyState
                .listRowSeparator(.hidden)
        } else {
            regularPatchSection
            wallpaperSection
        }
        if cleanerEnabled {
            Section(language.text("repository.utilities")) {
                cleanerRow
            }
        }
    }

    private var bundledPatchTabSection: some View {
        Section {
            Picker("Grupo de opções", selection: $selectedBundledTab) {
                Text("Opções 1–4").tag(0)
                Text("Opções 5–8").tag(1)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Grupo de opções pré-instaladas")
        } header: {
            Text("Patches pré-instalados")
        }
    }

    private var bundledPatchOptionsSection: some View {
        Section {
            ForEach(visibleBundledOptions) { option in
                if let item = store.bundledItem(for: option) {
                    bundledPatchRow(option, item: item)
                } else if store.isBusy {
                    bundledPatchLoadingRow(option)
                } else {
                    bundledPatchUnavailableRow(option)
                }
            }
        } header: {
            Text(selectedBundledTab == 0 ? "Opções 1–4" : "Opções 5–8")
        } footer: {
            Text("Ativar uma opção desativa automaticamente a outra opção pré-instalada que estiver ativa.")
        }
    }

    @ViewBuilder
    private var regularPatchSection: some View {
        if !filteredItems.isEmpty {
            Section(language.text("patch.title")) {
                ForEach(filteredItems) { item in
                    itemRow(item)
                }
                .onDelete { offsets in
                    offsets.map { filteredItems[$0] }.forEach(store.delete)
                }
            }
        }
    }

    @ViewBuilder
    private var wallpaperSection: some View {
        if !filteredWallpaperPackages.isEmpty {
            Section(language.text("tab.wallpapers")) {
                ForEach(filteredWallpaperPackages) { package in
                    NavigationLink {
                        InstalledWallpaperPackageDetailView(
                            package: package,
                            onApplied: reloadWallpaperPackages
                        )
                    } label: {
                        wallpaperRow(package)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            wallpaperPendingDeletion = package
                        } label: {
                            Label(
                                language.text("common.delete"),
                                systemImage: "trash"
                            )
                        }
                    }
                }
            }
        }
    }

    private func consumeExternalImport() {
        guard let request = draftCoordinator.importRequest else { return }
        draftCoordinator.clearImport()
        store.importPackage(from: request.source)
    }

    private func wallpaperRow(_ package: WallpaperStagedPackage) -> some View {
        HStack(spacing: 12) {
            AppRowIcon(systemName: wallpaperSymbol)
            VStack(alignment: .leading, spacing: 3) {
                Text(package.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                InstalledContentKindBadge(kind: .wallpaper, language: language)
                Text(language.text(
                    "wallpaper.package_summary",
                    Int64(package.payload.descriptors.count),
                    ByteCountFormatter.string(
                        fromByteCount: package.payload.totalBytes,
                        countStyle: .file
                    )
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func bundledPatchRow(
        _ option: BundledPatchOption,
        item: PatchLibraryItem
    ) -> some View {
        let active = store.isApplied(item.id)
        return HStack(spacing: 12) {
            AppRowIcon(systemName: active ? "checkmark.circle.fill" : "circle")
            VStack(alignment: .leading, spacing: 4) {
                Text("Opção \(option.number)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(option.filename)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(active ? "Desativar" : "Ativar") {
                pendingBundledAction = PendingBundledPatchAction(
                    option: option,
                    itemID: item.id,
                    activate: !active
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(active ? .orange : AppTheme.accent)
            .disabled(store.isBusy || item.project == nil)
            .accessibilityLabel("\(active ? "Desativar" : "Ativar") \(option.filename)")
        }
        .padding(.vertical, 5)
    }

    private func bundledPatchLoadingRow(_ option: BundledPatchOption) -> some View {
        HStack(spacing: 12) {
            AppRowIcon(systemName: "arrow.down.circle")
            VStack(alignment: .leading, spacing: 4) {
                Text("Opção \(option.number)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(option.filename)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
            }
            Spacer()
            ProgressView()
        }
        .padding(.vertical, 5)
    }

    private func bundledPatchUnavailableRow(_ option: BundledPatchOption) -> some View {
        HStack(spacing: 12) {
            AppRowIcon(systemName: "exclamationmark.circle")
            VStack(alignment: .leading, spacing: 4) {
                Text("Opção \(option.number)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(option.filename)
                    .font(.body.weight(.semibold))
                Text("Pacote indisponível")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Tentar carregar") {
                store.retryBundledPatches()
            }
            .buttonStyle(.bordered)
            .disabled(store.isBusy)
        }
        .padding(.vertical, 5)
    }

    private var cleanerRow: some View {
        Button {
            showCleaner = true
        } label: {
            HStack(spacing: 12) {
                AppRowIcon(systemName: "sparkles")
                VStack(alignment: .leading, spacing: 3) {
                    Text(language.text("tab.cleaner"))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(language.text("repository.cleaner_subtitle"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var wallpaperSymbol: String {
        if #available(iOS 18.0, *) {
            return "photo.on.rectangle.angled.fill"
        }
        return "photo.fill.on.rectangle.fill"
    }

    private func reloadWallpaperPackages() {
        wallpaperPackages = WallpaperPackageStore.packages()
    }

    private func deleteWallpaperPackage(_ package: WallpaperStagedPackage) {
        do {
            try WallpaperPackageStore.delete(package)
            reloadWallpaperPackages()
        } catch {
            wallpaperImportFeedback = WallpaperImportFeedback(
                titleKey: "wallpaper.operation_failed",
                message: wallpaperErrorMessage(error)
            )
        }
    }

    private func importWallpaperPackages(_ urls: [URL]) {
        guard !isImportingWallpapers else { return }
        isImportingWallpapers = true
        DispatchQueue.global(qos: .userInitiated).async {
            var imported = 0
            var failures: [String] = []
            for url in urls {
                do {
                    _ = try WallpaperPackageStore.importPackage(from: url)
                    imported += 1
                    log("wallpaper: staged \(url.lastPathComponent)")
                } catch {
                    failures.append(
                        "\(url.lastPathComponent): \(wallpaperErrorMessage(error))"
                    )
                    log("wallpaper: import rejected \(url.lastPathComponent)")
                }
            }
            DispatchQueue.main.async {
                isImportingWallpapers = false
                reloadWallpaperPackages()
                wallpaperImportFeedback = WallpaperImportFeedback(
                    titleKey: failures.isEmpty
                        ? "wallpaper.import_done_title"
                        : "wallpaper.import_result_title",
                    message: failures.isEmpty
                        ? language.text(
                            "wallpaper.import_done_message",
                            Int64(imported)
                        )
                        : failures.joined(separator: "\n")
                )
            }
        }
    }

    private func wallpaperErrorMessage(_ error: Error) -> String {
        if let wallpaperError = error as? WallpaperLabError {
            return language.text(wallpaperError.localizationKey)
        }
        return language.text("wallpaper.error.unknown")
    }

    @ViewBuilder
    private func itemRow(_ item: PatchLibraryItem) -> some View {
        if item.isLocked {
            Button { store.requestUnlock(for: item) } label: {
                PatchProjectRow(item: item, language: language)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                PatchProjectDetailView(store: store, projectID: item.id)
            } label: {
                PatchProjectRow(item: item, language: language)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(AppTheme.accent)
            Text(language.text("installed.empty_title"))
                .font(.headline)
            Text(language.text("installed.empty_message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(language.text("patch.new")) { showCreate = true }
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(language.text("installed.loading"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    private var searchEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(.secondary)
            Text(language.text("patch.search_empty"))
                .font(.headline)
            Text(language.text("patch.search_empty_message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

private struct WallpaperImportFeedback: Identifiable {
    let id = UUID()
    let titleKey: String
    let message: String
}

private struct PatchProjectRow: View {
    let item: PatchLibraryItem
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            AppRowIcon(systemName: item.isLocked ? "lock.doc.fill" : "shippingbox.fill")
            VStack(alignment: .leading, spacing: 3) {
                Text(item.project?.name ?? language.text("patch.locked_project"))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                InstalledContentKindBadge(kind: .patch, language: language)
                if let author = item.project?.author, !author.isEmpty {
                    Text(language.text("patch.by_author", author))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(rowDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if item.summary.isPasswordProtected {
                Image(systemName: "key.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(language.text("patch.password_protected"))
            }
            if item.project?.isPrivate == true {
                Image(systemName: "eye.slash.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityLabel(language.text("patch.private"))
            }
        }
        .padding(.vertical, 4)
    }

    private var rowDetail: String {
        if item.isLocked {
            return language.text("patch.tap_to_unlock")
        }
        if item.project?.isPrivate == true, !item.isAuthorCopy {
            return language.text("patch.private_received")
        }
        return language.text(
            item.summary.schemaVersion >= 2
                ? "patch.workspace_items_count"
                : "patch.rules_count",
            Int64((item.project?.rules.count ?? 0) + (item.project?.directories.count ?? 0))
        )
    }
}

private enum InstalledContentKind {
    case patch
    case wallpaper

    var localizationKey: String {
        switch self {
        case .patch: return "installed.kind.patch"
        case .wallpaper: return "installed.kind.wallpaper"
        }
    }

    var systemImage: String {
        switch self {
        case .patch: return "shippingbox.fill"
        case .wallpaper: return "photo.fill"
        }
    }
}

private struct InstalledContentKindBadge: View {
    let kind: InstalledContentKind
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: kind.systemImage)
                .accessibilityHidden(true)
            Text(language.text(kind.localizationKey))
        }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(AppTheme.accent.opacity(0.12), in: Capsule())
            .fixedSize()
            .accessibilityElement(children: .combine)
    }
}

struct PatchUnlockView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore
    let request: PatchPasswordRequest
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(language.text("patch.password"), text: $password)
                        .textContentType(.password)
                        .submitLabel(.done)
                        .onSubmit(unlock)
                        .onChange(of: password) { _ in
                            store.clearUnlockError()
                        }
                    if let errorKey = store.unlockErrorKey {
                        Text(language.text(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    if let origin = request.origin {
                        Text(language.text(
                            "patch.password_repo_contact",
                            origin.repositoryName
                        ))
                    } else {
                        Text(language.text("patch.password_once_message"))
                    }
                }
            }
            .navigationTitle(language.text("patch.unlock"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("patch.unlock"), action: unlock)
                        .disabled(password.isEmpty || store.isBusy)
                }
            }
        }
    }

    private func unlock() {
        guard !password.isEmpty else { return }
        store.unlock(password: password)
    }
}

private struct PatchStorePresentationModifier: ViewModifier {
    @ObservedObject var store: PatchProjectStore

    func body(content: Content) -> some View {
        content
            .sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { request in
                PatchUnlockView(store: store, request: request)
            }
    }
}

extension View {
    func patchStorePresentation(_ store: PatchProjectStore) -> some View {
        modifier(PatchStorePresentationModifier(store: store))
    }
}

private struct PatchProjectDetailView: View {
    @Environment(\.appLanguage) private var language
    @ObservedObject var store: PatchProjectStore
    let projectID: UUID
    @State private var showEditor = false
    @State private var editingRule: PatchRule?
    @State private var showApplyConfirmation = false
    @State private var showRestoreConfirmation = false
    @State private var showChangedRestoreConfirmation = false
    @State private var showResetConfirmation = false
    @State private var restoreChangedPaths: [String] = []
    @State private var isWorking = false
    @State private var actionAlert: PatchStoreAlert?
    @State private var shareRequest: PatchShareRequest?

    private var item: PatchLibraryItem? {
        store.items.first(where: { $0.id == projectID })
    }

    private var receipt: PatchTransactionReceipt? {
        DevicePatchService.latestReceipt(projectID: projectID)
    }

    private var isWorkspaceProject: Bool {
        (item?.summary.schemaVersion ?? 1) >= 2
    }

    var body: some View {
        List {
            if let item, let project = item.project {
                Section(language.text("patch.information")) {
                    if !project.author.isEmpty {
                        patchInfoRow(
                            label: language.text("patch.author"),
                            value: project.author
                        )
                    }
                    patchInfoRow(label: language.text("patch.privacy")) {
                        Label(
                            language.text(project.isPrivate
                                ? "patch.private"
                                : "patch.public"),
                            systemImage: project.isPrivate
                                ? "eye.slash.fill"
                                : "eye"
                        )
                        .foregroundStyle(project.isPrivate ? AppTheme.accent : Color.secondary)
                    }
                    if let origin = item.origin {
                        patchInfoRow(
                            label: language.text("repository.source"),
                            value: origin.repositoryName
                        )
                    }
                }

                if project.isPrivate && !item.canInspectContents {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(AppTheme.accent)
                            Text(language.text("patch.private_hidden_title"))
                                .font(.headline)
                            Text(language.text("patch.private_hidden_message"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                } else if isWorkspaceProject {
                    Section {
                        ForEach(project.allBundleIdentifiers, id: \.self) { bundleID in
                            Label {
                                Text(bundleID)
                                    .font(.subheadline.monospaced())
                            } icon: {
                                Image(systemName: "app.dashed")
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                        LabeledContent(language.text("patch.files")) {
                            Text("\(project.rules.count)")
                        }
                        LabeledContent(language.text("patch.folders")) {
                            Text("\(project.directories.count)")
                        }
                        if let workspaceURL = item.workspaceURL {
                            NavigationLink {
                                FileBrowserView(
                                    containerPath: workspaceURL.path,
                                    title: project.name,
                                    bundleID: nil
                                )
                            } label: {
                                Label(
                                    language.text("patch.open_workspace"),
                                    systemImage: "folder"
                                )
                            }
                        }
                    } header: {
                        Text(language.text("patch.workspace"))
                    } footer: {
                        Text(language.text("patch.workspace_detail_footer"))
                    }
                } else {
                    Section {
                        ForEach(project.rules) { rule in
                            Button {
                                editingRule = rule
                            } label: {
                                HStack(spacing: 10) {
                                    ruleSummary(rule)
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(language.text("patch.edit_rule_hint"))
                        }
                    } header: {
                        Text(language.text("patch.rules"))
                    } footer: {
                        Text(language.text("patch.legacy_footer"))
                    }
                }

                Section(language.text("patch.password")) {
                    HStack(spacing: 12) {
                        Image(systemName: item.summary.isPasswordProtected ? "lock.fill" : "lock.open")
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 24)
                        Text(language.text(item.summary.isPasswordProtected
                            ? "patch.password_locked"
                            : "patch.no_password"))
                            .font(.subheadline)
                    }
                }

                Section {
                    Button {
                        showApplyConfirmation = true
                    } label: {
                        actionLabel("patch.apply", systemImage: "checkmark.shield.fill")
                    }
                    .disabled(isWorking || receipt != nil)

                    if receipt != nil {
                        Button {
                            showResetConfirmation = true
                        } label: {
                            actionLabel("patch.reset", systemImage: "arrow.counterclockwise.circle")
                        }
                        .disabled(isWorking)

                        Button(role: .destructive) {
                            showRestoreConfirmation = true
                        } label: {
                            actionLabel("patch.restore", systemImage: "arrow.uturn.backward.circle")
                        }
                        .disabled(isWorking)
                    }

                    Button(action: prepareExport) {
                        actionLabel("patch.export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isWorking)
                } footer: {
                    Text(language.text("patch.apply_footer"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(item?.project?.name ?? language.text("patch.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isWorking {
                    ProgressView()
                } else if !isWorkspaceProject, item?.canInspectContents == true {
                    Button(language.text("patch.edit")) { showEditor = true }
                        .disabled(item?.project == nil)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            if let item, let project = item.project {
                PatchProjectEditorView(
                    existingProject: project,
                    passwordIsProtected: item.summary.isPasswordProtected
                ) { updatedProject, _ in
                    store.update(project: updatedProject)
                }
            }
        }
        .sheet(item: $editingRule) { rule in
            PatchRuleEditorView(rule: rule) { updatedRule in
                updateRule(updatedRule)
            }
        }
        .confirmationDialog(
            language.text("patch.apply_confirm_title"),
            isPresented: $showApplyConfirmation,
            titleVisibility: .visible
        ) {
            Button(language.text("patch.apply")) { apply() }
            Button(language.text("common.cancel"), role: .cancel) {}
        } message: {
            Text(language.text("patch.apply_confirm_message"))
        }
        .confirmationDialog(
            language.text("patch.restore_confirm_title"),
            isPresented: $showRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button(language.text("patch.restore"), role: .destructive) { prepareRestore() }
            Button(language.text("common.cancel"), role: .cancel) {}
        } message: {
            Text(language.text("patch.restore_confirm_message"))
        }
        .confirmationDialog(
            language.text("patch.restore_changed_title"),
            isPresented: $showChangedRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button(language.text("patch.restore_changed_action"), role: .destructive) {
                restore(allowChangedTargets: true)
            }
            Button(language.text("common.cancel"), role: .cancel) {}
        } message: {
            Text(changedRestoreMessage)
        }
        .confirmationDialog(
            language.text("patch.reset_confirm_title"),
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(language.text("patch.reset"), role: .destructive) { resetToAppliedState() }
            Button(language.text("common.cancel"), role: .cancel) {}
        } message: {
            Text(language.text("patch.reset_confirm_message"))
        }
        .alert(item: $actionAlert) { alert in
            Alert(
                title: Text(language.text(alert.titleKey)),
                message: Text(alert.message(language: language)),
                dismissButton: .default(Text(language.text("common.ok")))
            )
        }
        .sheet(item: $shareRequest) { request in
            PatchActivityView(items: [request.url])
                .ignoresSafeArea()
        }
    }

    private func actionLabel(_ key: String, systemImage: String) -> some View {
        Label(language.text(key), systemImage: systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func patchInfoRow(
        label: String,
        value: String
    ) -> some View {
        patchInfoRow(label: label) {
            Text(value)
                .foregroundStyle(.primary)
        }
    }

    private func patchInfoRow<Content: View>(
        label: String,
        @ViewBuilder value: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            value()
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .padding(.vertical, 5)
    }

    private func ruleSummary(_ rule: PatchRule) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(rule.bundleID)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(rule.relativePath)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Label(rule.replacementFilename, systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(AppTheme.accent)
        }
        .padding(.vertical, 3)
    }

    private func updateRule(_ updatedRule: PatchRule) {
        guard var project = item?.project,
              let index = project.rules.firstIndex(where: { $0.id == updatedRule.id }) else {
            return
        }
        project.rules[index] = updatedRule
        project.updatedAt = Date()
        do {
            try PatchPackageCodec.validate(project)
            store.update(project: project)
        } catch let error as PatchPackageError {
            actionAlert = PatchStoreAlert(
                titleKey: "common.failed",
                messageKey: error.localizationKey,
                messageArgument: error.localizationArgument
            )
        } catch {
            actionAlert = PatchStoreAlert(
                titleKey: "common.failed",
                messageKey: "patch.error.invalid_project"
            )
        }
    }

    private func apply() {
        guard let item, let baseProject = item.project else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                let project = item.summary.schemaVersion >= 2 && item.canInspectContents
                    ? try PatchProjectLibrary.synchronizeWorkspace(item: item)
                    : baseProject
                _ = try DevicePatchService.apply(project: project)
                await MainActor.run {
                    store.reload()
                    isWorking = false
                    actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.applied_message")
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: privateErrorKey(for: error),
                        messageArgument: privateErrorArgument(for: error)
                    )
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.apply")
                }
            }
        }
    }

    private func prepareExport() {
        guard let item else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                if item.summary.schemaVersion >= 2, item.canInspectContents {
                    _ = try PatchProjectLibrary.synchronizeWorkspace(item: item)
                }
                await MainActor.run {
                    store.reload()
                    isWorking = false
                    shareRequest = PatchShareRequest(url: item.packageURL)
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: privateErrorKey(for: error),
                        messageArgument: privateErrorArgument(for: error)
                    )
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: "patch.error.invalid_project"
                    )
                }
            }
        }
    }

    private var changedRestoreMessage: String {
        guard item?.project?.isPrivate != true || item?.isAuthorCopy == true else {
            return language.text(
                "patch.restore_changed_private_message",
                Int64(restoreChangedPaths.count)
            )
        }
        var visiblePaths = restoreChangedPaths.prefix(5).joined(separator: "\n")
        if restoreChangedPaths.count > 5 {
            visiblePaths += "\n…"
        }
        return language.text(
            "patch.restore_changed_message",
            Int64(restoreChangedPaths.count),
            visiblePaths
        )
    }

    private func prepareRestore() {
        guard let receipt else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                let inspection = try DevicePatchService.inspectRestore(receipt: receipt)
                if inspection.changedTargets.isEmpty {
                    try DevicePatchService.restore(receipt: receipt)
                    await MainActor.run {
                        isWorking = false
                        actionAlert = PatchStoreAlert(
                            titleKey: "common.done",
                            messageKey: "patch.restored_message"
                        )
                    }
                } else {
                    await MainActor.run {
                        isWorking = false
                        restoreChangedPaths = inspection.changedTargets.map(\.displayPath)
                        showChangedRestoreConfirmation = true
                    }
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: privateErrorKey(for: error),
                        messageArgument: privateErrorArgument(for: error)
                    )
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: "patch.error.restore"
                    )
                }
            }
        }
    }

    private func restore(allowChangedTargets: Bool) {
        guard let receipt else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                try DevicePatchService.restore(
                    receipt: receipt,
                    allowChangedTargets: allowChangedTargets
                )
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.restored_message")
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: privateErrorKey(for: error),
                        messageArgument: privateErrorArgument(for: error)
                    )
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.restore")
                }
            }
        }
    }

    private func resetToAppliedState() {
        guard let receipt, let project = item?.project else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                try DevicePatchService.resetToAppliedState(
                    receipt: receipt,
                    project: project
                )
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.done",
                        messageKey: "patch.reset_message"
                    )
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: privateErrorKey(for: error),
                        messageArgument: privateErrorArgument(for: error)
                    )
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: "patch.error.reset"
                    )
                }
            }
        }
    }

    private func privateErrorKey(for error: PatchPackageError) -> String {
        guard item?.project?.isPrivate == true,
              item?.isAuthorCopy == false else {
            return error.localizationKey
        }
        return "patch.error.private_operation"
    }

    private func privateErrorArgument(for error: PatchPackageError) -> String? {
        guard item?.project?.isPrivate == true,
              item?.isAuthorCopy == false else {
            return error.localizationArgument
        }
        return nil
    }
}

private struct PatchShareRequest: Identifiable {
    let id = UUID()
    let url: URL
}

private struct PatchActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}


struct BundledPatchesTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: PatchProjectStore
    @State private var pendingAction: PendingBundledPatchAction?

    let groupIndex: Int

    private var filenames: [String] {
        if groupIndex == 0 {
            return [
                "FF - Hs Pescoço 100-.3105",
                "FF - Hs Alto 100-.3105",
                "HS PESCOÇO - ANTENA-2.3105",
                "FF - Hs Pescoço-Alto.3105"
            ]
        }
        return [
            "420 i.3105",
            "FF - Hs Alto Baypss.3105",
            "HS 100-.3105",
            "HS PESCOÇO.3105"
        ]
    }

    private var options: [BundledPatchOption] {
        filenames.compactMap { BundledPatchCatalog.option(for: $0) }
    }

    private var groupTitle: String {
        groupIndex == 0 ? "Patches 1–4" : "Patches 5–8"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    groupHeader
                    ForEach(options.indices, id: \.self) { index in
                        patchCard(
                            options[index],
                            displayNumber: groupIndex * 4 + index + 1
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(groupTitle)
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                pendingAction?.activate == true ? "Ativar patch?" : "Desativar patch?",
                isPresented: Binding(
                    get: { pendingAction != nil },
                    set: { if !$0 { pendingAction = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let action = pendingAction {
                    Button(action.activate ? "Ativar" : "Desativar") {
                        store.setBundledPatch(action.itemID, active: action.activate)
                        pendingAction = nil
                    }
                    Button("Cancelar", role: .cancel) {
                        pendingAction = nil
                    }
                }
            } message: {
                if let action = pendingAction {
                    Text(action.activate
                        ? "Ativar \(action.option.filename). Outra opção pré-instalada ativa será desativada primeiro."
                        : "Desativar \(action.option.filename) e restaurar o arquivo original.")
                }
            }
        }
        .tint(AppTheme.accent)
    }

    private var groupHeader: some View {
        HStack(spacing: 13) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 46, height: 46)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(groupTitle.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
                Text("Escolha um patch")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 2)
    }

    private func patchCard(
        _ option: BundledPatchOption,
        displayNumber: Int
    ) -> some View {
        let item = store.bundledItem(for: option)
        let active = item.map { store.isApplied($0.id) } ?? false
        let status = item == nil
            ? (store.isBusy ? "CARREGANDO" : "INDISPONÍVEL")
            : (active ? "ATIVO" : "DESATIVADO")

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text(String(format: "%02d", displayNumber))
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle().strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text("OPÇÃO \(displayNumber)")
                        .font(.caption2.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    Text(option.filename)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                    Text(status)
                        .font(.caption2.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(active ? .primary : .secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.055), in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(Color.primary.opacity(0.09), lineWidth: 0.7)
                        }
                }
                Spacer(minLength: 0)
            }

            if let item {
                glassButton(
                    title: active ? "Desativar" : "Ativar",
                    symbol: active ? "arrow.uturn.backward" : "checkmark",
                    emphasized: active
                ) {
                    pendingAction = PendingBundledPatchAction(
                        option: option,
                        itemID: item.id,
                        activate: !active
                    )
                }
                .disabled(store.isBusy || item.project == nil)
            } else if store.isBusy {
                HStack(spacing: 9) {
                    ProgressView()
                    Text("Carregando patch…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                glassButton(
                    title: "Tentar carregar",
                    symbol: "arrow.clockwise",
                    emphasized: false
                ) {
                    store.retryBundledPatches()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.18),
                            Color.primary.opacity(0.035),
                            Color.primary.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.055),
            radius: 14,
            x: 0,
            y: 7
        )
    }

    private func glassButton(
        title: String,
        symbol: String,
        emphasized: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(emphasized ? Color(uiColor: .systemBackground) : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule().fill(Color.primary.opacity(emphasized ? 0.84 : 0.045))
                        }
                }
                .overlay {
                    Capsule().strokeBorder(Color.primary.opacity(0.17), lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
    }
}

struct DeviceInfoTabView: View {
    private var compatible: Bool {
        let version = AppInfo.versionTuple
        return ExploitSupportPolicy.isSupported(
            major: version.major,
            minor: version.minor,
            patch: version.patch,
            build: AppInfo.osBuild
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 13) {
                        Image(systemName: "iphone")
                            .font(.system(size: 23, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                            }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SEU DISPOSITIVO")
                                .font(.caption.weight(.bold))
                                .tracking(1.1)
                                .foregroundStyle(.secondary)
                            Text("Informações do sistema")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.bottom, 2)

                    DeviceInfoGlassCard(
                        symbol: "iphone",
                        title: "MODELO DO DISPOSITIVO",
                        value: UIDevice.current.model,
                        detail: AppInfo.displayMachineName
                    )
                    DeviceInfoGlassCard(
                        symbol: "gearshape",
                        title: "VERSÃO DO iOS",
                        value: "iOS \(AppInfo.osVersion)",
                        detail: "Build \(AppInfo.osBuild)"
                    )
                    DeviceInfoGlassCard(
                        symbol: compatible ? "checkmark.shield" : "info.circle",
                        title: "COMPATIBILIDADE DO 3105",
                        value: compatible ? "Dentro da faixa suportada" : "Fora da faixa verificada",
                        detail: compatible
                            ? "Esta versão do iOS está na faixa verificada para o exploit do 3105."
                            : "Esta versão do iOS não está na faixa verificada no código do 3105."
                    )
                    Text("A aplicação dos patches também depende do app-alvo e do acesso aos arquivos dele neste dispositivo.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("Dispositivo")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(AppTheme.accent)
    }
}

private struct DeviceInfoGlassCard: View {
    let symbol: String
    let title: String
    let value: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8)
                }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .tracking(0.9)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.9)
        }
        .shadow(color: Color.black.opacity(0.045), radius: 12, x: 0, y: 5)
    }
}


struct AvatarCacheTabView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: PatchProjectStore
    @State private var pendingStates: [UUID: Bool] = [:]

    let groupIndex: Int
    let showsBackdrop: Bool

    init(groupIndex: Int, showsBackdrop: Bool = true) {
        self.groupIndex = groupIndex
        self.showsBackdrop = showsBackdrop
    }

    private var filenames: [String] {
        let visibleFilenames: [String]
        if groupIndex == 0 {
            visibleFilenames = [
                "FF - Hs Pescoço 100-.3105",
                "FF - Hs Alto 100-.3105",
                "FF - Hs Pescoço-Alto.3105"
            ]
        } else {
            visibleFilenames = [
                "FF - Hs Alto Baypss.3105",
                "HS PESCOÇO.3105"
            ]
        }
        let activeHiddenFilenames = BundledPatchCatalog.options.compactMap { option -> String? in
            guard option.tabIndex == groupIndex,
                  !visibleFilenames.contains(option.filename),
                  let item = store.bundledItem(for: option),
                  store.isApplied(item.id) else { return nil }
            return option.filename
        }
        return visibleFilenames + activeHiddenFilenames
    }

    private var options: [BundledPatchOption] {
        filenames.compactMap { BundledPatchCatalog.option(for: $0) }
    }

    private var tabTitle: String {
        groupIndex == 0 ? "AVATAR" : "CACHE"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if showsBackdrop {
                    MonochromeGlassBackdrop()
                } else {
                    Color.clear
                }
                VStack(spacing: 13) {
                    ForEach(options) { option in
                        patchRow(option)
                    }
                }
                .padding(.horizontal, 17)
                .padding(.top, 22)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(tabTitle)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
        }
        .tint(AppTheme.accent)
        .onChange(of: store.isBusy) { busy in
            if !busy { pendingStates.removeAll() }
        }
    }

    private func patchRow(_ option: BundledPatchOption) -> some View {
        let name = displayName(for: option)
        let item = store.bundledItem(for: option)

        return HStack(spacing: 13) {
            Text(name)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .tracking(0.35)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            patchControl(name: name, item: item)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: colorScheme == .dark
                                    ? [Color.white.opacity(0.13), Color.white.opacity(0.035), Color.black.opacity(0.17)]
                                    : [Color.white.opacity(0.92), Color.white.opacity(0.62), Color.black.opacity(0.025)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            (colorScheme == .dark ? Color.white : Color.black)
                                .opacity(colorScheme == .dark ? 0.13 : 0.025),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color.white.opacity(0.42), Color.white.opacity(0.075), Color.gray.opacity(0.19)]
                            : [Color.white.opacity(0.95), Color.gray.opacity(0.28), Color.black.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.42 : 0.10), radius: 22, x: 0, y: 12)
    }

    @ViewBuilder
    private func patchControl(
        name: String,
        item: PatchLibraryItem?
    ) -> some View {
        if let item, item.project != nil || store.isApplied(item.id) {
            Toggle(isOn: Binding(
                get: { requestedState(for: item.id) },
                set: { isOn in setActive(isOn, for: item.id) }
            )) {
                Text(name)
            }
            .labelsHidden()
            .toggleStyle(LiquidGlassToggleStyle())
            .accessibilityLabel(name)
            .accessibilityValue(requestedState(for: item.id) ? "Ligado" : "Desligado")
            .disabled(store.isBusy || (item.project == nil && !store.isApplied(item.id)))
        } else if store.isBusy {
            ProgressView()
                .controlSize(.small)
                .tint(colorScheme == .dark ? Color.white : Color.primary)
                .frame(minWidth: 90)
                .accessibilityLabel(language.text("patch.bundled.loading"))
        } else {
            Button {
                store.retryBundledPatches()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                    Text(language.text("patch.bundled.unavailable"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.78) : Color.primary.opacity(0.78))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text("patch.bundled.unavailable"))
            .accessibilityHint(language.text("patch.bundled.retry_hint"))
        }
    }

    private func displayName(for option: BundledPatchOption) -> String {
        switch option.filename {
        case "420 i.3105": return "HS・PEITO/PESCOÇO"
        case "FF - Hs Alto 100-.3105": return "HS・ALTO"
        case "FF - Hs Alto Baypss.3105": return "HS・ALTO/PESCOÇO"
        case "FF - Hs Pescoço 100-.3105": return "HS・PESCOÇO"
        case "FF - Hs Pescoço-Alto.3105": return "HS・ALTO/PESCOÇO"
        case "HS 100-.3105": return "HS・PEITO"
        case "HS PESCOÇO - ANTENA-2.3105": return "HS・PESCOÇO + ANTENA"
        case "HS PESCOÇO.3105": return "HS・PESCOÇO"
        default: return option.packageName
        }
    }

    private func requestedState(for projectID: UUID) -> Bool {
        pendingStates[projectID] ?? store.isApplied(projectID)
    }

    private func setActive(_ active: Bool, for projectID: UUID) {
        guard !store.isBusy else { return }
        if active {
            for item in store.items where store.isBundledPatch(item.id) {
                pendingStates[item.id] = false
            }
        }
        pendingStates[projectID] = active
        store.setBundledPatch(projectID, active: active)
    }
}

private struct LiquidGlassToggleStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule().fill(Color.primary.opacity(configuration.isOn ? 0.18 : 0.055))
                    }
                    .overlay {
                        Capsule().strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.primary.opacity(colorScheme == .dark ? 0.48 : 0.22),
                                    Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.07)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                    }
                Circle()
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color.white, Color.gray.opacity(0.78)]
                                : [Color.white, Color.gray.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 29, height: 29)
                    .padding(4)
                    .overlay {
                        Circle().strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.15), lineWidth: 0.7)
                    }
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.42 : 0.16), radius: 6, x: 0, y: 2)
            }
            .frame(width: 72, height: 40)
            .opacity(isEnabled ? 1 : 0.44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(configuration.isOn ? "Desligar" : "Ligar")
        .accessibilityValue(configuration.isOn ? "Ligado" : "Desligado")
        .accessibilityAddTraits(.isButton)
        .disabled(!isEnabled)
    }
}

struct MonochromeGlassBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(white: colorScheme == .dark ? 0.045 : 0.985), location: 0),
                .init(color: Color(white: colorScheme == .dark ? 0.045 : 0.985), location: 0.61),
                .init(color: Color(white: colorScheme == .dark ? 0.10 : 0.86), location: 1)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct LiquidGlassDeviceInfoTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppAppearance.darkModeStorageKey) private var darkModeEnabled = true

    // Login/validação ainda não existe; estes valores serão fornecidos pelo fluxo de ativação futuro.
    let activationKey: String?
    let keyExpiresAt: Date?
    let showsBackdrop: Bool

    init(activationKey: String? = nil, keyExpiresAt: Date? = nil, showsBackdrop: Bool = true) {
        self.activationKey = activationKey
        self.keyExpiresAt = keyExpiresAt
        self.showsBackdrop = showsBackdrop
    }

    private enum CompatibilityStatus {
        case compatible
        case incompatible
        case unconfirmed

        var title: String {
            switch self {
            case .compatible: return "Compatível"
            case .incompatible: return "Incompatível"
            case .unconfirmed: return "Compatibilidade não confirmada"
            }
        }
    }

    private var compatibilityStatus: CompatibilityStatus {
        let version = AppInfo.versionTuple
        if ExploitSupportPolicy.isSupported(
            major: version.major,
            minor: version.minor,
            patch: version.patch,
            build: AppInfo.osBuild
        ) {
            return .compatible
        }
        switch version.major {
        case 17, 18, 26:
            return .incompatible
        default:
            return .unconfirmed
        }
    }

    private var maskedKey: String {
        guard let activationKey else { return "AGUARDANDO LOGIN" }
        let visiblePrefix = String(activationKey.prefix(5))
        let hiddenLength = max(0, activationKey.count - visiblePrefix.count)
        return visiblePrefix + String(repeating: "•", count: hiddenLength)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if showsBackdrop {
                    MonochromeGlassBackdrop()
                } else {
                    Color.clear
                }
                VStack(spacing: 14) {
                    keyStatusCard
                    deviceSummaryCard
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 17)
                .padding(.top, 18)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PERFIL")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        darkModeEnabled.toggle()
                    } label: {
                        Image(systemName: darkModeEnabled ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        Color.primary.opacity(colorScheme == .dark ? 0.20 : 0.12),
                                        lineWidth: 0.8
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(darkModeEnabled ? "Ativar modo claro" : "Ativar modo escuro")
                }
            }
        }
        .tint(AppTheme.accent)
    }

    private var keyStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LICENÇA")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(0.9)
                .foregroundStyle(.primary)

            licenseInfoRow(title: "KEY", symbol: "key.fill", value: maskedKey)
            Divider()
            licenseInfoRow(
                title: "VALIDADE",
                symbol: "calendar",
                value: keyExpiresAt.map {
                    DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none)
                } ?? "Aguardando login"
            )
            Divider()
            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18)
                    .foregroundStyle(.primary)
                Text("TEMPO RESTANTE")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Group {
                    if let keyExpiresAt {
                        TimelineView(.periodic(from: Date(), by: 1)) { context in
                            Text(countdownText(until: keyExpiresAt, now: context.date))
                        }
                    } else {
                        Text("--D --:--:--")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 12, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .accessibilityLabel(keyExpiresAt == nil ? "Tempo restante aguardando login" : "Tempo restante")

            HStack {
                Spacer(minLength: 0)
                Button(action: copyActivationKey) {
                    Label("COPIAR", systemImage: "doc.on.doc")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .disabled(activationKey == nil)
                .opacity(activationKey == nil ? 0.45 : 1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(profileCardSurface())
    }

    private func licenseInfoRow(title: String, symbol: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 18)
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
    }

    private var deviceSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DISPOSITIVO")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(0.9)
                .foregroundStyle(.primary)
            deviceInfoRow(title: "MODELO DO IPHONE", symbol: "iphone", value: AppInfo.hardwareDisplayName)
            Divider()
            deviceInfoRow(title: "VERSÃO DO iOS", symbol: "gearshape", value: AppInfo.osVersion)
            Divider()
            deviceInfoRow(
                title: "COMPATIBILIDADE",
                symbol: "exclamationmark.triangle.fill",
                value: compatibilityStatus.title
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(profileCardSurface())
    }

    private func deviceInfoRow(title: String, symbol: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func profileCardSurface() -> some View {
        RoundedRectangle(cornerRadius: 25, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color.white.opacity(0.13), Color.white.opacity(0.035), Color.black.opacity(0.17)]
                                : [Color.white.opacity(0.92), Color.white.opacity(0.62), Color.black.opacity(0.025)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.20 : 0.12), lineWidth: 0.9)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.40 : 0.08), radius: 22, x: 0, y: 12)
    }

    private func countdownText(until expiration: Date, now: Date) -> String {
        let remaining = max(0, Int(expiration.timeIntervalSince(now)))
        guard remaining > 0 else { return "EXPIRADA" }
        let days = remaining / 86_400
        let hours = (remaining % 86_400) / 3_600
        let minutes = (remaining % 3_600) / 60
        let seconds = remaining % 60
        return String(format: "%02dD  %02d:%02d:%02d", days, hours, minutes, seconds)
    }

    private func copyActivationKey() {
        guard let activationKey else { return }
        UIPasteboard.general.string = activationKey
    }
}
