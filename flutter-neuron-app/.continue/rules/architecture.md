---
title: 設計ドキュメント
---


**基本ルール**
- 回答は日本語で行うこと。
- ソースコードの解析が必要な場合は、継承元や使用するクラス、メソッド、プロパティについても参照すること。
- ソースコードの変更/更新/追加を行う際は、コメントを必ず記載すること。

**概要**
- **目的**: Flutter (Dart) 内で完結するニューロンベースAIを実装し、P2Pで同一アプリ間のモデル共有・同期、チャット対話、インターネットからの知識取得を行う。
- **制約**: 既存の推論モデルは使わない。全てDartで完結させる（ネイティブ最適化無し）。Web対応（IndexedDB等）を優先。

**高レベル構成**
- `NeuronCore` ⇄ `NeuronManager` ⇄ (`P2P` / `Storage`) ⇄ `UI`（全体に `SafetyFilter`）

**モジュール（責務）**
- **`NeuronCore`**: 行列演算、モデル表現（重み・バイアス）、`forward(input)`, `train(batch)`, `serialize()`, `applyUpdate(update)` を提供。学習ループと簡易オプティマイザを含む。
- **`NeuronManager`**: モデルのライフサイクル管理、ローカルトレーニングスケジュール、P2P同期ポリシー（頻度・差分合意）。
- **`P2P`**: ピア発見・シグナリング（軽量サーバ経由）とデータチャネル（WebRTC想定）。メッセージ型: `model_update`, `request_weights`, `chat_message`, `heartbeat`。
- **`Storage`**: 抽象インターフェース `IStorage`（`saveModel`, `loadModel`, `listModels`）。実装例: `IndexedDBStorage`（Web）, `SembastStorage`/`FileStorage`（モバイル・デスクトップ）。
- **`UI`**: `ChatPage`（チャット）、同期ステータス表示、モデルステータス表示。
- **`SafetyFilter`**: 出力前フィルタ、内部思考の危険度評価、自己防衛閾値。人間への危害を誘発する出力はブロックまたは修正。

**データフォーマット（提案）**
- モデルシリアライズ（JSON）:
  - {
  -   "id": "...",
  -   "layers": [ { "weights": [[...]], "bias": [...] }, ... ],
  -   "meta": { "version": 1, "timestamp": 123456 }
  - }
- P2Pメッセージ（JSON）例:
  - `{ "type":"model_update","from":"peerId","update":{...} }`
  - `{ "type":"request_weights","from":"peerId" }`
  - `{ "type":"chat_message","from":"peerId","text":"..." }`

**P2P設計メモ**
- 初期実装は `flutter_webrtc` と軽量シグナリングで検証する。`signaling_server/bin/signaling_server.dart` を最小構成で用意してピア接続を確立する。
- 同期方式はまず「差分（勾配または重みスナップショット）の配布」を試し、合意アルゴリズムは単純マージ→重み平均から始める。

**ストレージ実装メモ**
- Web: IndexedDB（`sembast_web` や `indexed_db` パッケージを検討）。
- モバイル/デスクトップ: `sembast` またはファイル（JSON）保存。`IStorage` で抽象化して切り替え可能にする。

**安全性（初期方針）**
- 出力フィルタリングを第一段階とし、ブラックリスト/ルールベースの検出で危険な出力を防止する。
- 内部状態に対する「危険度スコア」を段階的に導入し、閾値超過時は学習・出力を停止して管理者通知（ログ）を行う。

**推進ステップ（neuron-step123 の内容統合）**
- **ステップ1: 推論（思考）ロジックの実装**
  - `lib/models/local_model.dart` の `LocalModel.predict(String text)` を実装し、Neurons による順伝播で応答を生成する。UI 側の `lib/ui/chat_page.dart` から呼び出す。
- **ステップ2: ベクトル化と知識ベースの連携**
  - `lib/services/vectorizer.dart` でテキスト->ベクトル変換（例: Bag-of-Words）を実装。
  - `lib/services/local_kb.dart` に過去会話や知識をベクトルで保存・検索する `findSimilar` を実装し、`predict` が参照する。
- **ステップ3: 学習ロジックの基礎実装**
  - `LocalModel.train()` を用意し、対話やユーザー評価を元に重み/bias を更新する（まずは簡易なバックプロパゲーション）。

**構成イメージ（図の説明）**
- 各端末がローカルモデル（重み・バイアス）を持ち、ローカルトレーニングを行う。P2P ネットワークを介して `model_update`（勾配・スナップショット）を交換し、協調的に学習する。

**スケルトン/予定ファイル（追記）**
- `lib/models/local_model.dart` （`predict`, `train` 実装）
- `lib/services/vectorizer.dart`, `lib/services/local_kb.dart`
- 既出: `lib/neuron/core.dart`, `lib/manager/neuron_manager.dart`, `lib/p2p/p2p.dart`, `lib/storage/storage.dart`, `lib/safety/safety.dart`, `lib/ui/chat_page.dart`

**開発上の注意（再掲）**
- すべてのソース変更には必ずコメントを記載すること。
- パフォーマンスよりも可視性と可搬性（Dartのみで動くこと）を優先する。

**次のアクション（短期・推奨順）**
1. `lib/models/local_model.dart` の `predict` と簡易 `train` を実装する（ステップ1→3 を一度に進める）。
2. `lib/services/vectorizer.dart` と `lib/services/local_kb.dart` を追加して、`predict` と統合する。
3. `lib/neuron/core.dart` に行列演算と `DenseLayer` スケルトンを追加し、ユニットテストを用意する。

ドキュメントファイル: [flutter-neuron-app/.continue/rules/architecture.md](.continue/rules/architecture.md)
