import SwiftUI
import SwiftData

struct OrchestratorView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allRecipes: [Recipe]
    let selectedRecipeIds: [UUID]

    @State private var timeline: [ScheduleResponse.ScheduledStepData] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var currentStepIndex = 0
    @State private var showAskChef = false

    private var selectedRecipes: [Recipe] {
        allRecipes.filter { selectedRecipeIds.contains($0.id) }
    }

    private var recipeColors: [String: Color] {
        let palette: [Color] = [
            Color(red: 0.4, green: 0.75, blue: 0.45),
            Color(red: 0.55, green: 0.65, blue: 0.95),
            Color(red: 0.95, green: 0.7, blue: 0.5),
            Color(red: 0.9, green: 0.85, blue: 0.4)
        ]
        var result: [String: Color] = [:]
        for (index, recipe) in selectedRecipes.enumerated() {
            result[recipe.id.uuidString] = palette[index % palette.count]
        }
        return result
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 1.0, blue: 0.96)
                .ignoresSafeArea()

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.4, green: 0.75, blue: 0.45)))
                    Text("Planning your cooking schedule...")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.5, green: 0.6, blue: 0.5))
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.5, green: 0.55, blue: 0.5))
                }
            } else {
                VStack(spacing: 0) {
                    header
                    recipePills

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(timeline.enumerated()), id: \.element.step_id) { index, step in
                                OrchestratorStepCard(
                                    step: step,
                                    isActive: index == currentStepIndex,
                                    recipeColor: recipeColors[step.recipe_id] ?? .green
                                )
                                .onTapGesture {
                                    if index > 0 {
                                        currentStepIndex = index
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }

            // Floating Ask Chef button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    askChefButton
                }
            }
            .padding(.bottom, 100)
        }
        .navigationBarHidden(true)
        .task {
            await loadSchedule()
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(red: 0.5, green: 0.6, blue: 0.5))
            }

            Spacer()

            Text("Orchestrator")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(red: 0.2, green: 0.3, blue: 0.2))

            Spacer()

            Button {
                // Save session
            } label: {
                Text("Save")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.75, blue: 0.45))
            }
        }
        .padding()
    }

    private var recipePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(selectedRecipes, id: \.id) { recipe in
                    if let color = recipeColors[recipe.id.uuidString] {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(color)
                                .frame(width: 10, height: 10)
                            Text(recipe.recipeName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.1))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(color.opacity(0.15))
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var askChefButton: some View {
        Button {
            showAskChef = true
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [Color(red: 0.4, green: 0.75, blue: 0.45), Color(red: 0.3, green: 0.6, blue: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: Color(red: 0.3, green: 0.6, blue: 0.3).opacity(0.4), radius: 8, x: 0, y: 4)

                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .frame(width: 60, height: 60)
        }
        .sheet(isPresented: $showAskChef) {
            AskChefSheet(
                recipeName: selectedRecipes.first?.recipeName,
                currentStep: timeline.indices.contains(currentStepIndex) ? timeline[currentStepIndex].instruction : nil,
                upcomingSteps: Array(timeline.dropFirst(currentStepIndex + 1).prefix(3).map { $0.instruction })
            )
        }
    }

    private func loadSchedule() async {
        isLoading = true
        errorMessage = nil

        do {
            let recipesData = selectedRecipes.map { recipe in
                (id: recipe.id, name: recipe.recipeName, steps: Array(recipe.steps))
            }

            let response = try await ScheduleService.shared.getSchedule(recipes: recipesData)
            timeline = response.timeline
        } catch {
            errorMessage = "Failed to generate schedule. Is the server running?"
        }

        isLoading = false
    }
}

struct OrchestratorStepCard: View {
    let step: ScheduleResponse.ScheduledStepData
    let isActive: Bool
    let recipeColor: Color

    var body: some View {
        HStack(spacing: 0) {
            // Left color border indicating recipe
            Rectangle()
                .fill(recipeColor)
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(step.category == "active" ? "ACTIVE" : "PASSIVE",
                          systemImage: step.category == "active" ? "flame.fill" : "clock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(step.category == "active" ? .white : recipeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(step.category == "active" ? Color.green : recipeColor.opacity(0.15))
                        .cornerRadius(6)

                    Text(formatTime(step.start_time))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(red: 0.5, green: 0.55, blue: 0.5))

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 12))
                        Text("\(step.duration_minutes)m")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color(red: 0.5, green: 0.55, blue: 0.5))
                }

                Text(step.instruction)
                    .font(.system(size: isActive ? 17 : 15))
                    .foregroundColor(isActive ? Color(red: 0.2, green: 0.15, blue: 0.1) : Color(red: 0.4, green: 0.45, blue: 0.4))
                    .lineLimit(isActive ? nil : 2)

                Text(step.recipe_name)
                    .font(.system(size: 12))
                    .foregroundColor(recipeColor.opacity(0.8))
            }
            .padding()
        }
        .background(Color.white)
        .cornerRadius(isActive ? 16 : 12)
        .overlay(
            RoundedRectangle(cornerRadius: isActive ? 16 : 12)
                .stroke(isActive ? recipeColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(isActive ? 0.1 : 0.05), radius: isActive ? 8 : 4, x: 0, y: 2)
    }

    private func formatTime(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: isoString) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        return isoString
    }
}

#Preview {
    OrchestratorView(selectedRecipeIds: [])
}