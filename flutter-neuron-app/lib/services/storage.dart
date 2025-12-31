import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// シンプルな JSON 保存ユーティリティ。
///
/// Web では SharedPreferences（localStorage）に保存し、モバイル/デスクトップでも動作します。
class Storage {
  /// name キーで JSON オブジェクトを保存する。
  static Future<void> saveJson(String name, Map<String, dynamic> j) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(name, jsonEncode(j));
  }

  /// name キーから JSON オブジェクトを読み出す。存在しない場合は null を返す。
  static Future<Map<String, dynamic>?> loadJson(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(name);
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 指定キーを削除する
  static Future<void> remove(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(name);
  }

  /// 使用可能なキー一覧を返す
  static Future<List<String>> keys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys().toList();
  }
}
