import Foundation

protocol FileWatcherDelegate: AnyObject {
    func fileWatcherDidDetectChanges()
}

final class FileWatcher {

    weak var delegate: FileWatcherDelegate?

    private var source: DispatchSourceFileSystemObject?
    private var debounceWork: DispatchWorkItem?
    private var ignoreUntil: Date = .distantPast
    private var isWatching = false

    deinit {
        stop()
    }

    func startWatching(path: String) {
        stop()

        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        // DispatchSource often fires once on resume — ignore that burst.
        ignoreUntil = Date().addingTimeInterval(3)

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.delete, .rename, .write],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            self?.scheduleNotify()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        self.source = source
        isWatching = true
    }

    private func scheduleNotify() {
        guard Date() >= ignoreUntil else { return }
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, Date() >= self.ignoreUntil else { return }
            DispatchQueue.main.async {
                self.delegate?.fileWatcherDidDetectChanges()
            }
        }
        debounceWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    func stop() {
        debounceWork?.cancel()
        debounceWork = nil
        source?.cancel()
        source = nil
        isWatching = false
    }
}