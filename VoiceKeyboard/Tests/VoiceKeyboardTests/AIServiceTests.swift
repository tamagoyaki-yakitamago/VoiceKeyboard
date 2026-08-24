import Testing
@testable import VoiceKeyboard

@Test func testSummarizeFallbackReturnsFirstFiveWords() async throws {
    // テキストの最初の5語が要約として返ることを確認（シミュレータはフォールバック）
    let service = AIService()
    let input = "これは テスト 用 の 文 です。 追加 の 語 も 入れます。"
    let result = try await service.summarize(input)
    // simpleSummarize は空白区切りで最初の5語
    #expect(result == "これは テスト 用 の 文")
}

@Test func testRefineFallbackRemovesNewlinesAndAddsPeriod() async throws {
    // 整文フォールバックが改行・余分な空白を削除し、句点を付与することを確認
    let service = AIService()
    let input = "行1\n行2  \n\n"
    let result = try await service.refine(input)
    #expect(result == "行1 行2 .")
}

@Test func testGenerateTitleFallbackTruncatesTo20Chars() async throws {
    // タイトル生成フォールバックは最初の行を20文字以内に切り詰める
    let service = AIService()
    let input = "これは二十文字を超える長いタイトルのサンプルです。"
    let result = try await service.generateTitle(input)
    // 20文字以内に切り詰め、末尾に…を付与
    #expect(result == "これは二十文字を超える長" + "…")
}
