// プラットフォームに応じて適切なP2Pサービス実装をエクスポートする
export 'p2p_unsupported.dart'
    // dart.library.io が存在すれば native 実装をエクスポート
    if (dart.library.io) 'p2p_native.dart'
    // dart.library.html が存在すれば web 実装をエクスポート
    if (dart.library.html) 'p2p_web.dart';
