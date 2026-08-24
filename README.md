# VoiceKeyboard

**iPhone 向け音声入力・要約アプリ**

## Overview
VoiceKeyboard は、iOS 26+、Swift 6、SwiftUI をベースにした音声入力と下書き作成を支援するアプリです。オンデバイス音声認識（`SpeechAnalyzer` / `SpeechTranscriber`）と Apple Intelligence を活用し、リアルタイム文字起こし・要約・整文・タイトル生成が可能です。

## Features
- 録音開始 → リアルタイム文字起こし（ボランタリーボリュームテキスト）
- 録音停止時に未確定文字起こしを確定（final）
- Apple Intelligence が利用可能な端末では、要約・整文・タイトル生成を AI で実行
- 利用できない環境（シミュレータ等）ではシンプルなフォールバックロジックを使用
- 下書きの自動保存・ロード（ローカル JSON）
- マイク権限が拒否された場合の設定アプリ誘導 UI
- アクセシビリティ対応（accessibilityIdentifier と Label）

## Architecture

## Project Structure
- **MVVM** パターンで `Views/`, `ViewModels/`, `Models/`, `Services/` に責務分離
- **Swift Concurrency** (`async/await`, `Task`) を使用し、UI 更新は `@MainActor` で安全に
- `AudioRecorder`, `SpeechService`, `AIService`, `FileStorageService` がそれぞれ音声入力・文字起こし・AI 連携・永続化を担当
- テストは **Swift Testing** と **XCTest UI** を併用
- **プロジェクト構造**
  - `Views/` – SwiftUI ビュー
  - `ViewModels/` – UI ロジックと状態管理
  - `Models/` – データモデル（例: `Draft`）
  - `Services/` – 音声録音、文字起こし、AI 連携、永続化
  - `Tests/` – ユニットテスト (`VoiceKeyboardTests`)、UI テスト (`VoiceKeyboardUITests`)


## Requirements
- Xcode 15.x 以上
- iOS 26+ (対象デバイス)
- Swift 6, SwiftUI 5.5
- `Speech`, `AVFoundation`, `FoundationModels`（Apple Intelligence）

## Setup & Build
```bash
# Clone the repository
git clone https://github.com/yourname/VoiceKeyboard.git
cd VoiceKeyboard/VoiceKeyboard
# Open the Xcode project
open VoiceKeyboard.xcodeproj
```
1. Xcode で **VoiceKeyboard** スキーマを選択し、対象デバイス/シミュレータを設定
2. `⌘B` でビルド、`⌘R` で実機/シミュレータにインストール

## Running Tests
```bash
# Unit & UI tests (code coverage enabled)
xcodebuild -project VoiceKeyboard.xcodeproj \
  -scheme VoiceKeyboard \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro,OS=latest" \
  clean test -enableCodeCoverage YES
```
- ユニットテストは `VoiceKeyboardTests`（Swift Testing）
- UI テストは `VoiceKeyboardUITests`（XCTest）で、`saveButton` タップ後に保存完了アラートが表示されることを検証

## UI Test Guide
- テスト対象の UI 要素には `accessibilityIdentifier`（`recordButton`, `saveButton`）を設定
- UI テストは `-UITestMode` フラグで起動し、音声録音や AI 呼び出しはモックに差し替えられます（`MockAudioRecorder`, `MockAIService`）

## Accessibility
- すべてのインタラクティブ要素に日本語の `accessibilityLabel` と固定 `accessibilityIdentifier` を設定
- VoiceOver での読み上げ順序は `VStack`/`HStack` 階層に従います

## License
MIT License – see the `LICENSE` file for details.
