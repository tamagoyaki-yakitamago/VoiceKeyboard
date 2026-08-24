import AVFoundation
import Foundation

enum AudioRecorderError: Error, CustomStringConvertible {
    case permissionDenied
    case alreadyRecording
    case notRecording
    case sessionSetupFailed(Error)
    case audioFormatUnsupported
    case engineStartFailed(Error)

    var description: String {
        switch self {
        case .permissionDenied:
            return "マイクの使用が許可されていません。設定アプリから許可してください。"
        case .alreadyRecording:
            return "既に録音中です。"
        case .notRecording:
            return "録音が開始されていません。"
        case .sessionSetupFailed(let error):
            return "音声セッションの準備に失敗しました: \(error.localizedDescription)"
        case .audioFormatUnsupported:
            return "マイクの音声形式がこの端末でサポートされていません。"
        case .engineStartFailed(let error):
            return "録音エンジンの起動に失敗しました: \(error.localizedDescription)"
        }
    }
}

protocol AudioRecorderDelegate: AnyObject {
    nonisolated func audioRecorder(_ recorder: AudioRecorder, didReceive buffer: AVAudioPCMBuffer)
    nonisolated func audioRecorder(_ recorder: AudioRecorder, didFailWithError error: Error)
}

extension AudioRecorderDelegate {
    nonisolated func audioRecorder(_ recorder: AudioRecorder, didFailWithError error: Error) {}
}

final class AudioRecorder: @unchecked Sendable {

    nonisolated(unsafe) weak var delegate: AudioRecorderDelegate?

    nonisolated private let queue = DispatchQueue(label: "com.tamagoyaki.VoiceKeyboard.AudioRecorder")
    nonisolated(unsafe) private var engine: AVAudioEngine?
    nonisolated(unsafe) private var isRecording = false

    nonisolated func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    nonisolated func startRecording() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                do {
                    try self.startRecordingOnQueue()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    nonisolated func stopRecording() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { [weak self] in
                self?.stopRecordingOnQueue()
                continuation.resume()
            }
        }
    }

    nonisolated private func startRecordingOnQueue() throws {
        guard !isRecording else {
            throw AudioRecorderError.alreadyRecording
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setPreferredSampleRate(16000)
            try session.setActive(true)
        } catch {
            throw AudioRecorderError.sessionSetupFailed(error)
        }

        let newEngine = AVAudioEngine()
        let inputNode = newEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: inputFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioRecorderError.audioFormatUnsupported
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.delegate?.audioRecorder(self, didReceive: buffer)
        }

        do {
            try newEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioRecorderError.engineStartFailed(error)
        }

        engine = newEngine
        isRecording = true
    }

    nonisolated private func stopRecordingOnQueue() {
        guard isRecording else { return }

        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
        isRecording = false

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            delegate?.audioRecorder(self, didFailWithError: error)
        }
    }
}
