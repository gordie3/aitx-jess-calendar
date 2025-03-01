# JESS Calendar Assistant

JESS Calendar Assistant is an AI-powered voice assistant application for iOS/macOS that helps you manage your calendar events through natural language conversations. The calendar is backed by Google Calendar.

## Features

- **Voice-Activated Calendar Management**: Create, update, and delete calendar events using natural language commands
- **Day Overview**: Get a summary of your scheduled events for a specific day
- **Visual Feedback**: Real-time visual feedback during voice interactions
- **Event Notifications**: Receive confirmation popups when events are created, updated, or deleted

### App Screenshots

<img width="302" alt="Screenshot 2025-03-01 at 12 43 31 PM" src="https://github.com/user-attachments/assets/ffb60652-38c5-428a-86c3-60a60565750b" />
<img width="307" alt="Screenshot 2025-03-01 at 12 43 50 PM" src="https://github.com/user-attachments/assets/c9ed7609-aded-4299-aa32-97def486124c" />


## Requirements

- iOS 16.0+ / macOS 13.0+
- Xcode 14.0+
- Swift 5.7+
- [Vapi](https://vapi.ai) API key

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/aitx-jess-calendar.git
   cd aitx-jess-calendar
   ```

2. Open the project in Xcode:
   ```bash
   open calendar-assistant.xcodeproj
   ```

3. Add your Vapi API key:
   - Open `ContentView.swift`
   - Replace `"your public key"` with your actual Vapi public key

4. Build and run the application on your device or simulator

## Usage

1. Launch the application
2. Tap the microphone button to start a conversation
3. Speak your calendar-related commands naturally, for example:
   - "Create a meeting with John tomorrow at 2 PM for one hour"
   - "Show me my schedule for next Monday"
   - "Delete my dentist appointment on Friday"
   - "Move my team meeting from Tuesday to Wednesday at the same time"

## Architecture

The application is built using SwiftUI and follows the MVVM architecture pattern:
- **Models**: `CalendarEvent`, `DayEvent`, etc.
- **Views**: `ContentView` and supporting UI components
- **View Models**: `CallManager` handles the business logic and state management

## Dependencies

- [Vapi](https://vapi.ai): Voice AI platform for natural language processing and conversation management
- SwiftUI: Apple's declarative UI framework
- Combine: For reactive programming and event handling

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Vapi](https://vapi.ai) for providing the voice AI platform
- Apple for SwiftUI and the iOS/macOS ecosystem
