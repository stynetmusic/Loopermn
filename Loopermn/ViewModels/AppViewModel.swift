import Foundation
import AVFoundation
import AppKit
import Combine

enum AppMode: String, CaseIterable {
    case browser = "Browser"
    case library = "Library"
    case studio = "Studio"
}

enum SidebarTab: String, Identifiable, CaseIterable {
    case collections = "Коллекции"
    case allLoops = "Все лупы"
    case recent = "Недавние"
    case favorites = "Избранное"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .collections: return "folder"
        case .allLoops: return "music.note"
        case .recent: return "clock"
        case .favorites: return "star.fill"
        }
    }
}

enum SortOption: String, Identifiable, CaseIterable {
    case name = "По имени"
    case bpm = "По BPM"
    case key = "По тональности"
    case dateAdded = "По дате добавления"
    case rating = "По рейтингу"
    case duration = "По длительности"

    var id: String { rawValue }
}

final class AppViewModel: ObservableObject {

    private let metadataExtractor = MetadataExtractor()

    @Published var loops: [LoopItem] = []
    @Published var filteredLoops: [LoopItem] = []
    @Published var selectedTab: SidebarTab = .allLoops
    @Published var searchText: String = ""
    @Published var selectedBPMRange: ClosedRange<Int>? = nil
    @Published var selectedKey: LoopKey? = nil
    @Published var selectedTags: [String] = []
    @Published var sortOption: SortOption = .name
    @Published var libraryLayout: LibraryLayoutMode = .grid
    @Published var isLoading: Bool = false
    @Published var selectedFolderURL: URL?
    @Published var currentPlayerItem: LoopItem?
    @Published var currentMode: AppMode = .library
    @Published var highlightedLoopID: UUID?

    private let scanner = LoopScanner()
    private let fileWatcher = FileWatcher()
    private var cancellables = Set<AnyCancellable>()
    private var highlightClearTask: Task<Void, Never>?

    init() {
        loadLibrary()
        setupSearchFilter()
        setupFileWatcher()
    }

    /// JSON only. Never walks disk / Downloads on launch.
    func loadLibrary() {
        do {
            loops = try PersistenceManager.shared.loadLibrary()
        } catch {
            loops = []
        }
        applyFilters()
    }

    func saveLibrary() {
        do {
            try PersistenceManager.shared.saveLibrary(loops)
        } catch {
            print("Failed to save library: \(error)")
        }
    }

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.title = "Выберите папку с лупами"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            selectedFolderURL = url
            scanFolder(at: url)
        }
    }

    func scanFolder(at url: URL) {
        guard !isLoading else { return }
        isLoading = true
        Task {
            do {
                let items = try await scanner.scanFolder(at: url)
                await MainActor.run {
                    self.loops = self.mergeScannedItems(items)
                    self.isLoading = false
                    self.saveLibrary()
                    self.applyFilters()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("Scan error: \(error)")
                }
            }
        }
    }

    /// Keeps browser-downloaded loops when a folder scan would otherwise replace the library.
    /// Also preserves favorites / rating / tags for files that still exist on disk.
    private func mergeScannedItems(_ scanned: [LoopItem]) -> [LoopItem] {
        let downloadsPath = PersistenceManager.shared.downloadsDirectory.standardizedFileURL.path
        let existingByURL = Dictionary(
            loops.map { ($0.url.standardizedFileURL, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let mergedScanned = scanned.map { item -> LoopItem in
            var item = item
            if let existing = existingByURL[item.url.standardizedFileURL] {
                item.isFavorite = existing.isFavorite
                item.rating = existing.rating
                item.tags = existing.tags
            }
            return item
        }

        let scannedURLs = Set(mergedScanned.map { $0.url.standardizedFileURL })
        let uniqueDownloads = loops.filter { item in
            item.url.standardizedFileURL.path.hasPrefix(downloadsPath)
                && !scannedURLs.contains(item.url.standardizedFileURL)
        }
        return mergedScanned + uniqueDownloads
    }

    private func startWatchingFolder(at url: URL) {
        fileWatcher.delegate = self
        fileWatcher.startWatching(path: url.path)
    }

    private func setupSearchFilter() {
        $searchText
            .dropFirst()
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.applyFilters() }
            .store(in: &cancellables)

        $loops.dropFirst().sink { [weak self] _ in self?.applyFilters() }.store(in: &cancellables)
        $selectedTab.dropFirst().sink { [weak self] _ in self?.applyFilters() }.store(in: &cancellables)
        $selectedBPMRange.dropFirst().sink { [weak self] _ in self?.applyFilters() }.store(in: &cancellables)
        $selectedKey.dropFirst().sink { [weak self] _ in self?.applyFilters() }.store(in: &cancellables)
        $selectedTags.dropFirst().sink { [weak self] _ in self?.applyFilters() }.store(in: &cancellables)
        $sortOption.dropFirst().sink { [weak self] _ in self?.applyFilters() }.store(in: &cancellables)
    }

    func selectTab(_ tab: SidebarTab) {
        selectedTab = tab
        applyFilters()
    }

    func applyFilters() {
        var result = loops

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { item in
                item.displayName.lowercased().contains(query)
                    || item.fileName.lowercased().contains(query)
                    || (item.bpm != nil && String(item.bpm!).contains(query))
                    || item.key.rawValue.lowercased().contains(query)
                    || item.tags.contains { $0.name.lowercased().contains(query) }
            }
        }

        if let bpmRange = selectedBPMRange {
            result = result.filter { $0.bpm != nil && bpmRange.contains($0.bpm!) }
        }

        if let key = selectedKey, key != .unknown {
            result = result.filter { $0.key == key }
        }

        if !selectedTags.isEmpty {
            result = result.filter { item in
                selectedTags.allSatisfy { tag in
                    item.tags.contains { $0.name.lowercased() == tag.lowercased() }
                }
            }
        }

        switch selectedTab {
        case .allLoops:
            break
        case .favorites:
            result = result.filter { $0.isFavorite }
        case .recent:
            result = Array(
                result.sorted { $0.dateAdded > $1.dateAdded }
                    .prefix(LoopFileDrag.recentLimit)
            )
        case .collections:
            result = []
        }

        switch sortOption {
        case .name:
            result.sort { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        case .bpm:
            result.sort { ($0.bpm ?? 0) < ($1.bpm ?? 0) }
        case .key:
            result.sort { $0.key.rawValue < $1.key.rawValue }
        case .dateAdded:
            result.sort { $0.dateAdded > $1.dateAdded }
        case .rating:
            result.sort { $0.rating > $1.rating }
        case .duration:
            result.sort { $0.duration < $1.duration }
        }

        if filteredLoops != result {
            filteredLoops = result
        }
    }

    private func setupFileWatcher() {
        fileWatcher.delegate = self
    }

    @discardableResult
    func addLoopItem(from url: URL, switchToLibrary: Bool = true) async throws -> LoopItem {
        let (duration, sampleRate, channels, _) =
            try await metadataExtractor.validateAndExtract(from: url)

        let fileName = url.lastPathComponent
        let displayName = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        let format = LoopFormat(from: url)
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attrs[.size] as? Int64 ?? 0

        let bpm = metadataExtractor.parseBPM(from: fileName)
        let key = metadataExtractor.parseKey(from: fileName)

        let item = LoopItem(
            url: url,
            fileName: fileName,
            displayName: displayName,
            format: format,
            fileSize: fileSize,
            duration: duration,
            sampleRate: sampleRate,
            channels: channels,
            bpm: bpm,
            key: key,
            dateAdded: Date(),
            tags: [],
            rating: 0,
            isFavorite: false
        )

        return await MainActor.run {
            if let existingIndex = self.loops.firstIndex(where: {
                $0.url.standardizedFileURL == url.standardizedFileURL
            }) {
                let existing = self.loops[existingIndex]
                self.prepareLibraryVisibilityForNewItem()
                self.applyFilters()
                self.highlightAndShow(existing, switchToLibrary: switchToLibrary)
                return existing
            }

            self.loops.insert(item, at: 0)
            self.prepareLibraryVisibilityForNewItem()
            self.applyFilters()
            self.saveLibrary()
            self.highlightAndShow(item, switchToLibrary: switchToLibrary)
            return item
        }
    }

    @MainActor
    private func prepareLibraryVisibilityForNewItem() {
        searchText = ""
        selectedBPMRange = nil
        selectedKey = nil
        selectedTags = []
        selectedTab = .allLoops
        sortOption = .dateAdded
    }

    @MainActor
    private func highlightAndShow(_ item: LoopItem, switchToLibrary: Bool) {
        if switchToLibrary {
            currentMode = .library
        }

        highlightClearTask?.cancel()
        highlightedLoopID = item.id

        highlightClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            if highlightedLoopID == item.id {
                highlightedLoopID = nil
            }
        }
    }

    func toggleFavorite(for item: LoopItem) {
        if let index = loops.firstIndex(where: { $0.id == item.id }) {
            loops[index].isFavorite.toggle()
            saveLibrary()
            applyFilters()
        }
    }

    func toggleTag(_ tag: String, for item: LoopItem) {
        if let index = loops.firstIndex(where: { $0.id == item.id }) {
            if let tagIndex = loops[index].tags.firstIndex(where: { $0.name == tag }) {
                loops[index].tags.remove(at: tagIndex)
            } else {
                loops[index].tags.append(LoopTag(name: tag))
            }
            saveLibrary()
            applyFilters()
        }
    }

    func setRating(_ rating: Int, for item: LoopItem) {
        if let index = loops.firstIndex(where: { $0.id == item.id }) {
            loops[index].rating = rating
            saveLibrary()
            applyFilters()
        }
    }

    func addTag(_ tagName: String, for item: LoopItem) {
        if let index = loops.firstIndex(where: { $0.id == item.id }) {
            let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if !loops[index].tags.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
                loops[index].tags.append(LoopTag(name: trimmed))
                saveLibrary()
                applyFilters()
            }
        }
    }

    func removeTag(_ tag: LoopTag, from item: LoopItem) {
        if let index = loops.firstIndex(where: { $0.id == item.id }) {
            loops[index].tags.removeAll { $0.id == tag.id }
            saveLibrary()
            applyFilters()
        }
    }

    func deleteItem(_ item: LoopItem) {
        loops.removeAll { $0.id == item.id }
        saveLibrary()
        applyFilters()
    }
}

extension AppViewModel: FileWatcherDelegate {
    func fileWatcherDidDetectChanges() {
        // Auto-rescan disabled. Import folder is explicit only.
    }
}