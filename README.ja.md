# Provika

[English](README.md) · [한국어](README.ko.md) · [简体中文](README.zh-Hans.md) · [繁體中文](README.zh-Hant.md) · **日本語**

**撮影・パッケージ化・検証。**

Provikaは、撮影時刻、場所、原本の完全性が重要な写真や動画を記録するiOSアプリです。持ち運び可能な証拠パッケージを作成し、書き出したパッケージをネットワークなしでオフライン検証できます。

Provikaは交通違反の通報専用アプリではありません。事故やトラブルの現場、施設点検、配送や資産の状態、フィールドワークなど、後から確認できる撮影記録が必要な場面で利用できます。

> Provikaはファイルの完全性を確認するための技術情報を提供します。法的鑑定の代替ではなく、法的証拠能力を判断したり、特定機関での受理を保証したりするものではありません。撮影、書き出し、共有の際は、地域の法令とプライバシーに配慮してください。

## Provikaの処理フロー

1. 写真または動画を撮影し、時刻、許可された場合の位置情報、デバイスのコンテキストを記録します。
2. 元のメディアを保持し、正規化されたclaimを生成します。
3. SHA-256ダイジェストを計算し、ECDSA P-256鍵でパッケージに署名します。
4. 署名envelopeと独立検証に必要な情報をパッケージに保存します。
5. 署名に使用したKeychain項目に依存せず、パッケージの完全性を検証します。
6. 検証に合格した閲覧用コピーを、安全なZIPと多言語PDFレポートとして書き出します。

## 主な機能

| 分野 | 機能 |
| --- | --- |
| 写真・動画証拠 | バージョン付きevidence claim、元メディアの保持、決定的なパッケージ確定処理、妥当性検査 |
| 完全性 | SHA-256ダイジェスト、ECDSA P-256署名、公開鍵情報の書き出し、オフライン検証 |
| カメラ | ライブプレビュー、フォーカスと露出、フラッシュ、ズーム操作、0.5倍超広角、向きに応じた出力、連続録画 |
| プリレコード | 0 / 5 / 15 / 30秒のプリレコードバッファ |
| 可視コンテキスト | 日付、時刻、GPS、アプリ/デバイス情報を動画フレームに任意で描画 |
| 書き出し | 検証済みZIPと5言語の閲覧用PDFレポート |
| ギャラリー | ローカル記録の閲覧、絞り込み、再生、検証状態の確認、選択、共有、削除 |
| クイック撮影 | コントロールセンターとロック画面の入口、App Intents、ExtensionKitロック画面カメラ拡張 |
| データ保護 | 旧録画の移行、原本不変ポリシー、安全なファイル名、シンボリックリンク拒否、アトミックなstaging |
| 地域対応 | 中国本土向けのclaim・UIポリシーを含む単一のグローバルオフラインEvidence Core。中国専用コアは作成しない |

## 証拠パッケージ

確定済みのv2パッケージには、元のメディアと機械可読の検証記録が含まれます。

```text
EvidencePackage/
  <元のメディア>
  claim.json
  signature.json
  manifest.json       # 対象フローで生成された場合
Photo Evidence Report.pdf
```

PDFは人が読むためのコピーであり、署名された原本そのものではありません。完全性の検証は元のパッケージファイルに対して行う必要があります。

## 対応言語

アプリUI、権限説明、証拠レポートの文字列、App Storeメタデータは次の言語に対応しています。

- 日本語
- 英語
- 韓国語
- 簡体字中国語
- 繁体字中国語

署名対象のEvidence Coreはロケールに依存しません。翻訳された表示テキストが、署名済みの元の観測値を置き換えることはありません。

## プライバシーとオフライン境界

- 証拠メディアとパッケージデータは、ユーザーが明示的に書き出しまたは共有するまでデバイス内に保持されます。
- 撮影、ハッシュ、署名、パッケージ確定、検証、ZIP書き出しは、サービス接続なしで完了するよう設計されています。
- 位置情報はシステムの許可後にのみ記録され、デバイスの元座標と表示用の変換座標は区別されます。
- Firebaseの初期化は、ローカルに`GoogleService-Info.plist`がある場合に限られます。配布前に、実際のRelease構成とプライバシーマニフェストを確認してください。
- ロック画面カメラ拡張は、Appleの制限されたExtensionKit環境と一時セッションコンテナ内で動作します。

## 技術構成

| 項目 | 内容 |
| --- | --- |
| 言語 | Swift 5.9+ |
| 最小OS | iOS 18.0 |
| UI | SwiftUI + UIKitブリッジ |
| カメラとメディア | AVFoundation、Core Image |
| 保存 | SwiftData、FileManager |
| 位置情報 | CoreLocation |
| 完全性 | CryptoKit、Security framework、利用可能な場合はSecure Enclave |
| クイック撮影 | App Intents、WidgetKit、LockedCameraCapture、ExtensionKit |
| プロジェクト生成 | Tuist 4.x |

## リポジトリ構成

```text
Sources/
  App/                     アプリのエントリポイントとナビゲーション
  Core/
    Evidence/V2/           正規化claim、署名payload、finalizer、verifier
    Export/                安全なZIPと多言語PDFの書き出し
    Localization/          ロケール中立の確定テキストポリシー
    LockedCapture/         ロック画面撮影の取り込みとhandoffポリシー
    Policy/                オフラインと地域claimの境界
    Storage/               モデル、移行、証拠データ保護
    Workflow/              撮影、録画、書き出しの状態機械
  Features/
    Camera/                写真・動画撮影パイプラインと操作
    Gallery/               ローカル閲覧と詳細検証UI
    Settings/              ユーザー設定、鍵、サポートUI
  LockedCaptureExtension/  ExtensionKitロック画面カメラ体験
  Widgets/                 クイック撮影コントロール
Resources/                 アセット、プライバシーマニフェスト、ポリシー、文字列カタログ
Tests/                     証拠、ワークフロー、多言語、リリーステスト
Documentation/             設計境界と特性化ノート
```

## ビルドとテスト

### 必要環境

- iOS 18 SDK以降を含むXcode
- Tuist 4.x

### プロジェクト生成

```bash
tuist install
tuist generate --no-open
```

### ビルド

```bash
xcodebuild \
  -workspace Provika.xcworkspace \
  -scheme Provika \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### テスト

```bash
xcodebuild \
  -workspace Provika.xcworkspace \
  -scheme Provika \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

必要に応じて、シミュレータ名をローカルにインストール済みのデバイスへ置き換えてください。ハードウェア、カメラ動作、Secure Enclave、無線状態、ロックされたデバイス環境に依存する主張には、実機での証拠が必要です。

## ライセンス

Apache License 2.0。詳細は[LICENSE](LICENSE)を参照してください。
