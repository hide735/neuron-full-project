import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sembast/sembast_io.dart' as sembast_io;
import 'package:sembast_web/sembast_web.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// チャットメッセージを保存するためのストレージラッパー。
///
/// Web 環境では IndexedDB、非Web 環境ではローカルファイル（sembast）を用いて永続化します。
class ChatStorage {
  Database? _db;
  final StoreRef<int, Map<String, dynamic>> _store =
      intMapStoreFactory.store('messages');

  /// データベースをオープンする。既にオープン済みなら何もしない。
  Future<void> open() async {
    if (_db != null) return;
    if (kIsWeb) {
      _db = await databaseFactoryWeb.openDatabase('chat.db');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = join(dir.path, 'chat.db');
      _db = await sembast_io.databaseFactoryIo.openDatabase(dbPath);
    }
  }

  /// メッセージを追加して、そのレコード ID を返す。
  Future<int> add(Map<String, dynamic> msg) async {
    await open();
    return await _store.add(_db!, msg);
  }

  /// すべてのメッセージを取得する（古い順）。
  Future<List<Map<String, dynamic>>> all() async {
    await open();
    final records = await _store.find(_db!);
    return records.map((r) => r.value).toList();
  }
}
