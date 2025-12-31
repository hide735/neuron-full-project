import 'dart:math' as math;

/// TF-IDF (Term Frequency-Inverse Document Frequency) モデルを実装し、テキストのベクトル化を担当します。
///
/// このクラスは、アプリケーション全体で共有される単語の「辞書」を保持し、
/// テキストを単語の重要度に基づいたベクトルに変換します。
class TextVectorizer {
  /// 単語とインデックスをマッピングする辞書（語彙）。
  final Map<String, int> vocabulary = {};
  int _nextWordIndex = 0;

  // IDF 計算用の統計情報
  /// 各単語がいくつの文書に出現したか
  final Map<String, int> _documentFrequency = {};

  /// 全文書数
  int _totalDocuments = 0;

  /// テキストを単語（トークン）のリストに分割する内部ヘルパー関数。
  ///
  /// 現在は単純に空白と句読点で分割しています。
  List<String> _tokenize(String text) {
    // 正規表現で英数字の単語を抽出（日本語の分かち書きには非対応）
    return text
        .toLowerCase()
        .split(RegExp(r'[\s,.:;!?"]+'))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// 既存の全ドキュメントから辞書とIDFの統計情報を一括で構築する。
  ///
  /// アプリ起動時に一度だけ呼び出すことを想定。
  void fit(List<String> documents) {
    _totalDocuments = documents.length;
    for (final doc in documents) {
      final tokens = _tokenize(doc);
      // 辞書を構築
      for (final token in tokens) {
        if (!vocabulary.containsKey(token)) {
          vocabulary[token] = _nextWordIndex++;
        }
      }
      // ドキュメント頻度を更新
      for (final token in tokens.toSet()) {
        _documentFrequency[token] = (_documentFrequency[token] ?? 0) + 1;
      }
    }
  }

  /// 新しい単一のドキュメントで辞書とIDFの統計情報を動的に更新する。
  ///
  /// 新しいメッセージが追加されるたびに呼び出すことを想定。
  /// 辞書のサイズが変更された場合は true を返します。
  bool update(String document) {
    _totalDocuments++;
    final initialSize = vocabulary.length;
    final tokens = _tokenize(document);

    // 辞書を更新
    for (final token in tokens) {
      if (!vocabulary.containsKey(token)) {
        vocabulary[token] = _nextWordIndex++;
      }
    }
    // ドキュメント頻度を更新
    for (final token in tokens.toSet()) {
      _documentFrequency[token] = (_documentFrequency[token] ?? 0) + 1;
    }
    return vocabulary.length > initialSize;
  }

  /// 現在の辞書のサイズ（語彙数）を返す。
  int get vocabularySize => vocabulary.length;

  /// テキストを TF-IDF ベクトルに変換する。
  ///
  /// 辞書のサイズと同じ長さのベクトルを返し、各要素は対応する単語の TF-IDF スコアとなります。
  List<double> vectorize(String text) {
    final vec = List<double>.filled(vocabularySize, 0.0);
    final tokens = _tokenize(text);
    if (tokens.isEmpty || _totalDocuments == 0) return vec;

    // 1. TF (Term Frequency) の計算
    final tf = <int, double>{};
    for (final token in tokens) {
      final index = vocabulary[token];
      if (index != null) {
        tf[index] = (tf[index] ?? 0) + 1;
      }
    }
    tf.forEach((index, count) {
      tf[index] = count / tokens.length;
    });

    // 2. TF-IDF の計算
    tf.forEach((index, tfValue) {
      final word = vocabulary.entries.firstWhere((e) => e.value == index).key;
      // DF (Document Frequency) を取得。もし0なら1を設定（ゼロ除算防止）
      final df = _documentFrequency[word] ?? 1;
      // IDF (Inverse Document Frequency) の計算
      final idf = math.log(_totalDocuments / df);
      vec[index] = tfValue * idf;
    });

    return vec;
  }
}

/// 【一時的措置】文字列を固定長の数値ベクトルに変換する簡易ベクトル化関数。
///
/// こちらは `local_kb.dart` のような、動的な辞書を持たないモジュールとの
/// 互換性を維持するために残されています。
/// ハッシュベースのため、単語の意味は捉えられません。
List<double> vectorizeForKB(String s, {int dim = 128}) {
  // 単純ハッシュベースの埋め込み（プロトタイプ）
  final seed = s.codeUnits.fold<int>(0, (p, e) => p + e);
  final rnd = seed % 1000;
  return List.generate(dim, (i) => ((rnd + i * 37) % 1000) / 1000.0);
}
