import Foundation

enum PantryCategory: String, CaseIterable, Codable, Identifiable {

    case fruits
    case vegetables
    case nutsAndSeeds
    case dairy
    case meat
    case fishAndSeafood
    case bakery
    case sweets
    case grainsAndPasta
    case spicesSaucesAndOil
    case drinks
    case frozen
    case other

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .fruits:
            return "Fruits & Berries"
        case .vegetables:
            return "Vegetables & Greens"
        case .nutsAndSeeds:
            return "Nuts & Seeds"
        case .dairy:
            return "Dairy & Eggs"
        case .meat:
            return "Meat"
        case .fishAndSeafood:
            return "Fish & Seafood"
        case .bakery:
            return "Bakery & Bread"
        case .sweets:
            return "Sweets"
        case .grainsAndPasta:
            return "Grains & Pasta"
        case .spicesSaucesAndOil:
            return "Spices, Sauces & Oil"
        case .drinks:
            return "Drinks"
        case .frozen:
            return "Frozen"
        case .other:
            return "Other"
        }
    }
}
