import SwiftUI

struct EmptyStateView: View {
    @EnvironmentObject var libraryVM: LibraryViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
            Text("No Folder Selected")
                .font(.title2.weight(.medium))
            Text("Open a folder with photos to get started.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Folder…") {
                libraryVM.openFolder()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
