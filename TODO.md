# TODO

コードレビューで発見した問題の修正リスト。

## High priority

- [x] `handler.rs`: `force_ranges` の bounds check なし — `r[0]..r[1]` で要素数チェックなしのため panic リスク
- [x] `main.rs`: `to_str().unwrap()` — 非 UTF-8 パスでクラッシュ
- [x] `AkazaServerProcess.swift`: `start()` が再起動のたびに NotificationCenter observer を追加し続ける（leak）

## Medium priority

- [x] `JSONRPCClient.swift`: `convertKBestAsync()` と `sendRequestSync()` でリクエスト送信ロジックが重複 → 共通 `sendRequest()` に抽出
- [x] `JSONRPCClient.swift`: `lock.lock()` / `lock.unlock()` 手動管理 → `withLock {}` に置換
- [x] `CandidateWindowController.swift`: `show()` と `showSuggestions()` でラベル作成・ページング・配置ロジックが重複 → 共通 `showSurfaces()` に抽出

## Low priority

- [x] `AkazaInputController.swift` L162: `char.unicodeScalars.first!.value` force unwrap
- [x] `jsonrpc.rs`: `#[allow(dead_code)]` の `jsonrpc` フィールド → バージョン検証に活用
- [x] `AkazaServerProcess.swift` L36: `try?` でディレクトリ作成エラーを無視
- [x] `Settings.swift`: `suggestMaxPaths` に上限チェックなし（上限 20 を追加）
