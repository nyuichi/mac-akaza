# HACKING

開発者向けドキュメント。

## アーキテクチャ

Swift で書かれた IME フロントエンドと、Rust で書かれた変換エンジン（akaza-server）の 2 プロセス構成。
JSON-RPC over stdin/stdout で通信する。

```
┌──────────────────────────────────────────────────────────┐
│                    Akaza.app Bundle                       │
│           ~/Library/Input Methods/Akaza.app              │
│                                                          │
│  ┌────────────────────┐    ┌──────────────────────────┐  │
│  │  Swift IME Frontend│    │     akaza-server          │  │
│  │  (InputMethodKit)  │◄──►│     (Rust binary)         │  │
│  │                    │    │                           │  │
│  │ • IMKInputController    │ • libakaza               │  │
│  │ • 候補ウィンドウ     │    │ • かな漢字変換           │  │
│  │ • ローマ字→かな     │    │ • ユーザー学習           │  │
│  │ • キー入力処理      │    │ • モデル/辞書ロード      │  │
│  │ • 設定画面          │    │                           │  │
│  └────────┬───────────┘    └──────────┬───────────────┘  │
│           │       JSON-RPC over stdin/stdout              │
│           └──────────────────────────────────────────────┘│
│                                                          │
│  Contents/Resources/model/                               │
│  ├── unigram.model          (MARISA Trie)               │
│  ├── bigram.model           (MARISA Trie)               │
│  ├── skip_bigram.model      (MARISA Trie)               │
│  └── SKK-JISYO.akaza       (MARISA Trie)               │
└──────────────────────────────────────────────────────────┘
```

### 責務分担

| レイヤー | 言語 | 責務 |
|---------|------|------|
| **Swift Frontend** | Swift | InputMethodKit 統合, キー入力処理, ローマ字→かな変換, 候補ウィンドウ UI, 設定画面, preedit/MarkedText 管理, 文節操作, akaza-server プロセス管理 (自動再起動) |
| **akaza-server** | Rust | かな漢字変換, k-best 変換, ユーザー学習, モデル/辞書ロード, JSON-RPC サーバー (stdin/stdout) |

## 通信プロトコル: JSON-RPC over stdin/stdout

Swift プロセスが `akaza-server` を子プロセスとして起動し、stdin/stdout で JSON-RPC 2.0 メッセージを交換する。

- 1 リクエスト = 1 行の JSON (改行区切り)
- akaza-server がクラッシュした場合、Swift 側で自動的に再起動する

### RPC メソッド

**`convert`** - かな漢字変換

```json
// Request
{"jsonrpc":"2.0","id":1,"method":"convert","params":{"yomi":"わたしのなまえ"}}

// Response
{"jsonrpc":"2.0","id":1,"result":{"clauses":[
  [{"surface":"私","yomi":"わたし","cost":3.2},{"surface":"わたし","yomi":"わたし","cost":5.1}],
  [{"surface":"の","yomi":"の","cost":1.0}],
  [{"surface":"名前","yomi":"なまえ","cost":2.8}]
]}}
```

**`convert_k_best`** - k-best 変換（文節区切りの候補）

```json
{"jsonrpc":"2.0","id":2,"method":"convert_k_best","params":{"yomi":"わたしのなまえ","k":5}}
```

**`learn`** - ユーザー学習

```json
{"jsonrpc":"2.0","id":3,"method":"learn","params":{"candidates":[{"surface":"私","yomi":"わたし"}]}}
```

## バンドル構成

```
Akaza.app/
├── Contents/
│   ├── Info.plist
│   ├── MacOS/
│   │   ├── AkazaIME              # Swift メインバイナリ
│   │   └── akaza-server          # Rust 変換エンジン
│   ├── Resources/
│   │   ├── model/                # ~151MB モデルデータ
│   │   │   ├── unigram.model
│   │   │   ├── bigram.model
│   │   │   ├── skip_bigram.model
│   │   │   └── SKK-JISYO.akaza
│   │   ├── romkan/
│   │   │   └── default.json
│   │   ├── akaza.tiff
│   │   └── akaza.icns
│   └── Frameworks/
└──
```

## ビルド・インストール

```bash
make install
```

### コード変更後の反映

`make install` 後、以下のコマンドで IME を再起動すれば反映される。ログアウト・ログインは不要。

```bash
killall AkazaIME
```

次にテキスト入力欄にフォーカスすると、macOS が新しいバイナリで自動的に再起動する。

> **注意**: Info.plist の `InputMethodConnectionName` を変更した場合や、初回インストール時はログアウト・ログインが必要。

## 誤変換の調査手順

詳細は `CLAUDE.md` の「誤変換の調査手順」セクションを参照。

### akaza-server に直接変換リクエストを送る

```bash
MODEL="/Users/$(whoami)/Library/Input Methods/Akaza.app/Contents/Resources/model"
SERVER="$(pwd)/target/release/akaza-server"

printf '{"jsonrpc":"2.0","id":1,"method":"convert","params":{"yomi":"あらいだそう"}}\n' \
  | "$SERVER" "$MODEL" 2>/dev/null
```

## ローマ字→かな変換

Swift 側に実装。理由:
- キー入力ごとにリアルタイムでプリエディット表示が必要
- RPC 往復のレイテンシを避ける
- akaza の `romkan/default.json` テーブルを読み込み、前方一致マッチで変換

## akaza-server の自動再起動

Swift 側で `Process` (NSTask) の終了を監視し、異常終了時は自動的に再起動する。
- 短時間に連続クラッシュした場合はバックオフ（指数的に待機時間を増やす）
- 再起動後、モデルの再ロードが完了してからリクエストを送信

## モデルデータ

[akaza-default-model](https://github.com/akaza-im/akaza-default-model/releases) の GitHub Releases から取得。
ビルド時にダウンロードして .app バンドルの `Contents/Resources/model/` に同梱する。

## Glossary

- **preedit** - InputMethodKit では MarkedText と呼ばれる。変換確定前のテキスト
- **文節 (bunsetsu/clause)** - かな漢字変換の変換単位
- **MARISA Trie** - 言語モデルと辞書のデータ構造

## 関連リポジトリ

- [akaza](https://github.com/akaza-im/akaza) - Rust 製かな漢字変換エンジン (コアライブラリ libakaza)
- [akaza-default-model](https://github.com/akaza-im/akaza-default-model) - デフォルト言語モデル (~151MB)
- [TypoIME](https://github.com/toshi-pono/TypoIME) - Swift 製 macOS IME の参考実装
