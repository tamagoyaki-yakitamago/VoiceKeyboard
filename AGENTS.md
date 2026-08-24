# VoiceDraft — Agent Instructions

## Project

- iPhone向け音声入力・下書き作成アプリ
- 対象: iOS 26以上、Swift 6、SwiftUI
- 最優先: オンデバイス音声認識と、Apple Intelligenceを使った文章処理
- UI文言・コメント・ユーザー向けエラーは日本語

## Architecture

- MVVMを基本にする
- `Views/`, `ViewModels/`, `Models/`, `Services/` の責務を分離する
- 新規の外部依存は、必要性を説明してから追加する
- まずは小さく実装し、過剰な抽象化をしない
- Swift Concurrency を使い、UI更新はMainActorで安全に扱う

## Audio & Speech

- 音声認識には SpeechAnalyzer / SpeechTranscriber を優先する
- 録音には AVAudioSession / AVAudioEngine を使用する
- リアルタイム途中結果（volatile）と確定結果（final）を区別する
- 録音停止時は、未確定の文字起こしを必ずfinalizeする
- 日本語ロケールを基本とし、未対応言語・未ダウンロードモデルの状態をUIで説明する
- マイク権限が拒否された場合、設定アプリへ誘導できるUIを表示する

## Apple Intelligence

- テキストの要約、整文、タイトル生成にはFoundation Models frameworkを使用する
- Apple Intelligence非対応端末・利用不可状態では、機能を無効化し理由を表示する
- 音声と文字起こし内容を外部へ送信する実装は、明示的な要件がない限り追加しない
- AI出力はユーザーが編集・コピーできるようにする

## Quality

- 新規画面・状態管理にはSwiftUI Previewを用意する
- loading / empty / permission denied / error の各状態を実装する
- 変更後は可能な限り対象schemeをビルドする
- コンパイルエラー、警告、未使用コードを残さない
- 変更したファイルと検証内容を最後に短く報告する

## Workflow

- 大きな実装前には、対象ファイル・方針・影響範囲を先に簡潔に提示する
- 既存コードの命名・構成を優先して再利用する
- 要件が曖昧で実装方針に大きく影響する場合のみ質問する
- 破壊的変更や依存追加の前には確認を求める