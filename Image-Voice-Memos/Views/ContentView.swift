import SwiftUI

struct ContentView: View {
    @EnvironmentObject var libraryVM: LibraryViewModel
    @EnvironmentObject var voiceMemoVM: VoiceMemoViewModel

    var body: some View {
        HSplitView {
            // Left pane: photo grid
            VStack(spacing: 0) {
                ToolbarView()
                Divider()
                PhotoGridView()
            }
            .frame(minWidth: 260, idealWidth: 320, maxWidth: 480)

            // Right pane: detail or empty state
            Group {
                if libraryVM.selectedItem != nil {
                    DetailView()
                } else {
                    EmptyStateView()
                }
            }
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            libraryVM.restoreBookmarkOnLaunch()
            voiceMemoVM.libraryViewModel = libraryVM
        }
    }
}
