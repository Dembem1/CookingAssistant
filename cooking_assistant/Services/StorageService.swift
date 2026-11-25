import Foundation
import UIKit
import FirebaseAuth
import Supabase

final class StorageService {

    static let shared = StorageService()

    private let bucketName = "recipe-images"

    private let client = SupabaseClient(
        supabaseURL: URL(
            string: "https://xfplksvuxtbhodnakium.supabase.co"
        )!,
        supabaseKey: "sb_publishable_w4kxZqHlh0xsxuDwYpJVjw_lHUezFEG",
        options: SupabaseClientOptions(
            auth: .init(
                accessToken: {
                    try await Auth.auth()
                        .currentUser?
                        .getIDToken()
                }
            )
        )
    )

    private init() {}

    // MARK: Upload Recipe Image
    func uploadRecipeImage(
        _ image: UIImage,
        userID: String,
        recipeDocumentID: String,
        instructionID: UUID? = nil
    ) async throws -> String {

        guard Auth.auth().currentUser?.uid == userID else {
            throw StorageServiceError.unauthorised
        }

        let resizedImage = resizeImage(
            image,
            maxDimension: 1200
        )

        guard let imageData = resizedImage.jpegData(
            compressionQuality: 0.75
        ) else {
            throw StorageServiceError.imageConversionFailed
        }

        guard imageData.count <= 5 * 1024 * 1024 else {
            throw StorageServiceError.imageTooLarge
        }

        // Generate a unique storage path.

        let path: String

        if let instructionID {

            path = "\(userID)/\(recipeDocumentID)/steps/\(instructionID.uuidString)/\(UUID().uuidString).jpg"

        } else {

            path = "\(userID)/\(recipeDocumentID)/main-\(UUID().uuidString).jpg"
        }

        let bucket = client.storage.from(bucketName)

        do {

            try await bucket.upload(
                path,
                data: imageData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: false
                )
            )

            let publicURL = try bucket.getPublicURL(
                path: path
            )

            return publicURL.absoluteString

        } catch {

            _ = try? await bucket.remove(
                paths: [path]
            )

            throw error
        }
    }

    // MARK: Delete Image

    func deleteImage(at imageURL: String) async throws {

        guard let url = URL(string: imageURL) else {
            throw StorageServiceError.invalidImageURL
        }

        guard url.scheme == "https",
              url.host == clientProjectHost else {
            throw StorageServiceError.invalidImageURL
        }

        let prefix =
            "/storage/v1/object/public/\(bucketName)/"

        guard url.path.hasPrefix(prefix) else {
            throw StorageServiceError.invalidImageURL
        }

        let path = String(
            url.path.dropFirst(prefix.count)
        )

        guard let userID = Auth.auth().currentUser?.uid,
              path.hasPrefix("\(userID)/") else {
            throw StorageServiceError.unauthorised
        }

        try await client.storage
            .from(bucketName)
            .remove(paths: [path])
    }
    
    // MARK: Delete All Recipe Images
    func deleteRecipeImages(
        for recipe: Recipe
    ) async -> [String] {

        var imageURLs = Set<String>()

        // Main recipe image.
        if let imageURL = recipe.imageURL {
            imageURLs.insert(imageURL)
        }

        // Instruction step images.
        for step in recipe.instructionSteps ?? [] {

            if let imageURL = step.imageURL {
                imageURLs.insert(imageURL)
            }
        }

        var failedURLs: [String] = []

        for imageURL in imageURLs {

            do {

                try await deleteImage(at: imageURL)

            } catch {

                failedURLs.append(imageURL)

                print("Could not delete recipe image:", error)
            }
        }

        return failedURLs
    }

    private var clientProjectHost: String? {

        URL(string: "https://xfplksvuxtbhodnakium.supabase.co")?.host
    }

    // MARK: Resize Image

    private func resizeImage(
        _ image: UIImage,
        maxDimension: CGFloat
    ) -> UIImage {

        let originalSize = image.size

        let largestDimension = max(
            originalSize.width,
            originalSize.height
        )

        guard largestDimension > 0 else {
            return image
        }

        let scale = min(
            1,
            maxDimension / largestDimension
        )

        let newSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(
            size: newSize,
            format: format
        )

        return renderer.image { _ in

            image.draw(
                in: CGRect(
                    origin: .zero,
                    size: newSize
                )
            )
        }
    }
}

// MARK: Storage Errors

enum StorageServiceError: LocalizedError {

    case imageConversionFailed
    case imageTooLarge
    case invalidImageURL
    case unauthorised

    var errorDescription: String? {

        switch self {

        case .imageConversionFailed:
            return "Could not process the selected image."

        case .imageTooLarge:
            return "The selected image is too large."

        case .invalidImageURL:
            return "Invalid recipe image URL."

        case .unauthorised:
            return "You do not have permission to manage this image."
        }
    }
}
