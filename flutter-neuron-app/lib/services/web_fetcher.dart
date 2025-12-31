import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Web検索やURLの内容取得を担当するサービスクラス。
class WebFetcher {
  /// 指定されたクエリでWeb検索を行い、関連するテキストコンテンツを返す（シミュレーション）。
  ///
  /// 現在の実装は実際のWeb検索APIを呼び出す代わりに、
  /// ネットワーク遅延を模倣し、ダミーの検索結果を返します。
  ///
  /// [query] - 検索したい文字列。
  ///
  /// 将来的には、このメソッドは実際の検索エンジンAPI（例: Google Search API）を
  /// 呼び出すように拡張されるべきです。
  Future<String> search(String query) async {
    debugPrint('WebFetcher: Searching Wikipedia for "$query"...');

    final uri = Uri.https('en.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'list': 'search',
      'srsearch': query,
      'format': 'json',
      'prop': 'extracts', // To get content snippets
      'exintro': 'true', // Return only the introduction
      'explaintext': 'true', // Return as plain text
      'srlimit': '3', // Limit to 3 results
    });

    const int maxRetries = 3;
    Duration backoffDuration = const Duration(seconds: 1);

    for (int retryAttempt = 0; retryAttempt < maxRetries; retryAttempt++) {
      try {
        final response = await http.get(
          uri,
          headers: {'User-Agent': 'FlutterNeuronApp/1.0 (https://github.com/your_repo_link_here)'}, // Add a user agent
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          final List<dynamic> searchResults = data['query']['search'];

          if (searchResults.isNotEmpty) {
            final StringBuffer resultBuffer = StringBuffer();
            resultBuffer.writeln('Wikipedia search results for "$query":\n');
            for (var i = 0; i < searchResults.length; i++) {
              final result = searchResults[i];
              resultBuffer.writeln('Title: ${result['title']}');
              resultBuffer.writeln('Snippet: ${result['snippet']}...');
              if (i < searchResults.length - 1) {
                resultBuffer.writeln('');
              }
            }
            debugPrint('WebFetcher: Found content for "$query" from Wikipedia.');
            return resultBuffer.toString();
          } else {
            debugPrint('WebFetcher: No Wikipedia results found for "$query".');
            return 'No Wikipedia results found for "$query".';
          }
        } else if (response.statusCode == 403 || response.statusCode >= 500) {
          debugPrint('WebFetcher: Wikipedia search failed with status ${response.statusCode}. Retrying in ${backoffDuration.inSeconds} seconds...');
          await Future.delayed(backoffDuration);
          backoffDuration *= 2; // Exponential backoff
          if (retryAttempt == maxRetries - 1) {
            return 'Error: Failed to search Wikipedia after $maxRetries attempts. Status code: ${response.statusCode}';
          }
        } else {
          // Other client-side errors (e.g., 400, 404) are not retried
          debugPrint('WebFetcher: Failed to search Wikipedia. Status code: ${response.statusCode}');
          return 'Error: Failed to search Wikipedia. Status code: ${response.statusCode}';
        }
      } catch (e) {
        debugPrint('WebFetcher: Exception during Wikipedia search for "$query" (attempt ${retryAttempt + 1}/$maxRetries): $e');
        if (retryAttempt == maxRetries - 1) {
          return 'Error: Exception occurred during Wikipedia search after $maxRetries attempts.';
        }
        await Future.delayed(backoffDuration);
        backoffDuration *= 2; // Exponential backoff
      }
    }
    return 'Error: Unknown error occurred during Wikipedia search.'; // Should not be reached
  } // Added missing closing brace for search method

  /// 指定されたURLからコンテンツを取得する。
  ///
  /// [url] - コンテンツを取得したいURL。
  Future<String> fetchUrl(String url) async {
    debugPrint('WebFetcher: Fetching content from "$url"...');
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        debugPrint('WebFetcher: Successfully fetched content from "$url".');
        return response.body;
      } else {
        debugPrint(
            'WebFetcher: Failed to fetch content from "$url". Status code: ${response.statusCode}');
        return 'Error: Could not fetch content. Status code: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint(
          'WebFetcher: Exception while fetching content from "$url": $e');
      return 'Error: Exception occurred while fetching content.';
    }
  }
}
