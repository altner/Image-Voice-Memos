import UniformTypeIdentifiers

enum SupportedImageTypes {
    static let extensions: Set<String> = [
        "jpg", "jpeg",
        "png",
        "tiff", "tif",
        "heic",
        "heif",
        "webp",
        "bmp",
        "gif",
        "nef",
        "raf",
        "orf", "ori",
        "dng",
        "cr2", "cr3",
        "arw"
    ]

    static let utTypes: [UTType] = {
        var types: [UTType] = [
            .jpeg, .png, .tiff, .heic, .heif, .webP, .bmp, .gif, .rawImage
        ]
        let additionalIdentifiers = [
            "com.nikon.raw-image",
            "com.fuji.raw-image",
            "com.olympus.raw-image",
            "com.adobe.raw-image",
            "com.canon.cr2-raw-image",
            "com.canon.cr3-raw-image",
            "com.sony.arw-raw-image"
        ]
        for id in additionalIdentifiers {
            if let t = UTType(id) { types.append(t) }
        }
        return types
    }()
}
