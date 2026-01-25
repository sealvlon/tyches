import SwiftUI

struct CreateEventView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var deepLink: DeepLinkRouter
    @State private var currentStep = 0
    @State private var selectedMarket: MarketSummary?
    @State private var question = ""
    @State private var description = ""
    @State private var eventType = "binary"
    @State private var closesAt: Date = {
        // Default to 1 week from now at 8:00 PM (peak phone usage time in US)
        let calendar = Calendar.current
        let oneWeekFromNow = Date().addingTimeInterval(7 * 24 * 60 * 60)
        var components = calendar.dateComponents([.year, .month, .day], from: oneWeekFromNow)
        components.hour = 20 // 8:00 PM
        components.minute = 0
        return calendar.date(from: components) ?? oneWeekFromNow
    }()
    @State private var initialOdds: Double = 50
    @State private var outcomes: [OutcomeInput] = [
        OutcomeInput(label: "Option A", probability: 50),
        OutcomeInput(label: "Option B", probability: 50)
    ]
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var createdEventId: Int?
    
    struct OutcomeInput: Identifiable {
        let id = UUID()
        var label: String
        var probability: Int
    }
    
    let exampleQuestions = [
        "Will [person] [do thing] by [date]?",
        "Will we get a [pet] before [season]?",
        "Will [person] get the job at [company]?",
        "Will [project] launch by [deadline]?",
        "Will [person] move to [city] this year?"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator (dynamic based on event type)
                ProgressBar(currentStep: currentStep, totalSteps: eventType == "multiple" ? 7 : 6)
                    .padding()
                
                // Content
                TabView(selection: $currentStep) {
                    selectMarketStep.tag(0)
                    writeQuestionStep.tag(1)
                    descriptionStep.tag(2)
                    eventTypeStep.tag(3)
                    if eventType == "multiple" {
                        outcomesStep.tag(4)
                        resolutionStep.tag(5)
                        confirmationStep.tag(6)
                    } else {
                        resolutionStep.tag(4)
                        confirmationStep.tag(5)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                // Navigation buttons
                navigationButtons
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Event Created!", isPresented: $showSuccess) {
                Button("View Event") {
                    dismiss()
                    // Navigate to the created event via deep link
                    if let eventId = createdEventId {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            deepLink.routeToEvent(eventId: eventId)
                        }
                    }
                }
                Button("Create Another") {
                    resetForm()
                }
            } message: {
                Text("Your event is live! Friends can now place bets.")
            }
        }
    }
    
    // MARK: - Step 1: Select Market
    
    private var selectMarketStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Select a Market")
                .font(.title2.bold())
            
            Text("Which friend group is this prediction for?")
                .foregroundColor(.secondary)
            
            let markets = session.profile?.markets ?? []
            
            if markets.isEmpty {
                VStack(spacing: 16) {
                    Text("🎯")
                        .font(.system(size: 60))
                    Text("No markets yet")
                        .font(.headline)
                    Text("Create a market first to add events")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(markets) { market in
                            MarketSelectionCard(
                                market: market,
                                isSelected: selectedMarket?.id == market.id
                            ) {
                                selectedMarket = market
                                HapticManager.selection()
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Step 2: Write Question
    
    private var writeQuestionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's your prediction?")
                .font(.title2.bold())
            
            Text("Write a clear yes/no question")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Question input
            VStack(alignment: .trailing, spacing: 4) {
                TextField("e.g., Will Alex get the job?", text: $question, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(14)
                    .background(TychesTheme.cardBackground)
                    .cornerRadius(12)
                    .lineLimit(2...4)
                
                Text("\(question.count)/200")
                    .font(.caption2)
                    .foregroundColor(question.count > 200 ? TychesTheme.danger : .secondary)
            }
            
            // Example questions - compact horizontal scroll
            Text("Examples")
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(exampleQuestions, id: \.self) { example in
                        Button {
                            question = example
                            HapticManager.selection()
                        } label: {
                            Text(example)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(TychesTheme.cardBackground)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Step 3: Description (Optional)
    
    private var descriptionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add details")
                .font(.title2.bold())
                .padding(.top, 20)
            
            Text("Add description or rules to your event")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("e.g., This resolves YES if the offer is accepted by Dec 31...", text: $description, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(14)
                .background(TychesTheme.cardBackground)
                .cornerRadius(12)
                .lineLimit(3...6)
            
            Text("\(description.count)/500")
                .font(.caption2)
                .foregroundColor(description.count > 500 ? TychesTheme.danger : .secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            // Skip hint
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(TychesTheme.warning)
                Text("You can skip this step if your question is self-explanatory")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(TychesTheme.warning.opacity(0.1))
            .cornerRadius(10)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Step 4: Event Type
    
    private var eventTypeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Event Type")
                .font(.title2.bold())
                .padding(.top, 20)
            
            Text("Choose how friends can bet")
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                EventTypeCard(
                    title: "Binary (Yes/No)",
                    description: "Friends bet on YES or NO. Simple and clear.",
                    icon: "checkmark.circle.fill",
                    isSelected: eventType == "binary",
                    isEnabled: true
                ) {
                    eventType = "binary"
                    HapticManager.selection()
                }
                
                EventTypeCard(
                    title: "Multiple Choice",
                    description: "Friends bet on multiple outcomes.",
                    icon: "list.bullet.circle.fill",
                    isSelected: eventType == "multiple",
                    isEnabled: true
                ) {
                    eventType = "multiple"
                    HapticManager.selection()
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Step 5: Outcomes (Multiple Choice only)
    
    private var outcomesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Outcomes")
                .font(.title2.bold())
                .padding(.top, 20)
            
            Text("Add at least 2 possible outcomes")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(outcomes.indices, id: \.self) { index in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            TextField("Option \(index + 1)", text: $outcomes[index].label)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(TychesTheme.cardBackground)
                                .cornerRadius(10)
                            
                            if outcomes.count > 2 {
                                Button {
                                    outcomes.remove(at: index)
                                    redistributeProbabilities()
                                    HapticManager.selection()
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(TychesTheme.danger)
                                        .font(.title2)
                                }
                            }
                        }
                    }
                    
                    if outcomes.count < 6 {
                        Button {
                            outcomes.append(OutcomeInput(label: "", probability: 0))
                            redistributeProbabilities()
                            HapticManager.selection()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Outcome")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(TychesTheme.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(TychesTheme.primary.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func redistributeProbabilities() {
        let equalProb = 100 / max(outcomes.count, 1)
        for i in outcomes.indices {
            outcomes[i].probability = equalProb
        }
        // Adjust last one to make it sum to 100
        if !outcomes.isEmpty {
            let sum = outcomes.dropLast().reduce(0) { $0 + $1.probability }
            outcomes[outcomes.count - 1].probability = 100 - sum
        }
    }
    
    // MARK: - Step: Resolution
    
    private var resolutionStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("When does this close?")
                .font(.title2.bold())
                .padding(.top, 20)
            
            Text("Set when betting closes")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            DatePicker(
                "Closes at",
                selection: $closesAt,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .padding()
            .background(TychesTheme.cardBackground)
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Step: Confirmation
    
    private var confirmationStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Review & Create")
                    .font(.title2.bold())
                    .padding(.top, 10)
                
                // Preview card
                VStack(alignment: .leading, spacing: 12) {
                    // Market
                    if let market = selectedMarket {
                        HStack {
                            Text(market.avatar_emoji ?? "🎯")
                            Text(market.name)
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    // Question
                    Text(question)
                        .font(.headline)
                    
                    // Description
                    if !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Closes at
                    HStack {
                        Image(systemName: "clock")
                        Text("Closes \(closesAt.formatted(date: .abbreviated, time: .shortened))")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(TychesTheme.cardBackground)
                .cornerRadius(12)
                
                // Starting probability section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Starting odds")
                        .font(.subheadline.weight(.semibold))
                    
                    if eventType == "binary" {
                        // Binary: YES/NO slider
                        VStack(spacing: 8) {
                            Slider(value: $initialOdds, in: 1...99, step: 1)
                                .tint(TychesTheme.primary)
                            
                            HStack(spacing: 8) {
                                VStack {
                                    Text("YES")
                                        .font(.caption.bold())
                                    Text("\(Int(initialOdds))%")
                                        .font(.title3.bold())
                                }
                                .foregroundColor(TychesTheme.success)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(TychesTheme.success.opacity(0.1))
                                .cornerRadius(8)
                                
                                VStack {
                                    Text("NO")
                                        .font(.caption.bold())
                                    Text("\(100 - Int(initialOdds))%")
                                        .font(.title3.bold())
                                }
                                .foregroundColor(TychesTheme.danger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(TychesTheme.danger.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    } else {
                        // Multiple choice: show outcome probabilities
                        Text("Equal odds for all outcomes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        let validOutcomes = outcomes.filter { !$0.label.isEmpty }
                        let equalPercent = validOutcomes.isEmpty ? 0 : 100 / validOutcomes.count
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(validOutcomes) { outcome in
                                VStack(spacing: 4) {
                                    Text(outcome.label)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Text("\(equalPercent)%")
                                        .font(.subheadline.bold())
                                }
                                .foregroundColor(TychesTheme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(TychesTheme.primary.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .background(TychesTheme.cardBackground)
                .cornerRadius(12)
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(TychesTheme.danger)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(TychesTheme.danger.opacity(0.1))
                        .cornerRadius(10)
                }
                
                // Tokens bonus note
                HStack {
                    Image(systemName: "gift.fill")
                        .foregroundColor(TychesTheme.gold)
                    Text("You'll receive 5,000 tokens for creating this event!")
                        .font(.caption)
                        .foregroundColor(TychesTheme.gold)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(TychesTheme.gold.opacity(0.1))
                .cornerRadius(10)
            }
            .padding()
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation {
                        currentStep -= 1
                    }
                    HapticManager.selection()
                } label: {
                    Text("Back")
                        .font(.headline)
                        .foregroundColor(TychesTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(TychesTheme.primary.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            
            Button {
                if currentStep < lastStep {
                    withAnimation {
                        currentStep += 1
                    }
                    HapticManager.selection()
                } else {
                    createEvent()
                }
            } label: {
                HStack {
                    if isCreating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(currentStep < lastStep ? "Continue" : "Create Event")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canContinue ? TychesTheme.primaryGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                .cornerRadius(12)
            }
            .disabled(!canContinue || isCreating)
        }
        .padding()
    }
    
    private var lastStep: Int {
        eventType == "multiple" ? 6 : 5
    }
    
    private var canContinue: Bool {
        switch currentStep {
        case 0: return selectedMarket != nil
        case 1: return !question.isEmpty && question.count <= 200
        case 2: return true // Description is optional
        case 3: return true // Event type
        case 4:
            if eventType == "multiple" {
                // Outcomes step: need at least 2 valid outcomes
                let validOutcomes = outcomes.filter { !$0.label.isEmpty }
                return validOutcomes.count >= 2
            } else {
                // Resolution step for binary
                return closesAt > Date()
            }
        case 5:
            if eventType == "multiple" {
                // Resolution step for multiple
                return closesAt > Date()
            } else {
                // Confirmation for binary
                return true
            }
        case 6: return true // Confirmation for multiple
        default: return false
        }
    }
    
    private func createEvent() {
        guard let market = selectedMarket else { return }
        
        // Validate multiple choice outcomes
        if eventType == "multiple" {
            let validOutcomes = outcomes.filter { !$0.label.isEmpty }
            if validOutcomes.count < 2 {
                errorMessage = "Please add at least 2 outcomes"
                HapticManager.notification(.error)
                return
            }
        }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                let event: TychesAPI.CreateEventResponse
                
                if eventType == "multiple" {
                    let outcomeData = outcomes
                        .filter { !$0.label.isEmpty }
                        .map { TychesAPI.OutcomeData(label: $0.label, probability: $0.probability) }
                    
                    event = try await TychesAPI.shared.createEvent(
                        marketId: market.id,
                        title: question,
                        description: description.isEmpty ? nil : description,
                        eventType: eventType,
                        closesAt: closesAt,
                        outcomes: outcomeData
                    )
                } else {
                    event = try await TychesAPI.shared.createEvent(
                        marketId: market.id,
                        title: question,
                        description: description.isEmpty ? nil : description,
                        eventType: eventType,
                        closesAt: closesAt,
                        initialYesPercent: Int(initialOdds)
                    )
                }
                
                createdEventId = event.id
                
                // Refresh profile to get updated tokens
                await session.refreshProfile()
                
                MissionTracker.track(action: .eventCreated)
                HapticManager.notification(.success)
                showSuccess = true
            } catch let TychesError.server(msg) {
                errorMessage = msg
                HapticManager.notification(.error)
            } catch {
                errorMessage = "Failed to create event. Please try again."
                HapticManager.notification(.error)
            }
            
            isCreating = false
        }
    }
    
    private func resetForm() {
        currentStep = 0
        selectedMarket = nil
        question = ""
        description = ""
        eventType = "binary"
        closesAt = Date().addingTimeInterval(14 * 24 * 60 * 60)
        initialOdds = 50
        errorMessage = nil
    }
}

// MARK: - Supporting Views

struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Rectangle()
                    .fill(step <= currentStep ? TychesTheme.primaryGradient : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 4)
                    .cornerRadius(2)
            }
        }
    }
}

struct MarketSelectionCard: View {
    let market: MarketSummary
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(market.avatar_emoji ?? "🎯")
                    .font(.system(size: 32))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(market.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(market.members_count ?? 0) members · \(market.events_count ?? 0) events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(TychesTheme.primary)
                        .font(.title2)
                }
            }
            .padding()
            .background(TychesTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? TychesTheme.primary : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct EventTypeCard: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(isEnabled ? TychesTheme.primary : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(isEnabled ? .primary : .gray)
                        
                        if !isEnabled {
                            Text("SOON")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected && isEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(TychesTheme.primary)
                }
            }
            .padding()
            .background(TychesTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected && isEnabled ? TychesTheme.primary : Color.clear, lineWidth: 2)
            )
        }
        .disabled(!isEnabled)
    }
}

#Preview {
    CreateEventView()
        .environmentObject(SessionStore())
        .environmentObject(DeepLinkRouter())
}

