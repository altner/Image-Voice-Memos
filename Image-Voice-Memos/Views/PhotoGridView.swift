import SwiftUI

struct PhotoGridView: View {
    @EnvironmentObject var libraryVM: LibraryViewModel

    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 8)]

    var body: some View {
        Group {
            if libraryVM.isLoading {
                VStack {
                    ProgressView("Loading Photos…")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if libraryVM.photoItems.isEmpty && libraryVM.folderURL != nil {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Photos Found")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(libraryVM.photoItems) { item in
                            PhotoGridItemView(
                                itemID: item.id,
                                itemURL: item.url,
                                displayName: item.displayName,
                                hasVoiceMemo: item.hasVoiceMemo,
                                isSelected: libraryVM.selectedItem?.id == item.id,
                                onTap: { libraryVM.selectedItem = item }
                            )
                        }
                    }
                    .padding(8)
                }
            }
        }
    }
}
