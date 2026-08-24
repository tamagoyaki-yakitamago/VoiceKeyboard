import AVFoundation
import Foundation
import Speech

enum SpeechServiceError: Error, CustomStringConvertible {
    case notAvailable
    case localeUnsupported
    case modelDownloadFailed
    case prepareFailed(Error)
    case startFailed(Error)

    var description: String {
        switch self {
        case .notAvailable:
            return "この端末では音声認識を利用できません。"
        case .localeUnsupported:
            return "日本語の音声認識がこの端末でサポートされていません。"
        case .modelDownloadFailed:
            return "音声認識モデルのダウンロードに失敗しました。"
        case .prepareFailed(let error):
            return "音声認識の準備に失敗しました: \(error.localizedDescription)"
        case .startFailed(let error):
            return "音声認識の開始に失敗しました: \(error.localizedDescription)"
        }
    }
}

protocol SpeechServiceDelegate: AnyObject, Sendable {
    @MainActor func speechService(_ service: SpeechService, didUpdateVolatileText text: String)
    @MainActor func speechService(_ service: SpeechService, didFinalizeText text: String)
    @MainActor func speechService(_ service: SpeechService, didEncounterError message: String)
}

extension SpeechServiceDelegate {
    @MainActor func speechService(_ service: SpeechService, didUpdateVolatileText text: String) {}
    @MainActor func speechService(_ service: SpeechService, didFinalizeText text: String) {}
}

actor SpeechService {

    nonisolated(unsafe) weak var delegate: SpeechServiceDelegate?

    private let locale = Locale(identifier: "ja-JP")
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var targetFormat: AVAudioFormat?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var isRunning = false

    func prepare() async throws {
        guard SpeechTranscriber.isAvailable else {
            throw SpeechServiceError.notAvailable
        }

        let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale)
        guard let supportedLocale else {
            throw SpeechServiceError.localeUnsupported
        }

        let module = SpeechTranscriber(locale: supportedLocale, preset: .progressiveTranscription)

        let status = await AssetInventory.status(forModules: [module])
        switch status {
        case .unsupported:
            throw SpeechServiceError.localeUnsupported
        case .supported:
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                do {
                    try await request.downloadAndInstall()
                } catch {
                    throw SpeechServiceError.modelDownloadFailed
                }
            }
        case .downloading:
            break
        case .installed:
            break
        @unknown default:
            break
        }

        targetFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [module],
            considering: nil
        ) ?? AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)

        transcriber = module
    }

    func start() async throws {
        guard let transcriber else {
            throw SpeechServiceError.prepareFailed(SpeechServiceError.notAvailable)
        }
        guard !isRunning else { return }

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = continuation

        let options = SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .whileInUse)
        let newAnalyzer = SpeechAnalyzer(modules: [transcriber], options: options)

        try await newAnalyzer.prepareToAnalyze(in: targetFormat)

        Task {
            try? await newAnalyzer.start(inputSequence: stream)
        }

        analyzer = newAnalyzer
        isRunning = true

        resultsTask = Task { [weak self] in
            await self?.consumeResults(from: transcriber)
        }
    }

    func stop() async {
        guard isRunning else { return }
        isRunning = false

        inputContinuation?.finish()
        inputContinuation = nil

        do {
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
        } catch {
            await delegate?.speechService(self, didEncounterError: "音声認識の確定に失敗しました: \(error.localizedDescription)")
        }

        resultsTask?.cancel()
        resultsTask = nil
        analyzer = nil
    }

    func reset() {
        inputContinuation?.finish()
        inputContinuation = nil
        resultsTask?.cancel()
        resultsTask = nil
        analyzer = nil
        transcriber = nil
        targetFormat = nil
        isRunning = false
    }

    private func consumeResults(from transcriber: SpeechTranscriber) async {
        do {
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                if result.isFinal {
                    await delegate?.speechService(self, didFinalizeText: text)
                } else {
                    await delegate?.speechService(self, didUpdateVolatileText: text)
                }
            }
        } catch is CancellationError {
            // キャンセルは無視する
        } catch {
            await delegate?.speechService(self, didEncounterError: "音声認識でエラーが発生しました: \(error.localizedDescription)")
        }
    }
}

extension SpeechService: AudioRecorderDelegate {

    nonisolated func audioRecorder(_ recorder: AudioRecorder, didReceive buffer: AVAudioPCMBuffer) {
        let input = AnalyzerInput(buffer: buffer)
        Task { await self.appendInput(input) }
    }

    nonisolated func audioRecorder(_ recorder: AudioRecorder, didFailWithError error: Error) {
        let message = (error as? AudioRecorderError)?.description
            ?? "録音でエラーが発生しました: \(error.localizedDescription)"
        Task { await self.reportError(message) }
    }
}

extension SpeechService {
    private func appendInput(_ input: AnalyzerInput) {
        guard isRunning else { return }

        guard let targetFormat else {
            inputContinuation?.yield(input)
            return
        }

        do {
            let converted = try convert(buffer: input.buffer, to: targetFormat)
            inputContinuation?.yield(AnalyzerInput(buffer: converted))
        } catch {
            Task {
                await delegate?.speechService(self, didEncounterError: "音声形式の変換に失敗しました: \(error.localizedDescription)")
            }
        }
    }

    private func reportError(_ message: String) async {
        await delegate?.speechService(self, didEncounterError: message)
    }

    private func convert(buffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat) throws -> AVAudioPCMBuffer {
        if buffer.format == targetFormat {
            return buffer
        }

        guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else {
            throw SpeechServiceError.prepareFailed(NSError(domain: "SpeechService", code: -1, userInfo: [NSLocalizedDescriptionKey: "コンバータを作成できません"]))
        }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity) else {
            throw SpeechServiceError.prepareFailed(NSError(domain: "SpeechService", code: -1, userInfo: [NSLocalizedDescriptionKey: "出力バッファを作成できません"]))
        }

        let context = ConversionContext(buffer: buffer)
        var error: NSError?
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if context.consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            context.consumed = true
            outStatus.pointee = .haveData
            return context.buffer
        }

        if let error {
            throw error
        }

        return outputBuffer
    }
}

private final class ConversionContext: @unchecked Sendable {
    nonisolated(unsafe) let buffer: AVAudioPCMBuffer
    nonisolated(unsafe) var consumed = false
    nonisolated init(buffer: AVAudioPCMBuffer) { self.buffer = buffer }
}
