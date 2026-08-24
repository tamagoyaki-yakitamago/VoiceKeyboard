# VoiceKeyboard

**iPhone voice input and summary app**

## Overview
VoiceKeyboard is an iPhone app built with iOS 26+, Swift 6 and SwiftUI that assists with voice input and creating summary. It leverages on‑device speech recognition (`SpeechAnalyzer` / `SpeechTranscriber`) and Apple Intelligence to provide real‑time transcription, summarization, text polishing, and title generation.

## Features
- Start recording → real‑time transcription (volatile text)
- When recording stops, the interim transcription is finalized
- On devices that support Apple Intelligence, AI‑powered summarization, polishing, and title generation are available
- In environments where AI is unavailable (e.g., simulator), a simple fallback logic is used
- Automatic draft save/load using local JSON
- UI that guides the user to Settings when microphone permission is denied
- Accessibility support with `accessibilityIdentifier` and labels

## Architecture

## Project Structure
- **MVVM** pattern separating responsibilities into `Views/`, `ViewModels/`, `Models/`, and `Services/`
- **Swift Concurrency** (`async/await`, `Task`) with UI updates performed on `@MainActor`
- `AudioRecorder`, `SpeechService`, `AIService`, `FileStorageService` each handle recording, transcription, AI interaction, and persistence respectively
- Tests use **Swift Testing** and **XCTest UI**
- **Project layout**
  - `Views/` – SwiftUI view files
  - `ViewModels/` – UI logic and state management
  - `Models/` – data models (e.g., `Draft`)
  - `Services/` – audio recording, transcription, AI integration, persistence
  - `Tests/` – unit tests (`VoiceKeyboardTests`) and UI tests (`VoiceKeyboardUITests`)

## Requirements
- Xcode 15.x or later
- iOS 26+ (target devices)
- Swift 6, SwiftUI 5.5
- `Speech`, `AVFoundation`, `FoundationModels` (Apple Intelligence)

## Setup & Build
```bash
# Clone the repository
git clone https://github.com/yourname/VoiceKeyboard.git
cd VoiceKeyboard/VoiceKeyboard
# Open the Xcode project
open VoiceKeyboard.xcodeproj
```
1. In Xcode select the **VoiceKeyboard** scheme and choose a target device or simulator
2. Press `⌘B` to build and `⌘R` to run on a device or simulator

## Running Tests
```bash
# Unit & UI tests (code coverage enabled)
xcodebuild -project VoiceKeyboard.xcodeproj \
  -scheme VoiceKeyboard \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro,OS=latest" \
  clean test -enableCodeCoverage YES
```
- Unit tests are in `VoiceKeyboardTests` (Swift Testing)
- UI tests are in `VoiceKeyboardUITests` (XCTest) and verify that an alert appears after tapping `saveButton` indicating the draft was saved

## UI Test Guide
- UI elements under test have `accessibilityIdentifier` values (`recordButton`, `saveButton`)
- UI tests are launched with the `-UITestMode` flag; audio recording and AI calls are replaced with mocks (`MockAudioRecorder`, `MockAIService`)

## Accessibility
- All interactive elements have Japanese `accessibilityLabel` and a fixed `accessibilityIdentifier`
- VoiceOver reading order follows the `VStack`/`HStack` hierarchy

## License
MIT License – see the `LICENSE` file for details.
