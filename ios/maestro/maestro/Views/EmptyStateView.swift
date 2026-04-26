import SwiftUI

struct EmptyStateView: View {
    @Binding var showURLInput: Bool

    private let saladGradient = LinearGradient(
        colors: [Color(red: 0.35, green: 0.72, blue: 0.35), Color(red: 0.25, green: 0.55, blue: 0.25)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 1.0, blue: 0.96)

            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(saladGradient)
                        .frame(width: 140, height: 140)

                    Image(systemName: "fork.knife")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.9))
                }
                .shadow(color: Color(red: 0.3, green: 0.6, blue: 0.3).opacity(0.4), radius: 15, x: 0, y: 8)

                VStack(spacing: 12) {
                    Text("No Recipes Yet")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(red: 0.2, green: 0.3, blue: 0.2))

                    Text("Tap the button below to add your first recipe from the web")
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 0.35, green: 0.45, blue: 0.35))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Button {
                    showURLInput = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(saladGradient)
                            .shadow(color: Color(red: 0.3, green: 0.6, blue: 0.3).opacity(0.5), radius: 15, x: 0, y: 8)

                        Image(systemName: "plus")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(width: 140, height: 140)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    EmptyStateView(showURLInput: .constant(false))
}