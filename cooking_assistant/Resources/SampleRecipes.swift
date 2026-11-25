import Foundation

enum SampleRecipes {

    static let all: [Recipe] = [

        Recipe(
            id: 1,
            title: "Creamy Tomato Pasta",
            readyInMinutes: 25,
            diets: ["vegetarian"],
            imageURL: nil,
            servings: 2,
            ingredients: [
                Ingredient(name: "pasta", amount: 200, unit: "g"),
                Ingredient(name: "tomatoes", amount: 2, unit: ""),
                Ingredient(name: "cream", amount: 100, unit: "ml"),
                Ingredient(name: "garlic cloves", amount: 2, unit: ""),
                Ingredient(name: "salt and pepper", amount: 1, unit: "to taste")
            ],
            instructions: [
                "Cook the pasta according to the package instructions.",
                "Chop the tomatoes and garlic.",
                "Heat a little oil in a pan and cook the garlic and tomatoes.",
                "Add the cream and season with salt and pepper.",
                "Mix the sauce with the cooked pasta and serve."
            ],
            nutrition: NutritionInfo(
                calories: 420,
                protein: 14,
                fat: 16,
                carbs: 55
            )
        ),

        Recipe(
            id: 2,
            title: "Fresh Vegetable Bowl",
            readyInMinutes: 15,
            diets: ["vegan", "vegetarian"],
            imageURL: nil,
            servings: 2,
            ingredients: [
                Ingredient(name: "cucumber", amount: 1, unit: ""),
                Ingredient(name: "tomatoes", amount: 2, unit: ""),
                Ingredient(name: "avocado", amount: 1, unit: ""),
                Ingredient(name: "lettuce", amount: 100, unit: "g"),
                Ingredient(name: "olive oil", amount: 1, unit: "tbsp"),
                Ingredient(name: "lemon juice", amount: 1, unit: "to taste")
            ],
            instructions: [
                "Wash and chop the vegetables.",
                "Slice the avocado.",
                "Place all ingredients in a bowl.",
                "Add olive oil and lemon juice, then mix gently."
            ],
            nutrition: NutritionInfo(
                calories: 280,
                protein: 6,
                fat: 18,
                carbs: 25
            )
        ),

        Recipe(
            id: 3,
            title: "Chicken Rice Bowl",
            readyInMinutes: 30,
            diets: [],
            imageURL: nil,
            servings: 2,
            ingredients: [
                Ingredient(name: "chicken breast", amount: 150, unit: "g"),
                Ingredient(name: "rice", amount: 100, unit: "g"),
                Ingredient(name: "pepper", amount: 1, unit: ""),
                Ingredient(name: "olive oil", amount: 1, unit: "tbsp"),
                Ingredient(name: "salt and pepper", amount: 1, unit: "to taste")
            ],
            instructions: [
                "Cook the rice according to the package instructions.",
                "Cut the chicken and pepper into pieces.",
                "Heat oil in a pan and cook the chicken thoroughly.",
                "Add the pepper and cook until softened.",
                "Serve the chicken and vegetables over the rice."
            ],
            nutrition: NutritionInfo(
                calories: 450,
                protein: 32,
                fat: 12,
                carbs: 48
            )
        ),

        Recipe(
            id: 4,
            title: "Mushroom Risotto",
            readyInMinutes: 35,
            diets: ["vegetarian"],
            imageURL: nil,
            servings: 2,
            ingredients: [
                Ingredient(name: "risotto rice", amount: 150, unit: "g"),
                Ingredient(name: "mushrooms", amount: 150, unit: "g"),
                Ingredient(name: "onion", amount: 1, unit: "small"),
                Ingredient(name: "vegetable stock", amount: 500, unit: "ml"),
                Ingredient(name: "Parmesan", amount: 30, unit: "g"),
                Ingredient(name: "olive oil", amount: 1, unit: "tbsp")
            ],
            instructions: [
                "Chop the onion and mushrooms.",
                "Heat oil in a pan and cook the onion until soft.",
                "Add the mushrooms and cook for a few minutes.",
                "Add the rice and stir well.",
                "Gradually add the vegetable stock, stirring until the rice is creamy and cooked.",
                "Stir in the Parmesan and serve."
            ],
            nutrition: NutritionInfo(
                calories: 390,
                protein: 12,
                fat: 13,
                carbs: 54
            )
        )
    ]
}
