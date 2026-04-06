import SwiftUI

@main
struct ImageVoiceMemosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var libraryVM = LibraryViewModel()
    @StateObject private var voiceMemoVM = VoiceMemoViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(libraryVM)
                .environmentObject(voiceMemoVM)
                .frame(minWidth: 800, minHeight: 500)
                .onDisappear {
                    libraryVM.releaseFolder()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .newItem) {
                Button("Open Folder…") {
                    libraryVM.openFolder()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
