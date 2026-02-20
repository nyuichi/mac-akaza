# mac-akaza

## プロジェクト概要

macOS 用日本語 IME。Swift (InputMethodKit) フロントエンド + Rust (akaza-server) バックエンドの 2 プロセス構成。

## アーキテクチャ

- **Swift Frontend**: InputMethodKit IME。キー入力処理、ローマ字→かな変換、候補ウィンドウ UI、akaza-server プロセス管理
- **akaza-server (Rust)**: libakaza を利用したかな漢字変換エンジン。JSON-RPC over stdin/stdout で通信
- **通信**: JSON-RPC 2.0、1行1メッセージ（改行区切り）
- **自動再起動**: akaza-server が異常終了した場合、Swift 側で自動再起動（指数バックオフ付き）

## ビルド・実行

- Swift 部分: Xcode プロジェクト (`AkazaIME.xcodeproj`) でビルド
- Rust 部分 (akaza-server): `cargo build --release`
- インストール先: `~/Library/Input Methods/Akaza.app`
- モデルデータ: `Contents/Resources/model/` に配置（akaza-default-model の GitHub Releases からダウンロード）

## コーディング規約

- Swift コードは Swift 標準のコーディングスタイルに従う
- Rust コードは `cargo fmt` / `cargo clippy` に従う
- InputMethodKit の API では preedit のことを MarkedText と呼ぶ

## ディレクトリ構成

```
AkazaIME/          # Swift IME フロントエンド
akaza-server/      # Rust JSON-RPC サーバー (将来追加)
Resources/         # アイコン等のリソース
```

## 重要な注意事項

- InputMethodKit の IME は `~/Library/Input Methods/` にインストールする必要がある
- IME のデバッグは難しい。変更後はシステム環境設定からキーボードを一度削除して再追加するか、`killall AkazaIME` してから再起動する必要がある場合がある
- akaza-server との通信は非同期で行い、UI スレッドをブロックしないこと
- akaza-server のクラッシュに備え、変換リクエストのタイムアウトを設定すること

## バージョンアップ手順

akaza ライブラリとモデルを新しいバージョン（例: `vYYYY.MMD.0`）に更新する場合、以下の 2 ファイルを修正する。

1. `akaza-server/Cargo.toml` の `libakaza` タグを更新
   ```toml
   libakaza = { git = "https://github.com/akaza-im/akaza.git", tag = "vYYYY.MMD.0" }
   ```

2. `Makefile` の `MODEL_VERSION` を更新
   ```makefile
   MODEL_VERSION = vYYYY.MMD.0
   ```

3. `Cargo.lock` を更新
   ```sh
   cargo update -p libakaza
   ```

## 関連リポジトリ

- [akaza](https://github.com/akaza-im/akaza) - Rust 製かな漢字変換エンジン (コアライブラリ libakaza)
- [akaza-default-model](https://github.com/akaza-im/akaza-default-model) - デフォルト言語モデル (~151MB)
