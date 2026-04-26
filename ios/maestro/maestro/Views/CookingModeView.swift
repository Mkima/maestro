import SwiftUI
import SwiftData
import Combine

struct CookingModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let recipe: Recipe

    @State private var currentStepIndex: Int = 0
    @State private var completedSteps: Set<Int> = []
    @State private var activeTimers: [Int: Int] = [:] // stepIndex -> remaining seconds
    @State private var showAskChef: Bool = false

    @State private var timerCancellable: AnyCancellable?

    @Query(filter: #Predicate<CookingSession> { $0.recipeId == nil },
           sort: \CookingSession.startedAt, order: .reverse)
    private var sessions: [CookingSession]

    private var sortedSteps: [Step] {
        recipe.steps.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var currentStep: Step? {
        guard currentStepIndex < sortedSteps.count else { return nil }
        return sortedSteps[currentStepIndex]
    }

    private var nextStep: Step? {
        let nextIndex = currentStepIndex + 1
        guard nextIndex < sortedSteps.count, !completedSteps.contains(nextIndex) else { return nil }
        return sortedSteps[nextIndex]
    }

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 1.0, blue: 0.96)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                activeTimersBar
                if let step = currentStep {
                    progressSection(step: step)
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // Previous completed steps (collapsed)
                                ForEach(previousCompletedIndices, id: \.self) { index in
                                    CollapsedStepCard(step: sortedSteps[index])
                                        .id(index)
                                }

                                VStack(spacing: 12) {
                                    // n-1 step (previous non-completed)
                                    if currentStepIndex > 0 && !completedSteps.contains(currentStepIndex - 1) {
                                        StepContextCard(
                                            step: sortedSteps[currentStepIndex - 1],
                                            label: "Previous",
                                            accentColor: .gray
                                        )
                                        .id(currentStepIndex - 1)
                                    }

                                    // Current step - highlighted
                                    if let activeStep = currentStep {
                                        ActiveStepCard(
                                            step: activeStep,
                                            isTimerRunning: activeTimers[currentStepIndex] != nil && (activeTimers[currentStepIndex] ?? 0) > 0,
                                            timerSeconds: activeTimers[currentStepIndex] ?? 0,
                                            onStartTimer: { startTimer(for: activeStep) },
                                            onStopTimer: { stopTimer(for: currentStepIndex) },
                                            onAddTime: { seconds in
                                                if let current = activeTimers[currentStepIndex] {
                                                    activeTimers[currentStepIndex] = current + seconds
                                                }
                                            }
                                        )
                                        .id(currentStepIndex)
                                    }

                                    // n+1 step (next non-completed)
                                    if let next = nextStep, !completedSteps.contains(currentStepIndex + 1) {
                                        StepContextCard(
                                            step: next,
                                            label: "Next",
                                            accentColor: .gray
                                        )
                                        .id(currentStepIndex + 1)
                                    }
                                }
                            }
                            .padding()
                        }
                        .onChange(of: currentStepIndex) { _, newValue in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                    }
                }

                navigationButtons
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
        .onAppear {
            restoreSession()
        }
        .onDisappear {
            saveSession()
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(red: 0.5, green: 0.6, blue: 0.5))
            }

            Spacer()

            Text(recipe.recipeName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(red: 0.2, green: 0.3, blue: 0.2))
                .lineLimit(1)

            Spacer()

            // Placeholder for symmetry
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.clear)
        }
        .padding()
    }

    private var activeTimersBar: some View {
        Group {
            if !activeTimers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(activeTimers.keys.sorted()), id: \.self) { stepIdx in
                            if let seconds = activeTimers[stepIdx] {
                                TimerPill(
                                    stepIndex: stepIdx,
                                    remainingSeconds: seconds,
                                    onStop: { stopTimer(for: stepIdx) }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(red: 0.95, green: 0.98, blue: 0.96))
            }
        }
    }

    private func progressSection(step: Step) -> some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Step \(currentStepIndex + 1) of \(sortedSteps.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.6, blue: 0.5))

                HStack(spacing: 4) {
                    Circle()
                        .fill(step.isActive ? Color.green : Color.blue)
                        .frame(width: 8, height: 8)
                    Text(step.category == "active" ? "ACTIVE" : "PASSIVE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(step.isActive ? .green : .blue)
                }
            }

            Spacer()

            if let remaining = activeTimers[currentStepIndex], remaining > 0 {
                Text(formatTime(remaining))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.3, green: 0.6, blue: 0.35))
            }
        }
        .padding(.horizontal)
    }

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            Button {
                goBack()
            } label: {
                HStack {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.system(size: 20))
                    Text("Back")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.4, green: 0.75, blue: 0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [Color.white], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.4, green: 0.75, blue: 0.45), lineWidth: 2)
                )
            }
            .disabled(currentStepIndex == 0)

            Button {
                markStepComplete()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                    Text(completedSteps.contains(currentStepIndex) ? "Completed" : "Done")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if completedSteps.contains(currentStepIndex) {
                            Color.gray
                        } else {
                            LinearGradient(colors: [Color(red: 0.4, green: 0.75, blue: 0.45), Color(red: 0.3, green: 0.6, blue: 0.35)], startPoint: .leading, endPoint: .trailing)
                        }
                    }
                )
                .cornerRadius(16)
            }

            Button {
                advanceToNext()
            } label: {
                HStack {
                    Text("Skip")
                        .font(.system(size: 18, weight: .semibold))
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                }
                .foregroundColor(Color(red: 0.4, green: 0.75, blue: 0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [Color.white], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.4, green: 0.75, blue: 0.45), lineWidth: 2)
                )
            }
            .disabled(currentStepIndex >= sortedSteps.count - 1)
        }
        .padding()
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
            AskChefSheet(recipeName: recipe.recipeName, currentStep: currentStep?.instruction, upcomingSteps: Array(sortedSteps.dropFirst(currentStepIndex + 1).map { $0.instruction }.prefix(3)))
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var previousCompletedIndices: [Int] {
        (0..<currentStepIndex).filter { completedSteps.contains($0) }
    }

    // MARK: - Actions

    private func startTimer(for step: Step) {
        activeTimers[currentStepIndex] = step.durationMinutes * 60
        ensureGlobalTimerRunning()
    }

    private func stopTimer(for stepIndex: Int) {
        activeTimers.removeValue(forKey: stepIndex)
        if activeTimers.isEmpty {
            timerCancellable?.cancel()
        }
    }

    private func ensureGlobalTimerRunning() {
        guard !activeTimers.isEmpty else { return }

        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                var allFinished = true
                for (key, value) in activeTimers {
                    if value > 0 {
                        activeTimers[key] = value - 1
                        allFinished = false
                    } else {
                        activeTimers.removeValue(forKey: key)
                    }
                }
                if allFinished || activeTimers.isEmpty {
                    timerCancellable?.cancel()
                }
            }
    }

    private func markStepComplete() {
        completedSteps.insert(currentStepIndex)
        if currentStepIndex < sortedSteps.count - 1 {
            advanceToNext()
        }
    }

    private func advanceToNext() {
        guard currentStepIndex < sortedSteps.count - 1 else { return }
        if activeTimers.isEmpty {
            timerCancellable?.cancel()
        }
        currentStepIndex += 1
    }

    private func goBack() {
        guard currentStepIndex > 0 else { return }
        if activeTimers.isEmpty {
            timerCancellable?.cancel()
        }
        currentStepIndex -= 1
    }

    // MARK: - Session Persistence

    private func saveSession() {
        let session = CookingSession(
            recipeId: recipe.id,
            orchestratorRecipeIds: [],
            currentStepIndex: currentStepIndex,
            completedSteps: Array(completedSteps),
            startedAt: Date(),
            isOrchestratorMode: false
        )

        modelContext.insert(session)
    }

    private func restoreSession() {
        guard let session = sessions.first(where: { $0.recipeId == recipe.id }) else { return }
        currentStepIndex = session.currentStepIndex
        completedSteps = Set(session.completedSteps)
    }
}

// MARK: - Step Cards

struct ActiveStepCard: View {
    let step: Step
    let isTimerRunning: Bool
    let timerSeconds: Int
    let onStartTimer: () -> Void
    let onStopTimer: () -> Void
    var onAddTime: ((Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(step.category == "active" ? "ACTIVE" : "PASSIVE", systemImage: step.isActive ? "flame.fill" : "clock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(step.isActive ? .white : .blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(step.isActive ? Color.green : Color.blue.opacity(0.2))
                    .cornerRadius(8)

                Spacer()

                if let heatSource = step.heatSource {
                    Label(heatSource.capitalized, systemImage: "thermometer")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.4))
                }
            }

            Text(step.instruction)
                .font(.system(size: 18))
                .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.1))
                .multilineTextAlignment(.leading)

            if !step.tools.isEmpty {
                HStack {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 12))
                    Text(step.tools.joined(separator: ", "))
                        .font(.system(size: 14))
                }
                .foregroundColor(Color(red: 0.5, green: 0.55, blue: 0.5))
            }

            Divider()

            HStack {
                if isTimerRunning {
                    Text(formatTime(timerSeconds))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.3, green: 0.6, blue: 0.35))

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: { onAddTime?(60) }) {
                            Text("+1m")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }

                        Button(action: { onAddTime?(300) }) {
                            Text("+5m")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }

                        Button(action: onStopTimer) {
                            Label("Stop", systemImage: "stop.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                } else {
                    Button(action: onStartTimer) {
                        Label("Start Timer", systemImage: "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(colors: [Color(red: 0.4, green: 0.75, blue: 0.45), Color(red: 0.3, green: 0.6, blue: 0.35)], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.5), lineWidth: 3)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct StepContextCard: View {
    let step: Step
    let label: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accentColor)
                    .cornerRadius(4)

                Spacer()

                if let heatSource = step.heatSource {
                    Text(heatSource.capitalized)
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.4))
                }
            }

            Text(step.instruction)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.6, green: 0.65, blue: 0.6))
                .lineLimit(3)

            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.5))
        .cornerRadius(12)
    }
}

struct PreviewStepCard: View {
    let step: Step

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 24, height: 24)
                .overlay(
                    Text("\(step.orderIndex + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                )

            Text(step.instruction)
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.5, green: 0.55, blue: 0.5))
                .lineLimit(2)

            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.7))
        .cornerRadius(12)
    }
}

struct CollapsedStepCard: View {
    let step: Step

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(red: 0.4, green: 0.75, blue: 0.45))

            Text(step.instruction)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.6, green: 0.65, blue: 0.6))
                .lineLimit(1)

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.5))
        .cornerRadius(10)
    }
}

struct TimerPill: View {
    let stepIndex: Int
    let remainingSeconds: Int
    let onStop: () -> Void
    
    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                // iOS 17+ with Tooltip support - simplified to avoid complex issues
                Button(action: onStop) {
                    HStack(spacing: 8) {
                        Text("\(stepIndex + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.green)
                            .cornerRadius(12)

                        Text(formatTimePill(remainingSeconds))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(red: 0.2, green: 0.3, blue: 0.2))

                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
            } else {
                // Fallback for older iOS versions
                Button(action: onStop) {
                    HStack(spacing: 8) {
                        Text("\(stepIndex + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.green)
                            .cornerRadius(12)

                        Text(formatTimePill(remainingSeconds))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(red: 0.2, green: 0.3, blue: 0.2))

                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
            }
        }
    }

    private func formatTimePill(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
