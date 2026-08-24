import SwiftUI

struct MainView: View {
    @State private var showSaveAlert = false

    @StateObject private var viewModel = VoiceDraftViewModel()
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                statusView
                editorSection
                // Apple Intelligence 操作ボタン（利用可能時）
                if AIService.isAvailable {
                    HStack(spacing: 12) {
                        Button("要約") { viewModel.summarizeText() }.accessibilityLabel("要約")
                        Button("整文") { viewModel.refineText() }.accessibilityLabel("整文")
                        Button("タイトル生成") { viewModel.generateTitle() }.accessibilityLabel("タイトル生成")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isBusy)
                }
                Spacer()
                if horizontalSizeClass == .regular {
                    HStack(spacing: 12) {
                        recordButton
                        saveButton
                    }
                } else {
                    VStack(spacing: 12) {
                        recordButton
                        saveButton
                    }
                }
            }
            .padding()
            .alert("保存しました", isPresented: $showSaveAlert) {
                Button("OK", role: .cancel) {}
            }
            .navigationTitle("VoiceKeyboard")
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.uiState {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView("音声認識を準備中…")
        case .processing(let message):
            ProgressView(message)
        case .permissionDenied:
            VStack(spacing: 8) {
                Label(
                    "マイクの使用が許可されていません。設定アプリから許可してください。",
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.orange)

                Button("設定アプリを開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
        case .error(let message):
            Label(message, systemImage: "exclamationmark.circle")
                .foregroundStyle(.red)
        }
    }

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $viewModel.finalText)
                .font(.body)
                .padding(8)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(8)

            if !viewModel.volatileText.isEmpty {
                Text(viewModel.volatileText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
        }
    }

    private var recordButton: some View {
        Button(action: { viewModel.toggleRecording() }) {

            HStack(spacing: 8) {
                Image(systemName: viewModel.recordingState == .recording ? "stop.fill" : "mic.fill")
                Text(viewModel.recordingState == .recording ? "録音停止" : "録音開始")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.recordingState == .recording ? Color.red : Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel(viewModel.recordingState == .recording ? "録音を停止" : "録音を開始")
        .accessibilityIdentifier("recordButton")
    }
    
    private var saveButton: some View {
        Button(action: {
            Task {
                await viewModel.saveCurrentDraft()
                // 保存完了後にアラート表示
                await MainActor.run { showSaveAlert = true }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down")
                Text("保存")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel("下書きを保存")
        .accessibilityIdentifier("saveButton")
    }
}

#Preview {
    MainView()
}
