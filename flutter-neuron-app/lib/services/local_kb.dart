import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart' show databaseFactoryIo;
import 'package:sembast_web/sembast_web.dart' show databaseFactoryWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import 'vectorizer.dart';

/// ローカル知識ベース (LocalKB)
/// - Sembast を使って文書を保存する
/// - 文書は {id, url, title, content, vector} の JSON 形式で保存される
/// - 検索はベクトル類似度（コサイン類似度）により順位付けして返す
class LocalKB {
  final String dbName;
  Database? _db;
  final StoreRef<int, Map<String, dynamic>> _store =
      intMapStoreFactory.store('kb_store');

  LocalKB({this.dbName = 'local_kb.db'});

  /// DB を開く。web とネイティブでファクトリを切り替える。
  Future<void> open() async {
    if (_db != null) return;
    if (kIsWeb) {
      _db = await databaseFactoryWeb.openDatabase(dbName);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dir.path, dbName);
      _db = await databaseFactoryIo.openDatabase(dbPath);
    }
  }

  /// 文書を追加する。vector を含めて渡すこと。
  Future<int> addDocument(Map<String, dynamic> doc) async {
    await open();
    // ドキュメントに最低限のフィールドがあるかチェック
    if (!doc.containsKey('content')) {
      throw ArgumentError('doc must contain content field');
    }
    return await _store.add(_db!, doc);
  }

  /// 全文書を取得する
  Future<List<RecordSnapshot<int, Map<String, dynamic>>>> allDocuments() async {
    await open();
    return await _store.find(_db!);
  }

  /// id で文書を取得
  Future<RecordSnapshot<int, Map<String, dynamic>>?> getById(int id) async {
    await open();
    final finder = Finder(filter: Filter.byKey(id));
    final list = await _store.find(_db!, finder: finder);
    if (list.isEmpty) return null;
    return list.first;
  }

  /// クエリテキストをベクトル化してコサイン類似度で上位Nを返す
  Future<List<Map<String, dynamic>>> searchByText(String query,
      {int topK = 5, int vectorSize = 128}) async {
    await open();
    // Query をベクトル化
    final queryVec = vectorizeForKB(query, dim: vectorSize);
    final docs = await allDocuments();
    final results = <Map<String, dynamic>>[];
    for (final r in docs) {
      final data = r.value;
      final storedVec =
          (data['vector'] as List?)?.map((e) => (e as num).toDouble()).toList();
      if (storedVec == null) continue;
      final sim = _cosineSimilarity(queryVec, storedVec);
      results.add({
        'id': r.key,
        'score': sim,
        'data': data,
      });
    }
    results
        .sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return results.take(topK).toList();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    final minLen = min(a.length, b.length);
    double dot = 0.0;
    double na = 0.0;
    double nb = 0.0;
    for (int i = 0; i < minLen; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0.0;
    return dot / (sqrt(na) * sqrt(nb));
  }

  /// 単純な全文検索（コンテンツ内に query が含まれるもの）
  Future<List<Map<String, dynamic>>> simpleTextSearch(String query,
      {int topK = 20}) async {
    await open();
    final docs = await allDocuments();
    final lower = query.toLowerCase();
    final results = <Map<String, dynamic>>[];
    for (final r in docs) {
      final data = r.value;
      final content = (data['content'] as String?)?.toLowerCase() ?? '';
      if (content.contains(lower)) {
        results.add({
          'id': r.key,
          'data': data,
        });
      }
    }
    return results.take(topK).toList();
  }

  /// 指定した URL からページを取得し、テキスト抽出・サニタイズ・ベクトル化して DB に保存する。
  /// - url: 取得対象 URL
  /// - title: 任意のタイトル（未指定時はホスト名を使用）
  /// - vectorSize: ベクトル長
  /// - maxContentLength: 保存するテキストの最大長（長い場合は切り詰める）
  Future<int> fetchAndAddFromUrl(String url,
      {String? title,
      int vectorSize = 128,
      int maxContentLength = 100000,
      bool generateSummary = true,
      int summaryMaxChars = 1000,
      int summaryVectorSize = 64}) async {
    await open();
    final uri = Uri.parse(url);
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch $url: ${resp.statusCode}');
    }
    final html = resp.body;
    var text = _extractTextFromHtml(html);
    text = _sanitizeText(text);
    if (text.isEmpty) throw Exception('No text extracted from $url');
    if (text.length > maxContentLength) {
      // 長すぎる場合は切り詰める（将来的には分割して複数ドキュメント化する）
      text = text.substring(0, maxContentLength);
    }
    final vec = vectorizeForKB(text, dim: vectorSize);
    String? summary;
    List<double>? summaryVec;
    if (generateSummary) {
      summary = summarizeText(text, maxChars: summaryMaxChars);
      summaryVec = vectorizeForKB(summary, dim: summaryVectorSize);
    }
    final doc = <String, dynamic>{
      'url': url,
      'title': title ?? uri.host,
      'content': text,
      'vector': vec,
      'summary': summary,
      'summary_vector': summaryVec,
      'fetched_at': DateTime.now().toIso8601String(),
    };
    return await addDocument(doc);
  }

  /// 簡易抽出型要約
  /// - 文を分割して語頻度に基づき重要度を算出し、上位の文を繋いで返す
  /// - maxChars で最大文字数を制限する
  String summarizeText(String text, {int maxChars = 1000}) {
    if (text.isEmpty) return '';
    // 文分割（日本語と英語）
    final sentences = <String>[];
    final parts = text.split(RegExp(r'(?<=。|\.|\?|!|\n)\s*'));
    for (var p in parts) {
      final s = p.trim();
      if (s.isNotEmpty) sentences.add(s);
    }
    if (sentences.isEmpty) return text.substring(0, min(text.length, maxChars));

    // 単語頻度（簡易）
    final freq = <String, int>{};
    final wordRe = RegExp(r"[\p{L}\p{N}]+", unicode: true);
    for (var s in sentences) {
      for (final m in wordRe.allMatches(s)) {
        final w = m.group(0)!.toLowerCase();
        freq[w] = (freq[w] ?? 0) + 1;
      }
    }

    // 各文のスコアを計算
    final scores = <int, double>{};
    for (var i = 0; i < sentences.length; i++) {
      double sc = 0.0;
      for (final m in wordRe.allMatches(sentences[i])) {
        final w = m.group(0)!.toLowerCase();
        sc += (freq[w] ?? 0);
      }
      scores[i] = sc;
    }

    // スコアで上位文を選択して要約を作る
    final sorted = scores.keys.toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    final buffer = StringBuffer();
    for (final idx in sorted) {
      final candidate = sentences[idx];
      if (buffer.length + candidate.length + 1 > maxChars) continue;
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(candidate);
      if (buffer.length >= maxChars) break;
    }
    final result = buffer.toString();
    if (result.isEmpty) return text.substring(0, min(text.length, maxChars));
    return result;
  }

  /// DB を閉じる
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// 指定した URL を外部プロキシ経由で取得し、テキスト抽出・ベクトル化して DB に保存する。
  ///
  /// proxyBaseUrl はプロキシサーバのベース URL（例: https://example-proxy.com/fetch）で、
  /// ターゲット URL はクエリパラメータ `url` として渡されます。プロキシの実装は CORS ヘッダを付与して
  /// ブラウザからの直接取得を可能にする必要があります。
  Future<int> fetchAndAddFromUrlViaProxy(String url, String proxyBaseUrl,
      {String? title,
      int vectorSize = 128,
      int maxContentLength = 100000}) async {
    await open();
    final proxyUri = Uri.parse(proxyBaseUrl);
    // プロキシに url パラメータを付与して呼び出す
    final uri = proxyUri.replace(
      queryParameters: {
        ...proxyUri.queryParameters,
        'url': url,
      },
    );
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Proxy fetch failed ${resp.statusCode}');
    }
    final html = resp.body;
    var text = _extractTextFromHtml(html);
    text = _sanitizeText(text);
    if (text.isEmpty) throw Exception('No text extracted from proxied url');
    if (text.length > maxContentLength) {
      text = text.substring(0, maxContentLength);
    }
    final vec = vectorizeForKB(text, dim: vectorSize);
    String? summary;
    List<double>? summaryVec;
    // proxy経由メソッドでも要約生成可能（デフォルト true）
    summary = summarizeText(text, maxChars: 1000);
    summaryVec = vectorizeForKB(summary, dim: 64);
    final doc = <String, dynamic>{
      'url': url,
      'proxy': proxyBaseUrl,
      'title': title ?? Uri.parse(url).host,
      'content': text,
      'vector': vec,
      'summary': summary,
      'summary_vector': summaryVec,
      'fetched_at': DateTime.now().toIso8601String(),
    };
    return await addDocument(doc);
  }

  /// HTML から簡易的にテキストを抽出する。JSやCSS、タグを取り除く。
  String _extractTextFromHtml(String html) {
    // script/style を除去
    var t = html.replaceAll(
        RegExp(r'<script.*?>.*?</script>', caseSensitive: false, dotAll: true),
        ' ');
    t = t.replaceAll(
        RegExp(r'<style.*?>.*?</style>', caseSensitive: false, dotAll: true),
        ' ');
    // br, p を改行に置換
    t = t.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    t = t.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n');
    // タグを全て除去
    t = t.replaceAll(RegExp(r'<[^>]+>'), ' ');
    // 基本的な HTML エンティティをデコード
    t = t
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
    // 空白を整形して返す
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  /// 取り込んだテキストの簡易サニタイズ
  String _sanitizeText(String s) {
    var t = s.replaceAll(RegExp(r'[\u0000-\u001F]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    // 極端に長い場合は切り詰める
    if (t.length > 200000) t = t.substring(0, 200000);
    return t;
  }
}
