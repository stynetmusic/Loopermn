import SwiftUI
import AVFoundation
import AppKit

@main
struct LoopermnApp: App {
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appViewModel)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1100, minHeight: 680)
                .onKeyPress(.space) {
                    if let _ = appViewModel.currentPlayerItem {
                        PlayerViewModel.shared.togglePlayPause()
                    }
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    if let item = appViewModel.currentPlayerItem,
                       let idx = appViewModel.filteredLoops.firstIndex(where: { $0.id == item.id }) {
                        PlayerViewModel.shared.playNext(from: appViewModel.filteredLoops, currentIndex: idx)
                    }
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    if let item = appViewModel.currentPlayerItem,
                       let idx = appViewModel.filteredLoops.firstIndex(where: { $0.id == item.id }) {
                        PlayerViewModel.shared.playPrevious(from: appViewModel.filteredLoops, currentIndex: idx)
                    }
                    return .handled
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 700)
        .commands {
            // Standard About uses Info.plist (CFBundleName / version / copyright).
            CommandGroup(replacing: .appInfo) {
                Button("About Loopermn") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Loopermn",
                        .applicationVersion: (
                            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                        ) ?? "1.0.0",
                        .version: (
                            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
                        ) ?? "1",
                        .credits: NSAttributedString(
                            string: (
                                Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
                            ) ?? "Copyright © 2026 Loopermn. Personal use.",
                            attributes: [
                                .foregroundColor: NSColor.secondaryLabelColor,
                                .font: NSFont.systemFont(ofSize: 11)
                            ]
                        )
                    ])
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("Import loop folder…") {
                    appViewModel.selectFolder()
                }
                .keyboardShortcut("O", modifiers: [.command])
            }
        }
    }
}