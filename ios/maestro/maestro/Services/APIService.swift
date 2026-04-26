import Foundation

struct RecipeAPIResponse: Codable {
    struct RecipeData: Codable {
        let recipe_name: String
        let servings: Int?
        let ingredients: [IngredientData]
        let steps: [StepData]
        var recipeName: String { recipe_name }
    }
    struct IngredientData: Codable {
        let item: String
        let amount: String
    }
    struct StepData: Codable {
        let step_id: String
        let instruction: String
        let category: String
        let duration_minutes: Int?
        let requirements: RequirementsData?
        let concurrent_friendly: Bool?

        var stepId: String { step_id }
        var durationMinutes: Int? { duration_minutes }

        struct RequirementsData: Codable {
            let tools: [String]?
            let heat_source: String?
            let temp_celsius: Int?
        }
    }
    let recipe: RecipeData
    let source_url: String
}

actor APIService {
    static let shared = APIService()
    private let baseURL = "http://127.0.0.1:8000"

    func scrapeRecipe(from url: String) async throws -> (recipeName: String, ingredients: [Ingredient], steps: [Step]) {
        guard let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let requestURL = URL(string: "\(baseURL)/v1/scrape?url=\(encodedURL)&verbose=true") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(RecipeAPIResponse.self, from: data)

        var ingredients: [Ingredient] = []
        for ing in apiResponse.recipe.ingredients {
            ingredients.append(Ingredient(item: ing.item, amount: ing.amount))
        }

        var steps: [Step] = []
        for (index, step) in apiResponse.recipe.steps.enumerated() {
            let s = Step(
                stepId: step.stepId,
                instruction: step.instruction,
                category: step.category,
                durationMinutes: step.durationMinutes ?? 5,
                orderIndex: index
            )
            if let tools = step.requirements?.tools {
                s.tools = tools
            }
            s.heatSource = step.requirements?.heat_source
            s.tempCelsius = step.requirements?.temp_celsius
            s.concurrentFriendly = step.concurrent_friendly ?? true
            steps.append(s)
        }

        let recipeName = apiResponse.recipe.recipeName.isEmpty ? "Untitled Recipe" : apiResponse.recipe.recipeName
        return (
            recipeName: recipeName,
            ingredients: ingredients,
            steps: steps
        )
    }
}

struct ScheduleRequest: Codable {
    struct RecipeInput: Codable {
        let id: String
        let name: String
        let steps: [ScheduleStep]
    }
    struct ScheduleStep: Codable {
        let step_id: String
        let instruction: String
        let duration_minutes: Int
        let category: String
        let concurrent_friendly: Bool
        let dependencies: [String]
    }
    let recipes: [RecipeInput]
    let target_time: String?
}

struct ScheduleResponse: Codable {
    struct ScheduledStepData: Codable {
        let step_id: String
        let recipe_id: String
        let recipe_name: String
        let instruction: String
        let category: String
        let duration_minutes: Int
        let start_time: String
        let concurrent_friendly: Bool
    }
    let timeline: [ScheduledStepData]
}

actor ScheduleService {
    static let shared = ScheduleService()
    private let baseURL = "http://127.0.0.1:8000"

    func getSchedule(recipes: [(id: UUID, name: String, steps: [Step])], targetTime: Date? = nil) async throws -> ScheduleResponse {
        var requestBody: [[String: Any]] = []

        for recipe in recipes {
            let stepsData: [[String: Any]] = recipe.steps.map { step in
                [
                    "step_id": step.stepId,
                    "instruction": step.instruction,
                    "duration_minutes": step.durationMinutes,
                    "category": step.category,
                    "concurrent_friendly": step.concurrentFriendly,
                    "dependencies": []
                ]
            }

            requestBody.append([
                "id": recipe.id.uuidString,
                "name": recipe.name,
                "steps": stepsData
            ])
        }

        var bodyDict: [String: Any] = ["recipes": requestBody]
        if let targetTime = targetTime {
            let formatter = ISO8601DateFormatter()
            bodyDict["target_time"] = formatter.string(from: targetTime)
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: bodyDict) else {
            throw APIError.requestFailed
        }

        guard let requestURL = URL(string: "\(baseURL)/v1/schedule") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try JSONDecoder().decode(ScheduleResponse.self, from: data)
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed:
            return "Request failed. Is the server running?"
        }
    }
}