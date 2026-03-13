# Akaza for Mac

Mac 用の日本語かな漢字変換 IME。

## 動作環境

- macOS Tahoe (26) 以上
- Apple Silicon

## インストール

```bash
make install
```

初回インストール後はログアウト・ログインが必要。

## キー操作

### 入力中（preedit）

| キー | 動作 |
|------|------|
| Space | かな漢字変換を開始 |
| Enter | ひらがなのまま確定 |
| Escape | 入力をキャンセル |
| Backspace | 1文字削除 |
| F6 / Ctrl+J | ひらがなに変換 |
| F7 / Ctrl+K | カタカナ（全角）に変換 |
| F8 / Ctrl+; | 半角カタカナに変換 |
| F9 / Ctrl+L | 全角英数に変換 |
| F10 / Ctrl+: | 半角英数に変換 |

### 変換中

| キー | 動作 |
|------|------|
| Space / Tab | 次の候補 |
| Shift+Space / Shift+Tab | 前の候補 |
| Enter | 確定 |
| Escape | 変換をキャンセル |
| ←→ | 文節を移動 |
| Shift+← / Shift+→ | 文節の長さを変更 |
| ↑↓ | 文節内の候補を選択 |

## トラブルシューティング

### 設定変更後に反映されない

```bash
killall AkazaIME
```

次にテキスト入力欄にフォーカスすれば macOS が自動で再起動する。

初回インストール時や `Info.plist` の変更後はログアウト・ログインが必要。

### 変換結果が出ない / Space を押しても変換されない

1. ログを確認する

```bash
tail -50 ~/Library/Logs/AkazaIME/akaza.log
```

2. `make install` を再実行する（モデルデータが未配置の場合）

```bash
make install && killall AkazaIME
```

## 関連プロジェクト

- [akaza](https://github.com/akaza-im/akaza) - Rust 製かな漢字変換エンジン (コア)
- [akaza-default-model](https://github.com/akaza-im/akaza-default-model) - デフォルト言語モデル
