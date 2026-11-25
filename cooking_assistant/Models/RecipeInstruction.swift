import Foundation

nonisolated struct RecipeInstruction: Identifiable, Codable, Sendable {
    let id: UUID
    var text: String
    var imageURL: String?

    init(
        id: UUID = UUID(),
        text: String,
        imageURL: String? = nil
    ) {
        self.id = id
        self.text = text
        self.imageURL = imageURL
    }
}
