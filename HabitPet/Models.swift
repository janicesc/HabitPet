//
//  Models.swift
//  HabitPet
//
//  Created by Janice C on 9/16/25.
//

import Foundation
import CoreGraphics

struct UserData {
    var name: String = ""
    var email: String = ""
    var age: String = ""
    var gender: String = ""          // added
    var height: String = ""
    var weight: String = ""
    var goal: String = ""
    var goalDuration: Int = 0
    var foodPreferences: [String] = []
    var notifications: Bool = false
    var selectedCharacter: CharacterType = .avatar

    // live-updating scales
    var heightScale: CGFloat = 1.0
    var weightScale: CGFloat = 1.0
}

struct FoodItem: Identifiable, Equatable {
    let id: Int
    let name: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fats: Double
    let category: String
    let usdaFood: USDAFood?
    
    init(
        id: Int,
        name: String,
        calories: Int,
        protein: Double,
        carbs: Double,
        fats: Double,
        category: String,
        usdaFood: USDAFood? = nil
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.category = category
        self.usdaFood = usdaFood
    }
    
    static func == (lhs: FoodItem, rhs: FoodItem) -> Bool {
        return lhs.id == rhs.id
    }
}

struct LoggedFood: Identifiable {
    let id = UUID()
    let food: FoodItem
    let portion: Double
    let timestamp: Date
}

enum AvatarState: String {
    case happy, neutral, sad, strong, overweight
}

// MARK: - Recipe Models
struct Recipe: Identifiable, Equatable {
    let id: String
    let title: String
    let imageName: String
    let prepTime: String
    let calories: Int
    let protein: Double
    let fat: Double
    let carbs: Double
    let category: RecipeCategory
    let tags: [String]
    let description: String
    let ingredients: [String]
    let instructions: [String]
}

enum RecipeCategory: String, CaseIterable {
    case mealPrep = "Meal Prep"
    case grocery = "Grocery"
    case restaurant = "Restaurant/Dining"
    case quickMeals = "Quick Meals"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Recipe Extension for Food Logging
extension Recipe {
    func toFoodItem() -> FoodItem {
        return FoodItem(
            id: Int(id) ?? 0,
            name: title,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fat,
            category: "Recipe"
        )
    }
}

// MARK: - Character Types
enum CharacterType: String, CaseIterable, Identifiable {
    case avoFriend = "Avo Friend"
    case bobaBuddy = "Boba Buddy"
    case berrySweet = "Berry Sweet"
    case squirtle = "Squirtle"
    case avatar = "HabitPet"
    case mochiMouse = "Mochi Mouse"
    
    var id: String { self.rawValue }
    
    var modelName: String {
        return self.rawValue.lowercased().replacingOccurrences(of: " ", with: "-")
    }
    
    var displayName: String {
        return self.rawValue
    }
    
    var description: String {
        switch self {
        case .avoFriend:
            return "A nutritious companion who loves healthy fats and green goodness"
        case .bobaBuddy:
            return "A sweet and bubbly friend who brings joy to your wellness journey"
        case .berrySweet:
            return "A delightful companion packed with antioxidants and natural sweetness"
        case .squirtle:
            return "A water-type Pokémon known for its friendly nature"
        case .avatar:
            return "A balanced companion for your health journey"
        case .mochiMouse:
            return "A soft and sweet companion who makes healthy eating fun"
        }
    }
    
    var emoji: String {
        switch self {
        case .avoFriend: return "🥑"
        case .bobaBuddy: return "🧋"
        case .berrySweet: return "🍓"
        case .squirtle: return "🐢"
        case .avatar: return "👤"
        case .mochiMouse: return "🐭"
        }
    }
    
    var imageName: String {
        switch self {
        case .avoFriend: return "avocado"
        case .bobaBuddy: return "boba"
        case .berrySweet: return "strawberry"
        case .squirtle: return "squirtle"
        case .avatar: return "habitpet"
        case .mochiMouse: return "MochiMouse"
        }
    }
}

