import SwiftUI
import Vapi
import Combine

// Add a new enum for event action types
enum EventActionType {
    case created
    case deleted
}

// Event model to store created calendar events
struct CalendarEvent {
    let name: String
    let startTime: String
    let endTime: String
    let actionType: EventActionType
}

// Add a new enum for popup types
enum PopupType {
    case eventAction(CalendarEvent)
    case dayOverview([DayEvent])
}

// Add a model for day events
struct DayEvent: Identifiable, Decodable {
    let id = UUID()
    let title: String
    let startTime: String
    let endTime: String
    let eventId: String
    
    enum CodingKeys: String, CodingKey {
        case title
        case startTime
        case endTime
        case eventId
    }
}

class CallManager: ObservableObject {
    enum CallState {
        case started, loading, ended
    }

    @Published var callState: CallState = .ended
    @Published var voiceAmplitude: CGFloat = 0.0
    @Published var createdEvent: CalendarEvent? = nil
    @Published var showEventPopup: Bool = false
    @Published var activePopup: PopupType? = nil
    @Published var showPopup: Bool = false
    
    var vapiEvents = [Vapi.Event]()
    private var cancellables = Set<AnyCancellable>()
    private var voiceTimer: Timer?
    private var popupTimer: Timer?
    let vapi: Vapi

    init() {
        vapi = Vapi(
            publicKey: "your public key"
        )
    }

    func setupVapi() {
        vapi.eventPublisher
            .sink { [weak self] event in
                self?.vapiEvents.append(event)
                switch event {
                case .callDidStart:
                    self?.callState = .started
                    self?.startVoiceAnimation()
                case .callDidEnd:
                    self?.callState = .ended
                    self?.stopVoiceAnimation()
                case .speechUpdate:
                    print("speechUpdate")
                case .conversationUpdate(let conversation):
                    print(conversation)
                    self?.checkForCreatedEvent(in: conversation)
                case .functionCall:
                    print("functionCall")
                case .hang:
                    print("hang")
                case .metadata:
                    print("metadata")
                case .transcript:
                    print("transcript")
                case .statusUpdate:
                    print("statusUpdate")
                case .modelOutput:
                    print("modelOutput")
                case .userInterrupted:
                    print("userInterrupted")
                case .voiceInput:
                    // Simulate voice amplitude changes based on voice input
                    self?.updateVoiceAmplitude()
                case .error(let error):
                    print("Error: \(error)")
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkForCreatedEvent(in conversation: ConversationUpdate) {
        // Check for event creation
        if let lastMessage = conversation.conversation.last,
           lastMessage.role == .tool {
            
            // Check for event creation/update
            if (lastMessage.content?.contains("successfully created event") == true || 
                lastMessage.content?.contains("succefully created event") == true ||
                lastMessage.content?.contains("Successfully updated event") == true),
               let toolCallId = lastMessage.tool_call_id {
                
                handleEventAction(toolCallId: toolCallId, conversation: conversation, actionType: .created)
            }
            // Check for event deletion
            else if lastMessage.content?.contains("successfully deleted event") == true,
                    let toolCallId = lastMessage.tool_call_id {
                
                handleEventAction(toolCallId: toolCallId, conversation: conversation, actionType: .deleted)
            }
            // Check for day overview
            else if let content = lastMessage.content,
                    let toolCallId = lastMessage.tool_call_id,
                    content.hasPrefix("[{") && content.hasSuffix("}]") {
                
                handleDayOverview(content: content)
            }
        }
    }
    
    private func handleDayOverview(content: String) {
        // Parse the JSON array of events
        if let jsonData = content.data(using: .utf8) {
            do {
                let events = try JSONDecoder().decode([DayEvent].self, from: jsonData)
                if !events.isEmpty {
                    DispatchQueue.main.async {
                        self.activePopup = .dayOverview(events)
                        self.showPopup = true
                        
                        // Set timer to hide popup after 15 seconds (longer for overview)
                        self.popupTimer?.invalidate()
                        self.popupTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                            self?.showPopup = false
                        }
                    }
                }
            } catch {
                print("Error parsing day overview: \(error)")
            }
        }
    }
    
    private func handleEventAction(toolCallId: String, conversation: ConversationUpdate, actionType: EventActionType) {
        // Find the assistant message with the matching tool call
        if let assistantMessage = conversation.conversation.first(where: { msg in
            if let toolCalls = msg.tool_calls {
                return toolCalls.contains(where: { $0.id == toolCallId })
            }
            return false
        }) {
            // Extract event details from the function call arguments
            if let toolCalls = assistantMessage.tool_calls,
               let functionCall = toolCalls.first(where: { $0.id == toolCallId })?.function {
                
                // Parse the JSON arguments to extract event details
                if let jsonData = functionCall.arguments.data(using: .utf8),
                   let args = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    
                    var eventName = "Event Details"
                    var startTime = "Unknown"
                    var endTime = "Unknown"
                    
                    if actionType == .created {
                        eventName = args["event_name"] as? String ?? "Event Details"
                        
                        // Parse start and end dates
                        if let startDateStr = args["start_date"] as? String {
                            startTime = formatDateString(startDateStr)
                        }
                        
                        if let endDateStr = args["end_date"] as? String {
                            endTime = formatDateString(endDateStr)
                        }
                    } else if actionType == .deleted {
                        // For deletion, we might just have an event_id, but try to get name if available
                        eventName = args["event_name"] as? String ?? "Event"
                    }
                    
                    // Create and show the event popup
                    DispatchQueue.main.async {
                        let event = CalendarEvent(
                            name: eventName, 
                            startTime: startTime, 
                            endTime: endTime,
                            actionType: actionType
                        )
                        self.activePopup = .eventAction(event)
                        self.showPopup = true
                        
                        // Set timer to hide popup after 8 seconds
                        self.popupTimer?.invalidate()
                        self.popupTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
                            self?.showPopup = false
                        }
                    }
                }
            }
        }
    }
    
    // Helper function to format date strings from ISO format to a more readable format
    private func formatDateString(_ dateString: String) -> String {
        // Example input: "2025-03-02 01:00-0600"
        // Extract just the time part for simplicity
        let components = dateString.components(separatedBy: " ")
        if components.count >= 2 {
            let timePart = components[1].prefix(5) // Get "01:00" from "01:00-0600"
            
            // Convert 24-hour format to 12-hour format with AM/PM
            if let hour = Int(timePart.prefix(2)) {
                let minute = timePart.suffix(2)
                let period = hour >= 12 ? "PM" : "AM"
                let hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
                return "\(hour12):\(minute) \(period)"
            }
            return String(timePart)
        }
        return dateString
    }
    
    private func startVoiceAnimation() {
        voiceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateVoiceAmplitude()
        }
    }
    
    private func stopVoiceAnimation() {
        voiceTimer?.invalidate()
        voiceTimer = nil
        voiceAmplitude = 0.0
    }
    
    private func updateVoiceAmplitude() {
        DispatchQueue.main.async {
            self.voiceAmplitude = CGFloat.random(in: 0.2...1.0)
        }
    }

    @MainActor
    func handleCallAction() async {
        if callState == .ended {
            await startCall()
        } else {
            endCall()
        }
    }

    @MainActor
    func startCall() async {
        callState = .loading
        do {
            try await vapi.start(assistantId: "your-assistant-id")
        } catch {
            print("Error starting call: \(error)")
            callState = .ended
        }
    }

    func endCall() {
        vapi.stop()
    }
}

struct EventPopupView: View {
    let event: CalendarEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.actionType == .created ? "Event Details" : "Event Deleted")
                .font(.headline)
                .foregroundColor(.white)
            
            Divider()
                .background(Color.white.opacity(0.5))
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.white)
                Text(event.name)
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
            
            if event.actionType == .created {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.white)
                    Text("\(event.startTime) - \(event.endTime)")
                        .foregroundColor(.white)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(event.actionType == .created ? Color.blue.opacity(0.9) : Color.red.opacity(0.9))
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// Day Overview Popup View
struct DayOverviewPopupView: View {
    let events: [DayEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's Schedule")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(events.count) events")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Divider()
                .background(Color.white.opacity(0.5))
            
            if events.isEmpty {
                Text("No events scheduled")
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.vertical, 10)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(events) { event in
                            EventRow(event: event)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 250)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.indigo.opacity(0.9))
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct EventRow: View {
    let event: DayEvent
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Time column
            VStack(alignment: .leading) {
                Text(formatTimeForDisplay(event.startTime))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Text(formatTimeForDisplay(event.endTime))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(width: 70, alignment: .leading)
            
            // Vertical line
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 2)
                .padding(.vertical, 4)
            
            // Event details
            Text(event.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    // Format time string for display (extract just the time part)
    private func formatTimeForDisplay(_ timeString: String) -> String {
        let components = timeString.components(separatedBy: " ")
        if components.count >= 2 {
            return components[1]
        }
        return timeString
    }
}

struct ContentView: View {
    @StateObject private var callManager = CallManager()
    @State private var rotation: Double = 0.0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                // Top half - Voice visualization
                Spacer()
                
                if callManager.callState == .started {
                    VoiceVisualization(amplitude: callManager.voiceAmplitude)
                } else {
                    // Placeholder for visualization area when not active
                    Circle()
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                        .frame(width: 200, height: 200)
                }
                
                Spacer()
                
                // Bottom half - Action button
                ZStack {
                    // Pulsing blue circle for loading state
                    if callManager.callState == .loading {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 180, height: 180)
                            .scaleEffect(pulseScale)
                            .opacity(Double(2.0 - pulseScale) / 2.0)
                            .onAppear {
                                withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                                    pulseScale = 1.5
                                }
                            }
                    }
                    
                    Button(action: {
                        Task {
                            await callManager.handleCallAction()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(callManager.buttonColor)
                                .frame(width: 120, height: 120)
                                .shadow(color: callManager.buttonColor.opacity(0.7), radius: 15, x: 0, y: 0)
                            
                            if callManager.callState == .loading {
                                // Loading spinner
                                Circle()
                                    .trim(from: 0, to: 0.7)
                                    .stroke(Color.white, lineWidth: 4)
                                    .frame(width: 100, height: 100)
                                    .rotationEffect(Angle(degrees: rotation))
                                    .onAppear {
                                        withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                                            rotation = 360
                                        }
                                    }
                            } else {
                                // Button icon
                                Image(systemName: callManager.callState == .ended ? "mic.fill" : "stop.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .disabled(callManager.callState == .loading)
                }
                
                Spacer()
            }
            .padding()
            
            // Popup area
            VStack {
                if callManager.showPopup, let popup = callManager.activePopup {
                    switch popup {
                    case .eventAction(let event):
                        EventPopupView(event: event)
                            .animation(.spring(), value: callManager.showPopup)
                    case .dayOverview(let events):
                        DayOverviewPopupView(events: events)
                            .animation(.spring(), value: callManager.showPopup)
                    }
                }
                Spacer()
            }
            .padding(.top)
        }
        .onAppear {
            callManager.setupVapi()
        }
        .onDisappear {
            pulseScale = 1.0
        }
    }
}

struct VoiceVisualization: View {
    let amplitude: CGFloat
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Multiple circles with different opacities and sizes
            ForEach(0..<5) { i in
                Circle()
                    .stroke(Color.cyan.opacity(0.7 - Double(i) * 0.15), lineWidth: 2)
                    .scaleEffect(amplitude * (1.0 + 0.3 * CGFloat(i)))
                    .opacity(isAnimating ? 0.8 : 0.2)
            }
            
            // Vertical bars for voice visualization
            HStack(spacing: 4) {
                ForEach(0..<20) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.cyan)
                        .frame(width: 4, height: 10 + 40 * amplitude * (sin(CGFloat(i) * 0.3) + 1) / 2)
                        .opacity(0.7)
                }
            }
        }
        .frame(width: 300, height: 300)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

extension CallManager {
    var callStateText: String {
        switch callState {
        case .started: return "Listening..."
        case .loading: return "Connecting..."
        case .ended: return "Ready"
        }
    }

    var callStateColor: Color {
        switch callState {
        case .started: return Color.cyan
        case .loading: return Color.orange
        case .ended: return Color.indigo
        }
    }

    var buttonText: String {
        callState == .loading ? "Loading..." : (callState == .ended ? "Start Call" : "End Call")
    }

    var buttonColor: Color {
        switch callState {
        case .loading: return Color.gray
        case .ended: return Color.green
        case .started: return Color.red
        }
    }
}

#Preview {
    ContentView()
}
