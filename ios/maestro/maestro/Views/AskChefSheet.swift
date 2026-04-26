import SwiftUI

struct AskChefSheet: View {
    @Environment(\.dismiss) private var dismiss
    let recipeName: String?
    let currentStep: String?
    let upcomingSteps: [String]

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 1.0, blue: 0.96)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(messages) { message in
                                    ChatBubble(message: message)
                                        .id(message.id)
                                }
                            }
                            .padding()
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let lastMessage = messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }

                    inputBar
                }
            }
            .navigationTitle("Ask the Chef")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask about cooking...", text: $inputText)
                .font(.system(size: 16))
                .padding(12)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(red: 0.4, green: 0.75, blue: 0.45), Color(red: 0.3, green: 0.6, blue: 0.35)], startPoint: .bottomLeading, endPoint: .topTrailing)
                    )
            }
            .disabled(inputText.isEmpty || isLoading)
        }
        .padding()
        .background(Color.white.opacity(0.9))
    }

    private func sendMessage() async {
        guard !inputText.isEmpty else { return }

        let userMessage = ChatMessage(role: "user", content: inputText)
        messages.append(userMessage)
        inputText = ""
        isLoading = true

        do {
            let answer = try await ChefAssistantService.shared.ask(
                question: userMessage.content,
                recipeName: recipeName,
                currentStep: currentStep,
                upcomingSteps: upcomingSteps
            )
            let assistantMessage = ChatMessage(role: "assistant", content: answer)
            messages.append(assistantMessage)
        } catch {
            let errorMessage = ChatMessage(role: "assistant", content: "Sorry, I couldn't process your question. Please try again.")
            messages.append(errorMessage)
        }

        isLoading = false
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool {
        message.role == "user"
    }

    var body: some View {
        HStack {
            if isUser { Spacer() }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(isUser ? "You" : "👨‍🍳 Chef")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.55, blue: 0.5))

                Text(message.content)
                    .font(.system(size: 16))
                    .foregroundColor(isUser ? .white : Color(red: 0.2, green: 0.15, blue: 0.1))
                    .padding(12)
                    .background(
                        Group {
                            if isUser {
                                LinearGradient(colors: [Color(red: 0.4, green: 0.75, blue: 0.45), Color(red: 0.3, green: 0.6, blue: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            } else {
                                Color.white
                            }
                        }
                    )
                    .cornerRadius(16)
            }

            if !isUser { Spacer() }
        }
    }
}

#Preview {
    AskChefSheet(recipeName: "Oven Assado", currentStep: "Sear the meat in a hot pan", upcomingSteps: ["Cut vegetables"])
}