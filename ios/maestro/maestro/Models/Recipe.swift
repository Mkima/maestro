import Foundation
import SwiftData

@Model
final class Recipe {
    var id: UUID
    var recipeName: String
    var servings: Int
    var sourceURL: String
    var imageURL: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade) var ingredients: [Ingredient]
    @Relationship(deleteRule: .cascade) var steps: [Step]

    init(
        id: UUID = UUID(),
        recipeName: String,
        servings: Int = 4,
        sourceURL: String,
        imageURL: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.recipeName = recipeName
        self.servings = servings
        self.sourceURL = sourceURL
        self.imageURL = imageURL
        self.createdAt = createdAt
        self.ingredients = []
        self.steps = []
    }
}

@Model
final class Ingredient {
    var id: UUID
    var item: String
    var amount: String

    @Relationship(inverse: \Recipe.ingredients) var recipe: Recipe?

    init(item: String, amount: String) {
        self.id = UUID()
        self.item = item
        self.amount = amount
    }
}

@Model
final class Step {
    var id: UUID
    var stepId: String
    var instruction: String
    var category: String
    var durationMinutes: Int
    var orderIndex: Int

    // Extended properties from API (stored as JSON string)
    var toolsData: String?
    var heatSource: String?
    var tempCelsius: Int?
    var concurrentFriendly: Bool = true

    @Relationship(inverse: \Recipe.steps) var recipe: Recipe?

    init(
        stepId: String,
        instruction: String,
        category: String = "active",
        durationMinutes: Int = 5,
        orderIndex: Int = 0
    ) {
        self.id = UUID()
        self.stepId = stepId
        self.instruction = instruction
        self.category = category
        self.durationMinutes = durationMinutes
        self.orderIndex = orderIndex
        self.toolsData = nil
        self.heatSource = nil
        self.tempCelsius = nil
        self.concurrentFriendly = true
    }

    var tools: [String] {
        get {
            guard let data = toolsData,
                  let items = try? JSONDecoder().decode([String].self, from: Data(data.utf8)) else {
                return []
            }
            return items
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                toolsData = string
            }
        }
    }

    var isActive: Bool {
        category == "active"
    }
}

@Model
final class CookingSession {
    @Attribute(.unique) var id: UUID
    var recipeId: UUID?
    var orchestratorRecipeIds: [UUID]
    var currentStepIndex: Int
    var completedStepsData: String
    var startedAt: Date
    var targetFinishTime: Date?
    var isOrchestratorMode: Bool

    init(
        id: UUID = UUID(),
        recipeId: UUID? = nil,
        orchestratorRecipeIds: [UUID] = [],
        currentStepIndex: Int = 0,
        completedSteps: [Int] = [],
        startedAt: Date = Date(),
        targetFinishTime: Date? = nil,
        isOrchestratorMode: Bool = false
    ) {
        self.id = id
        self.recipeId = recipeId
        self.orchestratorRecipeIds = orchestratorRecipeIds
        self.currentStepIndex = currentStepIndex
        self.completedStepsData = "[]"
        self.startedAt = startedAt
        self.targetFinishTime = targetFinishTime
        self.isOrchestratorMode = isOrchestratorMode

        if let data = try? JSONEncoder().encode(completedSteps),
           let string = String(data: data, encoding: .utf8) {
            self.completedStepsData = string
        }
    }

    var completedSteps: [Int] {
        get {
            guard let data = completedStepsData.data(using: .utf8),
                  let items = try? JSONDecoder().decode([Int].self, from: data) else {
                return []
            }
            return items
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                completedStepsData = string
            }
        }
    }

    var isActive: Bool {
        currentStepIndex > 0 || !completedSteps.isEmpty
    }
}