import Combine
import Foundation

protocol AIServiceProtocol {
    static var isAvailable: Bool { get }
    func summarize(_ text: String) async throws -> String
    func refine(_ text: String) async throws -> String
    func generateTitle(_ text: String) async throws -> String
}

extension AIService: AIServiceProtocol {}

@MainActor
final class VoiceDraftViewModel: ObservableObject {
    private let isUITestMode: Bool = ProcessInfo.processInfo.arguments.contains("-UITestMode")

    enum RecordingState: Equatable {
        case idle
        case recording
    }

    enum UIState: Equatable {
        case idle
        case loading
        case processing(String)
        case permissionDenied
        case error(String)
    }

    @Published var recordingState: RecordingState = .idle
    @Published var volatileText: String = ""
    @Published var finalText: String = ""
    @Published var uiState: UIState = .idle
    var isBusy: Bool {
        if case .loading = uiState { return true }
        if case .processing(_) = uiState { return true }
        return false
    }

    private var audioRecorder: AudioRecorder = AudioRecorder()
    private var speechService: SpeechService = SpeechService()
    private var aiService: AIServiceProtocol = AIService()
    private var storage: FileStorageService = FileStorageService()
    private var drafts: [Draft] = []
    // Currently running AI task (summarize / refine / generate title). Cancelable to avoid overlapping work.
    private var currentTask: Task<Void, Never>? = nil

    init() {
        audioRecorder.delegate = speechService
        speechService.delegate = self
        // Load saved drafts and set the latest content
        drafts = storage.loadDrafts()
        if let latest = drafts.sorted(by: { $0.updatedAt > $1.updatedAt }).first {
            finalText = latest.content
        }
    }

    func toggleRecording() {
        switch recordingState {
        case .idle:
            Task { await startRecording() }
        case .recording:
            Task { await stopRecording() }
        }
    }

    func saveCurrentDraft() async {
        let draft = Draft(content: finalText)
        do {
            try storage.saveDraft(draft)
            if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
                drafts[index] = draft
            } else {
                drafts.append(draft)
            }
        } catch {
            setError("保存に失敗しました: \(error.localizedDescription)")
        }
    }

    func summarizeText() {
        // Cancel any previous AI task
        currentTask?.cancel()
        uiState = .processing("要約中…")
        currentTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let result = try await self.aiService.summarize(self.finalText)
                await MainActor.run {
                    self.finalText = result
                    self.uiState = .idle
                }
            } catch is CancellationError {
                // Task was cancelled – keep current state
            } catch let error as AIService.AIServiceError {
                await MainActor.run { self.setError(error.description) }
            } catch {
                await MainActor.run { self.setError("要約に失敗しました: \(error.localizedDescription)") }
            }
            await MainActor.run { self.currentTask = nil }
        }
    }

    func refineText() {
        currentTask?.cancel()
        uiState = .processing("整文中…")
        currentTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let result = try await self.aiService.refine(self.finalText)
                await MainActor.run {
                    self.finalText = result
                    self.uiState = .idle
                }
            } catch is CancellationError {
                // ignore
            } catch let error as AIService.AIServiceError {
                await MainActor.run { self.setError(error.description) }
            } catch {
                await MainActor.run { self.setError("整文に失敗しました: \(error.localizedDescription)") }
            }
            await MainActor.run { self.currentTask = nil }
        }
    }

    func generateTitle() {
        currentTask?.cancel()
        uiState = .processing("タイトル生成中…")
        currentTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let result = try await self.aiService.generateTitle(self.finalText)
                await MainActor.run {
                    self.finalText = result
                    self.uiState = .idle
                }
            } catch is CancellationError {
                // ignore
            } catch let error as AIService.AIServiceError {
                await MainActor.run { self.setError(error.description) }
            } catch {
                await MainActor.run { self.setError("タイトル生成に失敗しました: \(error.localizedDescription)") }
            }
            await MainActor.run { self.currentTask = nil }
        }
    }

    func setError(_ message: String) {
        uiState = .error(message)
        recordingState = .idle
    }

    func clearError() {
        uiState = .idle
    }

    private func startRecording() async {
        uiState = .loading

        let granted = await audioRecorder.requestPermission()
        guard granted else {
            uiState = .permissionDenied
            recordingState = .idle
            return
        }

        do {
            try await speechService.prepare()
            try await speechService.start()
            try await audioRecorder.startRecording()
            recordingState = .recording
            uiState = .idle
        } catch let error as SpeechServiceError {
            setError(error.description)
        } catch let error as AudioRecorderError {
            setError(error.description)
            await speechService.reset()
        } catch {
            setError("録音・音声認識の開始に失敗しました: \(error.localizedDescription)")
            await speechService.reset()
        }
    }

    private func stopRecording() async {
        await audioRecorder.stopRecording()
        await speechService.stop()
        recordingState = .idle
        uiState = .idle
    }
}

extension VoiceDraftViewModel: SpeechServiceDelegate {

    func speechService(_ service: SpeechService, didUpdateVolatileText text: String) {
        volatileText = text
    }

    func speechService(_ service: SpeechService, didFinalizeText text: String) {
        finalText += (finalText.isEmpty ? "" : "\n") + text
        volatileText = ""
    }

    func speechService(_ service: SpeechService, didEncounterError message: String) {
        setError(message)
    }
}
