// P2Pサービスがサポートされていないプラットフォーム用のダミー実装
import 'dart:async';

class P2pService {
  // シングルトンインスタンス
  static final P2pService _instance = P2pService._internal();
  factory P2pService() => _instance;
  P2pService._internal();

  // データストリームは空のストリームを返す
  final _dataStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get dataStream => _dataStreamController.stream;

  /// 初期化処理（何もしない）
  Future<void> initialize() async {
    print(
        'ℹ️ P2P Service is not supported on this platform. Skipping initialization.');
  }

  /// ブロードキャスト処理（何もしない）
  void broadcast(Map<String, dynamic> message) {
    // 何もしない
  }

  /// 破棄処理（何もしない）
  void dispose() {
    _dataStreamController.close();
  }
}
