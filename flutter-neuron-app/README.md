# Flutter Neuron App

このプロジェクトは、ニューロンを持つ人工知能アプリケーションをFlutterで開発することを目的としています。アプリはP2Pネットワークを介して他のデバイスと通信し、ユーザーとの対話を通じて知識を習得します。

## 機能

- ニューロンを持つ
- ネットワーク機能を使い、他端末の同一アプリのニューロンを共用
- チャットのようにニューロンネットワークで作成された人工知能と会話可能
- インターネットを使い知識を習得
- 感情や自己防衛の概念を持つ
- 人間に対する危害を加えるような思考はブロックする

## プロジェクト構成

- `lib/main.dart`: アプリケーションのエントリーポイント
- `lib/app.dart`: アプリ全体の構成を定義
- `lib/models/neuron.dart`: ニューロンのデータモデル
- `lib/models/local_model.dart`: ローカルモデルのデータ構造
- `lib/services/p2p_service.dart`: P2Pネットワーク通信を管理
- `lib/services/training_service.dart`: ニューロンのトレーニングを行う
- `lib/services/inference_service.dart`: 推論を行う
- `lib/services/storage_service.dart`: データの保存と取得を管理
- `lib/services/network_service.dart`: ネットワーク関連の機能を提供
- `lib/data/local_database.dart`: ローカルデータベースの設定と操作
- `lib/ui/screens/chat_screen.dart`: チャット画面のUI
- `lib/ui/screens/training_screen.dart`: トレーニング画面のUI
- `lib/ui/screens/settings_screen.dart`: 設定画面のUI
- `lib/ui/widgets/neuron_widget.dart`: ニューロンを表示するカスタムウィジェット
- `lib/utils/serializers.dart`: データのシリアライズとデシリアライズ
- `test/widget_test.dart`: ウィジェットのテスト

## インストール

1. このリポジトリをクローンします。
2. 必要な依存関係をインストールします。

```bash
flutter pub get
```

3. アプリを実行します。

```bash
flutter run
```

## Webでの永続化とデバッグ時の注意

Flutter Web はデータを IndexedDB や Local Storage に保存できますが、`flutter run -d chrome` で起動したときに自動で開かれる Chrome のデバッグインスタンスは一時プロファイルで起動され、ブラウザを閉じると保存データが消えることがあります。以下の手順で永続化を確認・運用してください。

1. デバッグ実行中に通常のブラウザで開く（推奨）
   - `flutter run -d chrome` を実行するとターミナルに DevTools とデバッグ用 URL（例: `http://127.0.0.1:60020/...`）が表示されます。
   - その URL をコピーして、通常の Chrome ウィンドウのアドレスバーに貼って開いてください。IndexedDB / Local Storage は通常プロファイルに保存され、ブラウザを閉じても残ります。

2. 本番用にビルドして配布／ローカルサーバで配信する（確実）
   - Web ビルドを作成して、静的サーバで配信します。例:
     ```powershell
     flutter build web
     python -m http.server 8000 --directory build\web
     ```
   - ブラウザで `http://localhost:8000` を開くと、通常プロファイルで永続化が利用できます。

3. DevTools で保存状況を確認する
   - ブラウザの DevTools → Application → IndexedDB や Local Storage を開き、`chat.db` や `model.json` の中身を確認してください。

4. 注意点
   - インコグニートやプライベートモードでは永続化されません。
   - 別ポートや origin（プロトコル・ホスト・ポート）が変わると別ストレージになります。
   - 開発中は保存処理を `await` しているか、エラーをログで確認するようにしてください（本リポジトリの `_storage.add` は await してログ出力する実装になっています）。

以上を README に追記しました。

## ライセンス

このプロジェクトはMITライセンスの下で提供されています。詳細はLICENSEファイルを参照してください。