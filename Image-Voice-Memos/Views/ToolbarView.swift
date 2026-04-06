import SwiftUI

struct ToolbarView: View {
    @EnvironmentObject var libraryVM: LibraryViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: Controls
            HStack(spacing: 6) {
                Button {
                    libraryVM.openFolder()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .help("Open Folder")

                if !libraryVM.photoItems.isEmpty {
                    Text("Images: \(libraryVM.photoItems.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("Filter", selection: Binding(
                    get: { libraryVM.noteFilter },
                    set: { libraryVM.setFilter($0) }
                )) {
                    ForEach(NoteFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .labelsHidden()

                Picker("Sort", selection: Binding(
                    get: { libraryVM.sortOrder },
                    set: { libraryVM.setSortOrder($0) }
                )) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .labelsHidden()
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Row 2: Folder path
            if let url = libraryVM.folderURL {
                HStack {
                    Text(url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}
