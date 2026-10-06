import Foundation
import AVFoundation

final class LoopScanner {

    let metadataExtractor = MetadataExtractor()

    func scanFolder(at url: URL, recursive: Bool = true) async throws -> [LoopItem] {
        let supportedExtensions = Set([
            "wav", "aif", "aiff", "mp3", "flac", "aac", "m4a",
            "ogg", "oga", "caf", "aiff"
        ])

        let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
        guard resourceValues.isDirectory == true else { return [] }

        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: recursive ? [.skipsHiddenFiles, .skipsPackageDescendants] : [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        )

        var fileURLs: [URL] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                  resourceValues.isDirectory == false else { continue }
            guard supportedExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
            fileURLs.append(fileURL)
        }

        let sortedURLs = fileURLs.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        guard !sortedURLs.isEmpty else { return [] }

        var collected: [LoopItem] = []
        collected.reserveCapacity(sortedURLs.count)

        try await withThrowingTaskGroup(of: LoopItem?.self) { group in
            var iterator = sortedURLs.makeIterator()
            let limit = 4

            func enqueue(_ url: URL) {
                group.addTask {
                    try? await self.processFile(at: url)
                }
            }

            for _ in 0..<min(limit, sortedURLs.count) {
                if let url = iterator.next() { enqueue(url) }
            }

            for try await item in group {
                if let item { collected.append(item) }
                if let url = iterator.next() { enqueue(url) }
            }
        }

        return collected.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    private func processFile(at url: URL) async throws -> LoopItem {
        let fileName = url.deletingPathExtension().lastPathComponent
        let displayName = fileName.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        let format = LoopFormat(from: url)

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attrs[.size] as? Int64 ?? 0
        let modificationDate = attrs[.modificationDate] as? Date ?? Date()

        let (duration, sampleRate, channels, _) = await metadataExtractor.extractBasicMetadata(from: url)

        let bpm = MetadataExtractor().parseBPM(from: fileName)
        let key = MetadataExtractor().parseKey(from: fileName)

        return LoopItem(
            url: url,
            fileName: url.lastPathComponent,
            displayName: displayName,
            format: format,
            fileSize: fileSize,
            duration: duration,
            sampleRate: sampleRate,
            channels: channels,
            bpm: bpm,
            key: key,
            dateAdded: modificationDate,
            tags: [],
            rating: 0,
            isFavorite: false
        )
    }
}