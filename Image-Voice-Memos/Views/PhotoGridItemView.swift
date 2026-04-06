import SwiftUI
import AppKit

struct PhotoGridItemView: View {
    let itemID: UUID
    let itemURL: URL
    let displayName: String
    let hasVoiceMemo: Bool
    let isSelected: Bool
    let onTap: () -> Void

    @EnvironmentObject var libraryVM: LibraryViewModel

    var currentItem: PhotoItem? {
        libraryVM.photoItems.first { $0.id == itemID }
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let thumb = currentItem?.thumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            Color(NSColor.controlBackgroundColor)
                            ProgressView()
                                .frame(width: 24, height: 24)
                        }
                    }
                }
                .frame(width: 120, height: 120)
                .clipped()
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.clear,
                            lineWidth: 2.5
                        )
                )

                if hasVoiceMemo {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Circle().fill(Color.accentColor))
                        .offset(x: -5, y: 5)
                }
            }

            Text(displayName)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(width: 120)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear {
            if currentItem?.thumbnail == nil {
                Task {
                    if let thumb = await libraryVM.imageLoadingService.loadThumbnail(url: itemURL, maxDimension: 300) {
                        await MainActor.run {
                            if let item = libraryVM.photoItems.first(where: { $0.id == itemID }) {
                                libraryVM.updateThumbnail(thumb, for: item)
                            }
                        }
                    }
                }
            }
        }
    }
}
