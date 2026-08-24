import Testing
@testable import VoiceKeyboard

@Test func testSummarizeFlowUpdatesStateAndText() async throws {
    // 要約実行後に UIState が idle になることと finalText が更新されることを確認
    let viewModel = VoiceDraftViewModel()
    // 初期テキストを設定（5語以上）
    viewModel.finalText = "これは テスト 用 の 文 です。 さらに テキスト を 追加"
    viewModel.summarizeText()
    // Summarize はフォールバックで最初の5語になるはず
    // 実行は非同期タスクなので少し待つ
    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 sec
    #expect(viewModel.uiState == .idle)
    #expect(viewModel.finalText == "これは テスト 用 の 文")
}

@Test func testRefineFlowUpdatesStateAndText() async throws {
    // 整文実行後に UIState が idle になることと改行が除去され句点が付くことを確認
    let viewModel = VoiceDraftViewModel()
    viewModel.finalText = "行1\n行2  \n"
    viewModel.refineText()
    try await Task.sleep(nanoseconds: 500_000_000)
    #expect(viewModel.uiState == .idle)
    #expect(viewModel.finalText == "行1 行2 .")
}

@Test func testGenerateTitleFlowUpdatesStateAndText() async throws {
    // タイトル生成実行後に UIState が idle になることと 20 文字以内に切り詰められることを確認
    let viewModel = VoiceDraftViewModel()
    viewModel.finalText = "これは二十文字を超える長いタイトルのサンプルです。"
    viewModel.generateTitle()
    try await Task.sleep(nanoseconds: 500_000_000)
    #expect(viewModel.uiState == .idle)
    #expect(viewModel.finalText == "これは二十文字を超える長…")
}
