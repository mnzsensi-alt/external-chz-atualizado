import Foundation

struct PatchStoreAlert: Identifiable {
    let id = UUID()
    let titleKey: String
    let messageKey: String
    var messageArgument: String?

    init(titleKey: String, messageKey: String, messageArgument: String? = nil) {
        self.titleKey = titleKey
        self.messageKey = messageKey
        self.messageArgument = messageArgument
    }

    func message(language: AppLanguage) -> String {
        if let messageArgument {
            return language.text(messageKey, messageArgument)
        }
        return language.text(messageKey)
    }
}

struct BundledPatchOption: Identifiable, Equatable {
    let number: Int
    let filename: String
    let packageName: String

    var id: String { filename }
    var tabIndex: Int { number <= 4 ? 0 : 1 }
}

enum BundledPatchCatalog {
    static let options: [BundledPatchOption] = [
        BundledPatchOption(number: 1, filename: "420 i.3105", packageName: "420 i"),
        BundledPatchOption(number: 2, filename: "FF - Hs Alto 100-.3105", packageName: "Hs Alto 100%"),
        BundledPatchOption(number: 3, filename: "FF - Hs Alto Baypss.3105", packageName: "Hs Alto Baypss"),
        BundledPatchOption(number: 4, filename: "FF - Hs Pescoço 100-.3105", packageName: "Hs Pescoço 100%"),
        BundledPatchOption(number: 5, filename: "FF - Hs Pescoço-Alto.3105", packageName: "Hs Pescoço+Alto"),
        BundledPatchOption(number: 6, filename: "HS 100-.3105", packageName: "HS 100%"),
        BundledPatchOption(number: 7, filename: "HS PESCOÇO - ANTENA-2.3105", packageName: "HS PESCOÇO + ANTENA"),
        BundledPatchOption(number: 8, filename: "HS PESCOÇO.3105", packageName: "HS PESCOÇO")
    ]

    static func sourceKey(for packageID: UUID) -> String {
        "3105.bundled_patch.source.\(packageID.uuidString)"
    }

    static func option(for filename: String) -> BundledPatchOption? {
        options.first { $0.filename == filename }
    }

    static func option(packageName: String) -> BundledPatchOption? {
        options.first { $0.packageName == packageName }
    }
}

private enum BundledPatchBootstrap {
    static func importIfNeeded() {
        let bundledURLs = Bundle.main.urls(
            forResourcesWithExtension: "3105",
            subdirectory: "BundledPatches"
        ) ?? []
        let resourceDirectory = Bundle.main.resourceURL?.appendingPathComponent(
            "BundledPatches",
            isDirectory: true
        )
        let directoryURLs = resourceDirectory.flatMap { directory in
            try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )
        } ?? []
        let sources = Array(Set(bundledURLs + directoryURLs))
            .filter { $0.pathExtension.lowercased() == "3105" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !sources.isEmpty else { return }

        var existingIDs = Set(PatchProjectLibrary.load().map(\.id))
        for sourceURL in sources {
            do {
                let data = try PatchProjectLibrary.readPackage(at: sourceURL)
                let summary = try PatchPackageCodec.inspect(data)
                guard !summary.isPasswordProtected else {
                    throw PatchPackageError.invalidProject
                }
                let decoded = try PatchPackageCodec.decode(data, password: nil)
                guard let option = BundledPatchCatalog.option(
                    packageName: decoded.project.name
                ) else { continue }
                let sourceKey = BundledPatchCatalog.sourceKey(for: summary.packageID)
                if existingIDs.contains(summary.packageID) {
                    UserDefaults.standard.set(option.filename, forKey: sourceKey)
                    continue
                }
                // Keep all eight packs available in the library, including packs whose
                // destinations overlap. The transaction layer blocks overlapping applies.
                _ = try PatchProjectLibrary.save(
                    data: data,
                    projectName: decoded.project.name
                )
                existingIDs.insert(summary.packageID)
                UserDefaults.standard.set(option.filename, forKey: sourceKey)
            } catch {
                log("patch: skipped bundled package \(sourceURL.lastPathComponent)")
            }
        }
    }
}

@MainActor
final class PatchProjectStore: ObservableObject {
    @Published private(set) var items: [PatchLibraryItem] = []
    @Published private(set) var isBusy = false
    @Published private(set) var appliedProjectIDs: Set<UUID> = []
    @Published var passwordRequest: PatchPasswordRequest?
    @Published var alert: PatchStoreAlert?
    @Published var unlockErrorKey: String?

    private struct PendingUnlock {
        let data: Data
        let summary: PatchPackageSummary
        let existingURL: URL?
        let origin: PatchPackageOrigin?
    }

    private var pendingUnlock: PendingUnlock?

    init() {
        isBusy = true
        Task.detached(priority: .userInitiated) { [weak self] in
            BundledPatchBootstrap.importIfNeeded()
            let loadedItems = PatchProjectLibrary.load()
            await self?.finishInitialLoad(loadedItems)
        }
    }

    func reload() {
        items = PatchProjectLibrary.load()
        appliedProjectIDs = Set(items.compactMap { item in
            DevicePatchService.latestReceipt(projectID: item.id) == nil ? nil : item.id
        })
    }

    func retryBundledPatches() {
        guard !isBusy else { return }
        isBusy = true
        Task.detached(priority: .userInitiated) { [weak self] in
            BundledPatchBootstrap.importIfNeeded()
            let loadedItems = PatchProjectLibrary.load()
            await self?.finishInitialLoad(loadedItems)
        }
    }

    func isApplied(_ projectID: UUID) -> Bool {
        appliedProjectIDs.contains(projectID)
    }

    func isBundledPatch(_ projectID: UUID) -> Bool {
        guard let filename = UserDefaults.standard.string(
            forKey: BundledPatchCatalog.sourceKey(for: projectID)
        ) else { return false }
        return BundledPatchCatalog.option(for: filename) != nil
    }

    func bundledItem(for option: BundledPatchOption) -> PatchLibraryItem? {
        items.first { item in
            UserDefaults.standard.string(
                forKey: BundledPatchCatalog.sourceKey(for: item.id)
            ) == option.filename
        }
    }

    func setBundledPatch(_ projectID: UUID, active: Bool) {
        guard !isBusy,
              let item = items.first(where: { $0.id == projectID }),
              isBundledPatch(projectID) else { return }

        if active {
            guard let project = item.project else {
                present(.invalidProject)
                return
            }
            let activeOthers = items.filter {
                $0.id != projectID
                    && isBundledPatch($0.id)
                    && DevicePatchService.latestReceipt(projectID: $0.id) != nil
            }
            runOperation(successMessageKey: "patch.applied_message") {
                var restoredProjects: [PatchProject] = []
                do {
                    for other in activeOthers {
                        guard let receipt = DevicePatchService.latestReceipt(projectID: other.id) else {
                            continue
                        }
                        try DevicePatchService.restore(receipt: receipt)
                        if let otherProject = other.project {
                            restoredProjects.append(otherProject)
                        }
                    }
                    _ = try DevicePatchService.apply(project: project)
                } catch {
                    for restoredProject in restoredProjects.reversed() {
                        _ = try? DevicePatchService.apply(project: restoredProject)
                    }
                    throw error
                }
            }
        } else if let receipt = DevicePatchService.latestReceipt(projectID: projectID) {
            runOperation(successMessageKey: "patch.restored_message") {
                try DevicePatchService.restore(receipt: receipt)
            }
        }
    }

    private func finishInitialLoad(_ loadedItems: [PatchLibraryItem]) {
        items = loadedItems
        appliedProjectIDs = Set(loadedItems.compactMap { item in
            DevicePatchService.latestReceipt(projectID: item.id) == nil ? nil : item.id
        })
        isBusy = false
    }

    func create(project: PatchProject, password: String?) {
        runOperation(successMessageKey: "patch.created_message") {
            let encoded = try PatchPackageCodec.encodeNew(project: project, password: password)
            let summary = try PatchPackageCodec.inspect(encoded.data)
            let workspace = try PatchWorkspaceService.createWorkspace(for: project)
            var savedURL: URL?
            do {
                if summary.isPasswordProtected {
                    try PatchKeyStore.store(encoded.contentKey, for: summary)
                }
                savedURL = try PatchProjectLibrary.save(
                    data: encoded.data,
                    projectName: project.name
                )
                try PatchProjectLibrary.markAsAuthorCopy(packageID: project.id)
            } catch {
                try? FileManager.default.removeItem(at: workspace)
                if let savedURL {
                    try? FileManager.default.removeItem(at: savedURL)
                }
                try? PatchKeyStore.delete(for: summary)
                throw error
            }
        }
    }

    func update(project: PatchProject) {
        guard let item = items.first(where: { $0.id == project.id }),
              let contentKey = item.contentKey else {
            present(.invalidProject)
            return
        }
        runOperation(successMessageKey: "patch.updated_message") {
            let original = try PatchProjectLibrary.readPackage(at: item.packageURL)
            let updated = try PatchPackageCodec.update(
                original,
                project: project,
                contentKey: contentKey,
                schemaVersion: PatchPackageCodec.latestSchemaVersion
            )
            _ = try PatchProjectLibrary.save(
                data: updated,
                projectName: project.name,
                existingURL: item.packageURL
            )
        }
    }

    func importPackage(at sourceURL: URL) {
        guard !isBusy else { return }
        isBusy = true
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        Task.detached(priority: .userInitiated) { [weak self] in
            defer {
                if hasAccess { sourceURL.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try PatchProjectLibrary.readPackage(at: sourceURL)
                let summary = try PatchPackageCodec.inspect(data)
                let existingURL = await self?.existingPackageURL(for: summary.packageID)
                if let pending = try Self.persistImportedPackage(
                    data: data,
                    summary: summary,
                    existingURL: existingURL
                ) {
                    await self?.requestPassword(pending: pending)
                } else {
                    await self?.finishOperation(successMessageKey: "patch.imported_message")
                }
            } catch let error as PatchPackageError {
                await self?.failOperation(error)
            } catch {
                await self?.failOperation(.unsupportedFormat)
            }
        }
    }

    @discardableResult
    func importPackage(
        data: Data,
        password: String? = nil,
        origin: PatchPackageOrigin? = nil
    ) -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let summary = try PatchPackageCodec.inspect(data)
                let existingURL = await self?.existingPackageURL(for: summary.packageID)
                if let pending = try Self.persistImportedPackage(
                    data: data,
                    summary: summary,
                    existingURL: existingURL,
                    password: password,
                    origin: origin
                ) {
                    await self?.requestPassword(pending: pending)
                } else {
                    await self?.finishOperation(successMessageKey: "patch.imported_message")
                }
            } catch let error as PatchPackageError {
                await self?.failOperation(error)
            } catch {
                await self?.failOperation(.unsupportedFormat)
            }
        }
        return true
    }

    func presentImportError(_ error: PatchPackageError) {
        present(error)
    }

    func importPackage(from source: PatchImportSource) {
        switch source {
        case .file(let url):
            importPackage(at: url)
        case .remote(let url):
            importPackage(fromRemoteURL: url)
        case .invalid:
            present(.invalidImportLink)
        }
    }

    private func importPackage(fromRemoteURL remoteURL: URL) {
        guard !isBusy,
              PatchImportRoute.validatedRemoteURL(remoteURL) != nil else {
            if !isBusy { present(.invalidImportLink) }
            return
        }
        isBusy = true
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = 60
                configuration.timeoutIntervalForResource = 600
                let session = URLSession(configuration: configuration)
                defer { session.invalidateAndCancel() }

                let (temporaryURL, response) = try await session.download(from: remoteURL)
                defer { try? FileManager.default.removeItem(at: temporaryURL) }
                guard let response = response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode),
                      let finalURL = response.url,
                      PatchImportRoute.validatedRemoteURL(finalURL) != nil else {
                    throw PatchPackageError.remoteImportFailed
                }

                let data = try PatchProjectLibrary.readPackage(at: temporaryURL)
                let summary = try PatchPackageCodec.inspect(data)
                let existingURL = await self?.existingPackageURL(for: summary.packageID)
                if let pending = try Self.persistImportedPackage(
                    data: data,
                    summary: summary,
                    existingURL: existingURL
                ) {
                    await self?.requestPassword(pending: pending)
                } else {
                    await self?.finishOperation(successMessageKey: "patch.imported_message")
                }
            } catch let error as PatchPackageError {
                await self?.failOperation(error)
            } catch {
                await self?.failOperation(.remoteImportFailed)
            }
        }
    }

    func requestUnlock(for item: PatchLibraryItem) {
        guard item.isLocked, !isBusy else { return }
        do {
            let data = try PatchProjectLibrary.readPackage(at: item.packageURL)
            pendingUnlock = PendingUnlock(
                data: data,
                summary: item.summary,
                existingURL: item.packageURL,
                origin: item.origin
            )
            passwordRequest = PatchPasswordRequest(
                summary: item.summary,
                origin: item.origin
            )
        } catch let error as PatchPackageError {
            present(error)
        } catch {
            present(.unsupportedFormat)
        }
    }

    func unlock(password: String) {
        guard let pending = pendingUnlock, !isBusy else { return }
        isBusy = true
        unlockErrorKey = nil
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let decoded = try PatchPackageCodec.decode(pending.data, password: password)
                try PatchKeyStore.store(decoded.contentKey, for: pending.summary)
                do {
                    try PatchProjectLibrary.installImportedPackage(
                        data: pending.data,
                        decoded: decoded,
                        summary: pending.summary,
                        existingURL: pending.existingURL,
                        origin: pending.origin
                    )
                } catch {
                    try? PatchKeyStore.delete(for: pending.summary)
                    throw error
                }
                await self?.clearPendingUnlock()
                await self?.finishOperation(successMessageKey: "patch.unlocked_message")
            } catch let error as PatchPackageError {
                await self?.failUnlock(error)
            } catch {
                await self?.failUnlock(.invalidPasswordOrCorruptedPackage)
            }
        }
    }

    func cancelUnlock() {
        clearPendingUnlock()
        isBusy = false
    }

    func clearUnlockError() {
        unlockErrorKey = nil
    }

    func delete(_ item: PatchLibraryItem) {
        do {
            try PatchProjectLibrary.delete(item)
            reload()
        } catch let error as PatchPackageError {
            present(error)
        } catch {
            present(.invalidProject)
        }
    }

    func synchronizeWorkspace(projectID: UUID, reportsSuccess: Bool = false) {
        guard let item = items.first(where: { $0.id == projectID }),
              item.summary.schemaVersion >= 2,
              !isBusy else { return }
        isBusy = true
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                _ = try PatchProjectLibrary.synchronizeWorkspace(item: item)
                await self?.finishWorkspaceSynchronization(reportsSuccess: reportsSuccess)
            } catch let error as PatchPackageError {
                await self?.failOperation(error)
            } catch {
                await self?.failOperation(.invalidProject)
            }
        }
    }

    private func finishWorkspaceSynchronization(reportsSuccess: Bool) {
        reload()
        isBusy = false
        if reportsSuccess {
            alert = PatchStoreAlert(
                titleKey: "common.done",
                messageKey: "patch.workspace_synced_message"
            )
        }
    }

    private func runOperation(
        successMessageKey: String,
        operation: @escaping () throws -> Void
    ) {
        guard !isBusy else { return }
        isBusy = true
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try operation()
                await self?.finishOperation(successMessageKey: successMessageKey)
            } catch let error as PatchPackageError {
                await self?.failOperation(error)
            } catch {
                await self?.failOperation(.invalidProject)
            }
        }
    }

    private func requestPassword(pending: PendingUnlock) {
        pendingUnlock = pending
        passwordRequest = PatchPasswordRequest(
            summary: pending.summary,
            origin: pending.origin
        )
        isBusy = false
    }

    private func existingPackageURL(for packageID: UUID) -> URL? {
        items.first(where: { $0.id == packageID })?.packageURL
    }

    private nonisolated static func persistImportedPackage(
        data: Data,
        summary: PatchPackageSummary,
        existingURL: URL?,
        password: String? = nil,
        origin: PatchPackageOrigin? = nil
    ) throws -> PendingUnlock? {
        if let key = try PatchKeyStore.load(for: summary) {
            let decoded = try PatchPackageCodec.decode(data, contentKey: key)
            try PatchProjectLibrary.installImportedPackage(
                data: data,
                decoded: decoded,
                summary: summary,
                existingURL: existingURL,
                origin: origin
            )
            return nil
        }
        if summary.isPasswordProtected {
            guard let password else {
                return PendingUnlock(
                    data: data,
                    summary: summary,
                    existingURL: existingURL,
                    origin: origin
                )
            }
            let decoded = try PatchPackageCodec.decode(data, password: password)
            try PatchKeyStore.store(decoded.contentKey, for: summary)
            do {
                try PatchProjectLibrary.installImportedPackage(
                    data: data,
                    decoded: decoded,
                    summary: summary,
                    existingURL: existingURL,
                    origin: origin
                )
            } catch {
                try? PatchKeyStore.delete(for: summary)
                throw error
            }
            return nil
        }
        let decoded = try PatchPackageCodec.decode(data, password: nil)
        try PatchProjectLibrary.installImportedPackage(
            data: data,
            decoded: decoded,
            summary: summary,
            existingURL: existingURL,
            origin: origin
        )
        return nil
    }

    private func clearPendingUnlock() {
        pendingUnlock = nil
        passwordRequest = nil
        unlockErrorKey = nil
    }

    private func finishOperation(successMessageKey: String) {
        reload()
        isBusy = false
        alert = PatchStoreAlert(titleKey: "common.done", messageKey: successMessageKey)
    }

    private func failOperation(_ error: PatchPackageError) {
        isBusy = false
        present(error)
    }

    private func failUnlock(_ error: PatchPackageError) {
        isBusy = false
        // Keep the password sheet open so the user can retry.
        // Presenting an alert while dismissing the sheet swallows the message.
        if case .invalidPasswordOrCorruptedPackage = error {
            unlockErrorKey = "patch.error.wrong_password"
        } else {
            unlockErrorKey = error.localizationKey
        }
    }

    private func present(_ error: PatchPackageError) {
        alert = PatchStoreAlert(
            titleKey: "common.failed",
            messageKey: error.localizationKey,
            messageArgument: error.localizationArgument
        )
    }
}
