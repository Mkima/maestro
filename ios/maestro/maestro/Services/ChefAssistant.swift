import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: String  // "user" or "assistant"
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

actor ChefAssistantService {
    static let shared = ChefAssistantService()
    private let baseURL = "http://127.0.0.1:8000"

    func ask(question: String, recipeName: String?, currentStep: String?, upcomingSteps: [String]) async throws -> String {
        guard let requestURL = URL(string: "\(baseURL)/v1/ask-chef") else {
            throw ChefError.invalidURL
        }

        var context: [String: Any] = [:]
        if let recipeName = recipeName {
            context["recipe_name"] = recipeName
        }
        if let currentStep = currentStep {
            context["current_step"] = currentStep
        }
        if !upcomingSteps.isEmpty {
            context["upcoming_steps"] = upcomingSteps
        }

        let requestBody: [String: Any] = [
            "question": question,
            "context": context
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw ChefError.requestFailed
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ChefError.requestFailed
        }

        struct AskChefResponse: Codable {
            let answer: String?
            let error: String?
        }

        let decoded = try JSONDecoder().decode(AskChefResponse.self, from: data)

        if let answer = decoded.answer {
            return answer
        } else if let error = decoded.error {
            throw ChefError.serverError(error)
        } else {
            throw ChefError.noResponse
        }
    }
}

enum ChefError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case noResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed:
            return "Request failed"
        case .noResponse:
            return "No response from chef"
        case .serverError(let message):
            return message
        }
    }
}