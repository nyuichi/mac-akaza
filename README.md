# Akaza for Mac

Mac 用の日本語かな漢字変換 IME。

[akaza](https://github.com/akaza-im/akaza) の変換エンジン（Rust）を利用し、macOS フロントエンドを Swift (InputMethodKit) で実装する。

## 動作環境

- macOS Tahoe (26) 以上
- Apple Silicon

## アーキテクチャ

### 概要

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

### 通信プロトコル: JSON-RPC over stdin/stdout

Swift プロセスが `akaza-server` を子プロセスとして起動し、stdin/stdout で JSON-RPC 2.0 メッセージを交換する。

- 1 リクエスト = 1 行の JSON (改行区切り)
- akaza-server がクラッシュした場合、Swift 側で自動的に再起動する

#### RPC メソッド

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

### 責務分担

| レイヤー | 言語 | 責務 |
|---------|------|------|
| **Swift Frontend** | Swift | InputMethodKit 統合, キー入力処理, ローマ字→かな変換, 候補ウィンドウ UI, 設定画面, preedit/MarkedText 管理, 文節操作, akaza-server プロセス管理 (自動再起動) |
| **akaza-server** | Rust | かな漢字変換, k-best 変換, ユーザー学習, モデル/辞書ロード, JSON-RPC サーバー (stdin/stdout) |

### Swift 側の主要コンポーネント

```
AkazaIME/
├── Package.swift or AkazaIME.xcodeproj
├── Sources/
│   ├── App/
│   │   ├── main.swift                    # NSApplication + IMKServer 起動
│   │   └── AppDelegate.swift
│   ├── InputController/
│   │   ├── AkazaInputController.swift    # IMKInputController サブクラス
│   │   ├── InputState.swift              # 状態管理 (直接入力/変換中/候補選択)
│   │   └── KeyHandler.swift              # キーイベント処理
│   ├── Conversion/
│   │   ├── RomkanConverter.swift         # ローマ字→かな変換 (YAML テーブル)
│   │   └── InputMode.swift              # ひらがな/カタカナ/英数モード
│   ├── Server/
│   │   ├── AkazaServerProcess.swift      # akaza-server 子プロセス管理・自動再起動
│   │   └── JSONRPCClient.swift           # JSON-RPC クライアント
│   └── UI/
│       ├── CandidateWindow.swift         # 変換候補ウィンドウ
│       └── PreferencesWindow.swift       # 設定画面
├── Resources/
│   ├── romkan/default.json
│   ├── akaza.tiff
│   └── akaza.icns
└── Tests/
```

### akaza-server (Rust) 側

akaza リポジトリに `akaza-server` クレートを追加、または mac-akaza リポジトリ内に配置する。
`libakaza` をライブラリとして利用し、stdin/stdout で JSON-RPC サーバーとして動作する薄いラッパー。

### ローマ字→かな変換

Swift 側に実装する。理由:
- キー入力ごとにリアルタイムでプリエディット表示が必要
- RPC 往復のレイテンシを避ける
- akaza の `romkan/default.json` テーブルを読み込み、前方一致マッチで変換

### akaza-server の自動再起動

Swift 側で `Process` (NSTask) の終了を監視し、異常終了時は自動的に再起動する。
- 短時間に連続クラッシュした場合はバックオフ（指数的に待機時間を増やす）
- 再起動後、モデルの再ロードが完了してからリクエストを送信

### モデルデータ

[akaza-default-model](https://github.com/akaza-im/akaza-default-model/releases) の GitHub Releases から取得。
ビルド時にダウンロードして .app バンドルの `Contents/Resources/model/` に同梱する。

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

## 開発

### ビルド・インストール

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

## 実装計画

### Phase 1: Swift IME の骨格

- Xcode プロジェクトまたは Swift Package で InputMethodKit IME を構築
- IMKServer + IMKInputController の最小実装
- `~/Library/Input Methods/` へのインストール・動作確認

### Phase 2: ローマ字→ひらがな変換

- `romkan/default.json` を読み込み、ローマ字→かな変換を Swift で実装
- preedit (MarkedText) のリアルタイム表示
- Enter で確定、Backspace で削除

### Phase 3: akaza-server (Rust)

- libakaza を利用した JSON-RPC サーバーを Rust で実装
- stdin から 1 行ずつ JSON-RPC リクエストを読み、stdout にレスポンスを返す
- `convert`, `convert_k_best`, `learn` メソッドを実装

### Phase 4: Swift ↔ akaza-server 接続

- Swift 側で akaza-server を子プロセスとして起動
- JSON-RPC クライアントを実装
- 異常終了時の自動再起動（指数バックオフ付き）
- ひらがな入力をサーバーに送信し、変換結果を受け取る

### Phase 5: 変換候補ウィンドウ

- 候補ウィンドウ UI の実装
- Space で次候補、Shift+Space で前候補
- 数字キーで候補を直接選択
- 文節の移動 (←/→) と伸縮 (Shift+←/→)

### Phase 6: ユーザー学習・辞書

- 変換確定時に `learn` RPC を呼び出し
- ユーザー辞書の管理

### Phase 7: 配布パッケージ

- モデルデータの同梱
- ビルドスクリプト整備
- (将来) DMG / pkg インストーラー

## トラブルシューティング

### 変換結果が出ない / Space を押しても変換されない

akaza-server がクラッシュしている可能性が高い。以下の手順で確認する。

#### 1. ログを確認

```bash
tail -50 ~/Library/Logs/AkazaIME/akaza.log
```

`akaza-server terminated with status 1` が連続して出力されている場合、サーバーが起動直後にクラッシュしている。

#### 2. akaza-server を手動で起動してエラーを確認

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"convert","params":{"yomi":"てすと"}}' | \
  ~/Library/Input\ Methods/Akaza.app/Contents/MacOS/akaza-server \
  ~/Library/Input\ Methods/Akaza.app/Contents/Resources/model 2>&1
```

stderr にエラーメッセージが出力される。

#### 3. よくある原因: モデルデータが未配置

```
Error: No such file or directory (os error 2)
```

このエラーが出た場合、`Contents/Resources/model/` にモデルデータが配置されていない。`make install` はモデルのダウンロードも自動で行うので、再度実行する。

```bash
make install && killall AkazaIME
```

手動でモデルを配置する場合:

```bash
gh release download v2026.0212.1 \
  --repo akaza-im/akaza-default-model \
  --pattern "akaza-default-model.tar.gz" \
  --dir /tmp
tar xzf /tmp/akaza-default-model.tar.gz -C /tmp
mkdir -p ~/Library/Input\ Methods/Akaza.app/Contents/Resources/model
cp /tmp/akaza-default-model/*.model /tmp/akaza-default-model/SKK-JISYO.* \
  ~/Library/Input\ Methods/Akaza.app/Contents/Resources/model/
killall AkazaIME
```

### IME を切り替えても入力が反映されない

```bash
killall AkazaIME
```

次にテキスト入力欄にフォーカスすれば macOS が自動再起動する。

初回インストール時や `Info.plist` の `InputMethodConnectionName` を変更した場合はログアウト・ログインが必要。

## Glossary

- **preedit** - InputMethodKit では MarkedText と呼ばれる。変換確定前のテキスト
- **文節 (bunsetsu/clause)** - かな漢字変換の変換単位
- **MARISA Trie** - 言語モデルと辞書のデータ構造

## 関連プロジェクト

- [akaza](https://github.com/akaza-im/akaza) - Rust 製かな漢字変換エンジン (コア)
- [akaza-default-model](https://github.com/akaza-im/akaza-default-model) - デフォルト言語モデル
- [TypoIME](https://github.com/toshi-pono/TypoIME) - Swift 製 macOS IME の参考実装
- [GyaIM](https://masui.github.io/GyaimMotion/)
