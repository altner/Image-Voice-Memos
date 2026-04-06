import Foundation
import AppKit
import ImageIO

actor ImageLoadingService {
    private let thumbnailCache = NSCache<NSString, NSImage>()

    init() {
        thumbnailCache.countLimit = 500
        thumbnailCache.totalCostLimit = 200 * 1024 * 1024  // 200 MB
    }

    func loadThumbnail(url: URL, maxDimension: Int = 300) async -> NSImage? {
        let key = url.absoluteString as NSString
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceShouldCacheImmediately: false
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let image = NSImage(cgImage: cgImage, size: .zero)
        thumbnailCache.setObject(image, forKey: key)
        return image
    }

    func loadFullResolution(url: URL) async -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceShouldAllowFloat: false
        ]

        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: .zero)
    }

    func clearCache() {
        thumbnailCache.removeAllObjects()
    }
}
