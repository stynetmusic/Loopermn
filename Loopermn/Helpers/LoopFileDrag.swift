import SwiftUI
import AppKit

enum LoopFileDrag {
    static let recentLimit = 20
}

/// Writes a real filesystem path so DAWs get the .wav/.mp3, not a webloc/alias.
final class AudioFilePasteboardWriter: NSObject, NSPasteboardWriting {
    let url: URL

    init(url: URL) {
        self.url = url.absoluteURL
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            .fileURL
        ]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .fileURL:
            return url.absoluteString
        case NSPasteboard.PasteboardType("NSFilenamesPboardType"):
            return [url.path]
        default:
            return nil
        }
    }
}

final class FileDragNSView: NSView, NSDraggingSource {
    var fileURL: URL?
    var onDraggingChanged: ((Bool) -> Void)?
    private var sessionActive = false

    override var isOpaque: Bool { false }

    /// Never steal clicks/hover from SwiftUI (play, heart, context menu).
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func startDragIfNeeded() {
        guard !sessionActive else { return }
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return }
        guard let event = NSApp.currentEvent else { return }
        guard event.type == .leftMouseDragged || event.type == .leftMouseDown else { return }

        let writer = AudioFilePasteboardWriter(url: url)
        let draggingItem = NSDraggingItem(pasteboardWriter: writer)
        let preview = Self.previewImage(for: url)
        let loc = convert(event.locationInWindow, from: nil)
        draggingItem.setDraggingFrame(
            NSRect(
                x: loc.x - 16,
                y: loc.y - preview.size.height / 2,
                width: preview.size.width,
                height: preview.size.height
            ),
            contents: preview
        )

        sessionActive = true
        onDraggingChanged?(true)
        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.draggingFormation = .none
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        guard let url = fileURL else { return }
        let pb = session.draggingPasteboard
        pb.setPropertyList([url.path], forType: NSPasteboard.PasteboardType("NSFilenamesPboardType"))
        pb.setString(url.absoluteString, forType: .fileURL)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        sessionActive = false
        onDraggingChanged?(false)
    }

    private static func previewImage(for url: URL) -> NSImage {
        let name = url.lastPathComponent as NSString
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textSize = name.size(withAttributes: attrs)
        let width = min(260, max(120, 48 + textSize.width))
        let size = NSSize(width: width, height: 40)

        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(calibratedWhite: 0.12, alpha: 0.96).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 8, yRadius: 8).fill()
        icon.draw(in: NSRect(x: 6, y: 4, width: 32, height: 32), from: .zero, operation: .sourceOver, fraction: 1)
        name.draw(
            in: NSRect(x: 42, y: 11, width: size.width - 50, height: 18),
            withAttributes: attrs
        )
        image.unlockFocus()
        return image
    }
}

final class FileDragStarter: ObservableObject {
    weak var view: FileDragNSView?

    func start() {
        view?.startDragIfNeeded()
    }
}

struct FileDragAttach: NSViewRepresentable {
    let url: URL
    let starter: FileDragStarter
    @Binding var isDragging: Bool

    func makeNSView(context: Context) -> FileDragNSView {
        let view = FileDragNSView()
        view.fileURL = url
        view.onDraggingChanged = { dragging in
            DispatchQueue.main.async { isDragging = dragging }
        }
        starter.view = view
        return view
    }

    func updateNSView(_ nsView: FileDragNSView, context: Context) {
        nsView.fileURL = url
        nsView.onDraggingChanged = { dragging in
            DispatchQueue.main.async { isDragging = dragging }
        }
        starter.view = nsView
    }
}

struct DAWFileDragModifier: ViewModifier {
    let url: URL
    var cornerRadius: CGFloat = AppTheme.cornerMd

    @StateObject private var starter = FileDragStarter()
    @State private var isDragging = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isDragging ? 0.98 : 1)
            .opacity(isDragging ? 0.88 : 1)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isDragging ? AppTheme.accent.opacity(0.7) : Color.clear, lineWidth: 1.5)
            )
            .background(
                FileDragAttach(url: url, starter: starter, isDragging: $isDragging)
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { _ in
                        starter.start()
                    }
            )
            .animation(.easeOut(duration: 0.12), value: isDragging)
    }
}

extension View {
    func dawFileDrag(url: URL, cornerRadius: CGFloat = AppTheme.cornerMd) -> some View {
        modifier(DAWFileDragModifier(url: url, cornerRadius: cornerRadius))
    }
}
