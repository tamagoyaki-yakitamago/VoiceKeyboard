// AIService.swift – Apple Intelligence 連携（実装完了）

// MARK: - Helper functions for fallback behavior

private func simpleSummarize(_ text: String) -> String {
    // Very naive summary: return the first few words (up to 5) of the text.
    let words = text
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
    let summaryWords = words.prefix(5)
    return summaryWords.joined(separator: " ")
}

private func simpleGenerateTitle(_ text: String) -> String {
    // Heuristic title generation: take the first line (or the whole text if no newline)
    // and truncate it to a maximum of 20 characters, appending an ellipsis if truncated.
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    // Use the first line as a base for the title
    let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
    let maxLength = 20
    if firstLine.count <= maxLength {
        return firstLine
    }
    let endIndex = firstLine.index(firstLine.startIndex, offsetBy: maxLength)
    return String(firstLine[..<endIndex]) + "…"
}

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

@available(iOS 26.0, *)
final class AIService {
    // デバイスと設定が利用可能か判定
    static var isAvailable: Bool {
#if targetEnvironment(simulator)
        return false
#else
        // Apple Intelligence がデバイスで利用可能か確認
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        return false
#endif
    }

    enum AIServiceError: Error, CustomStringConvertible {
        case unavailable
        case generationFailed(reason: String)
        var description: String {
            switch self {
            case .unavailable:
                return "Apple Intelligence が利用できません。デバイスが対応していないか設定で無効です"
            case .generationFailed(let reason):
                return "AI 生成に失敗しました: \(reason)"
            }
        }
    }

    // 簡易実装 – 文字列を加工して要約・整文・タイトルを生成
    func summarize(_ text: String) async throws -> String {
        guard Self.isAvailable else { throw AIServiceError.unavailable }
        #if targetEnvironment(simulator)
        // シミュレータでは簡易ロジックを使用
        return simpleSummarize(text)
        #else
        // 実機で Apple Intelligence を使用。失敗したらフォールバック
#if canImport(FoundationModels)
        do {
            let session = LanguageModelSession()
            let prompt = "以下のテキストを要約してください。\n\n" + text
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            // 失敗したらフォールバック
            return simpleSummarize(text)
        }
#else
        // FoundationModels が利用できない環境はフォールバック
        return simpleSummarize(text)
#endif
        #endif
    }

    func refine(_ text: String) async throws -> String {
        guard Self.isAvailable else { throw AIServiceError.unavailable }
        #if targetEnvironment(simulator)
        // シミュレータでは簡易ロジックを使用
        var refined = text.replacingOccurrences(of: "\n", with: " ")
        refined = refined.replacingOccurrences(of: "  ", with: " ")
        refined = refined.trimmingCharacters(in: .whitespacesAndNewlines)
        if !refined.hasSuffix("。") && !refined.hasSuffix("！") && !refined.hasSuffix("？") {
            refined += "。"
        }
        return refined
        #else
        // Apple Intelligence を使用して整文。失敗したらフォールバック
#if canImport(FoundationModels)
        do {
            let session = LanguageModelSession()
            let prompt = "以下のテキストを整文してください。\n\n" + text
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            // フォールバック（既存ロジック）
            var refined = text.replacingOccurrences(of: "\n", with: " ")
            refined = refined.replacingOccurrences(of: "  ", with: " ")
            refined = refined.trimmingCharacters(in: .whitespacesAndNewlines)
            if !refined.hasSuffix("。") && !refined.hasSuffix("！") && !refined.hasSuffix("？") {
                refined += "。"
            }
            return refined
        }
#else
        // FoundationModels が利用できない環境はフォールバック
        var refined = text.replacingOccurrences(of: "\n", with: " ")
        refined = refined.replacingOccurrences(of: "  ", with: " ")
        refined = refined.trimmingCharacters(in: .whitespacesAndNewlines)
        if !refined.hasSuffix("。") && !refined.hasSuffix("！") && !refined.hasSuffix("？") {
            refined += "。"
        }
        return refined
#endif
        #endif
    }

    func generateTitle(_ text: String) async throws -> String {
        guard Self.isAvailable else { throw AIServiceError.unavailable }
        #if targetEnvironment(simulator)
        // シミュレータでは簡易ロジックを使用
        return simpleGenerateTitle(text)
        #else
        // 実機では Apple Intelligence を使用し、失敗したらフォールバック
#if canImport(FoundationModels)
        do {
            let session = LanguageModelSession()
            let prompt = "以下のテキストのタイトルを日本語で20文字以内に要約してください。\n\n" + text
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            return simpleGenerateTitle(text)
        }
#else
        return simpleGenerateTitle(text)
#endif
        #endif
    }
}
