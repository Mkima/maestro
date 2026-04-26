import SwiftUI
import SwiftData

struct URLInputSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var viewContext

    @State private var urlText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 1.0, blue: 0.96)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.4, green: 0.75, blue: 0.45), Color(red: 0.3, green: 0.6, blue: 0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Add Recipe from URL")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(red: 0.2, green: 0.3, blue: 0.2))

                    VStack(spacing: 16) {
                        TextField("Paste recipe URL here", text: $urlText)
                            .font(.system(size: 18))
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.go)
                            .onSubmit { Task { await scrapeRecipe() } }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 24)

                    Button {
                        Task { await scrapeRecipe() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 22))
                                Text("Scrape Recipe")
                                    .font(.system(size: 20, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            urlText.isEmpty || isLoading
                                ? LinearGradient(colors: [Color.gray], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color(red: 0.4, green: 0.75, blue: 0.45), Color(red: 0.3, green: 0.6, blue: 0.35)], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                    }
                    .disabled(urlText.isEmpty || isLoading)
                    .padding(.horizontal, 24)

                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 18))
                }
            }
        }
    }

    private func scrapeRecipe() async {
        guard !urlText.isEmpty else { return }

        print("DEBUG: Starting scrape for URL: \(urlText)")
        isLoading = true
        errorMessage = nil

        do {
            let result = try await APIService.shared.scrapeRecipe(from: urlText)
            print("DEBUG: Scrape succeeded, recipe name: \(result.recipeName), ingredients: \(result.ingredients.count), steps: \(result.steps.count)")

            var saveSuccess = false
            await MainActor.run {
                // Create the full recipe with all relationships
                let newRecipe = Recipe(
                    recipeName: result.recipeName,
                    sourceURL: urlText
                )
                print("DEBUG: Created newRecipe with id: \(newRecipe.id)")

                // Add ingredients and steps to the recipe FIRST before inserting
                for ingredient in result.ingredients {
                    newRecipe.ingredients.append(ingredient)
                }
                for step in result.steps {
                    newRecipe.steps.append(step)
                }

                print("DEBUG: newRecipe has \(newRecipe.ingredients.count) ingredients and \(newRecipe.steps.count) steps")

                viewContext.insert(newRecipe)
                print("DEBUG: After insert, modelContext.hasChanges: \(viewContext.hasChanges)")
            }

            await MainActor.run {
                do {
                    try viewContext.save()
                    print("DEBUG: Context saved successfully")
                    
                    let descriptor = FetchDescriptor<Recipe>()
                    if let allRecipes = try? viewContext.fetch(descriptor) {
                        print("DEBUG: Found \(allRecipes.count) recipes in context after save")
                        for r in allRecipes {
                            print("DEBUG:   - Recipe: \(r.recipeName), ingredients: \(r.ingredients.count), steps: \(r.steps.count)")
                        }
                    } else {
                        print("DEBUG: Failed to fetch any recipes")
                    }
                    saveSuccess = true
                } catch {
                    print("DEBUG: Save error: \(error)")
                }
            }

            if saveSuccess {
                try? await Task.sleep(nanoseconds: 300_000_000)
                await MainActor.run {
                    dismiss()
                }
            }
        } catch {
            print("DEBUG: Scrape error: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }
}

#Preview {
    URLInputSheetView()
        .modelContainer(for: Recipe.self, inMemory: true)
}