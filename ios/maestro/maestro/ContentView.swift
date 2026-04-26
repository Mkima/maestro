import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]

    @State private var isSelectMode = false
    @State private var selectedRecipes: Set<UUID> = []
    @State private var showURLInput = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color(red: 0.97, green: 1.0, blue: 0.96)
                    .ignoresSafeArea()

                if recipes.isEmpty {
                    EmptyStateView(showURLInput: $showURLInput)
                } else {
                    recipeList
                }
            }
            .navigationTitle("Maestro")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSelectMode ? "Done" : "Select") {
                        if isSelectMode {
                            if selectedRecipes.count >= 2 {
                                navigationPath.append(NavigationDestination.orchestrator(Array(selectedRecipes)))
                            }
                            isSelectMode = false
                            selectedRecipes.removeAll()
                        } else {
                            isSelectMode = true
                        }
                    }
                    .font(.system(size: 18))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showURLInput = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .cookingMode(let recipe):
                    CookingModeView(recipe: recipe)
                case .orchestrator(let ids):
                    OrchestratorView(selectedRecipeIds: ids)
                }
            }
        }
        .sheet(isPresented: $showURLInput) {
            URLInputSheetView()
        }
    }

    private var recipeList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(recipes) { recipe in
                    RecipeCard(
                        recipe: recipe,
                        isSelectMode: isSelectMode,
                        isSelected: selectedRecipes.contains(recipe.id)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isSelectMode {
                            toggleSelection(recipe)
                        } else {
                            navigationPath.append(NavigationDestination.cookingMode(recipe))
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            modelContext.delete(recipe)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func toggleSelection(_ recipe: Recipe) {
        if selectedRecipes.contains(recipe.id) {
            selectedRecipes.remove(recipe.id)
        } else {
            selectedRecipes.insert(recipe.id)
        }
    }
}

enum NavigationDestination: Hashable {
    case cookingMode(Recipe)
    case orchestrator([UUID])
}

struct RecipeCard: View {
    let recipe: Recipe
    let isSelectMode: Bool
    let isSelected: Bool

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.35, green: 0.72, blue: 0.35), Color(red: 0.25, green: 0.55, blue: 0.25)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        HStack(spacing: 16) {
            if isSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? Color(red: 0.3, green: 0.6, blue: 0.3) : .gray)
            }

            ZStack {
                Circle()
                    .fill(gradient)
                    .frame(width: 60, height: 60)

                Image(systemName: "fork.knife")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.recipeName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.2, green: 0.3, blue: 0.2))

                HStack(spacing: 8) {
                    Label("\(recipe.steps.count)", systemImage: "list.number")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    Label("\(recipe.ingredients.count)", systemImage: "leaf")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray.opacity(0.6))
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Recipe.self, inMemory: true)
}