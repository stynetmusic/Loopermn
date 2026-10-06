import Foundation

final class PersistenceManager {

    static let shared = PersistenceManager()

    private let libraryURL: URL
    private let metadataFileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        libraryURL = appSupport.appendingPathComponent("Loopermn", isDirectory: true)
        metadataFileURL = libraryURL.appendingPathComponent("library.json")

        try? FileManager.default.createDirectory(at: libraryURL, withIntermediateDirectories: true)
    }

    func saveLibrary(_ items: [LoopItem]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(items)
        try data.write(to: metadataFileURL, options: [.atomic])
    }

    func loadLibrary() throws -> [LoopItem] {
        guard FileManager.default.fileExists(atPath: metadataFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: metadataFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let items = try decoder.decode([LoopItem].self, from: data)
        return items
    }

    func saveItem(_ item: LoopItem) throws {
        var items = try loadLibrary()
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        try saveLibrary(items)
    }

    func deleteItem(_ item: LoopItem) throws {
        var items = try loadLibrary()
        items.removeAll { $0.id == item.id }
        try saveLibrary(items)
    }

    var libraryDirectory: URL {
        libraryURL
    }

    var downloadsDirectory: URL {
        libraryURL.appendingPathComponent("Downloads", isDirectory: true)
    }

    func ensureDownloadsDirectory() throws -> URL {
        let dir = downloadsDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}