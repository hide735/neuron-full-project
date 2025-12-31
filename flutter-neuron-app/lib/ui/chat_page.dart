import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/local_model.dart';
import '../services/p2p_service.dart';
import '../services/storage.dart';
import '../services/chat_storage.dart';
import '../services/local_kb.dart';
import '../services/vectorizer.dart';
import '../services/web_fetcher.dart';
import 'settings_page.dart';

/// チャット UI。
///
/// 入力を受け取りローカルモデルで応答を生成し、メッセージを永続化します。
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  /// テキスト入力用コントローラ
  final _controller = TextEditingController();

  /// メッセージ一覧（先頭が最新）
  final _messages = <Map<String, String>>[];

  /// スクロール制御
  final ScrollController _scrollController = ScrollController();

  /// テキストベクトル化サービス
  final TextVectorizer _vectorizer = TextVectorizer();

  /// ローカルモデル
  LocalModel? _model;

  /// Webフェッチャー
  final _webFetcher = WebFetcher();

  /// 永続化ストレージ
  final ChatStorage _storage = ChatStorage();

  /// ユーザーからの肯定的な反応を示すキーワード
  final _positiveKeywords = const ['なるほど', 'わかった', 'そうですか', 'ありがとう', '了解'];

  /// ユーザーが言い換えを行ったことを示すキーワード
  final _rephraseKeywords = const [
    'つまり',
    'というか',
    '正しくは',
    'i mean',
    'in other words'
  ];

  StreamSubscription? _p2pSubscription;
  double _temperature = 1.0;
  double _learningRate = 0.01;

  @override
  void initState() {
    super.initState();
    _loadMessagesAndInitModel();
    _loadSettings();

    // P2Pネットワークからのデータ受信を待機
    _p2pSubscription = P2pService().dataStream.listen((message) {
      if (message['type'] == 'model_update' && message['model'] != null) {
        if (!mounted) return;
        setState(() {
          if (_model != null) {
            print('📬 Received model update from a peer.');
            final peerModel =
                LocalModel.fromJson(message['model'] as Map<String, dynamic>);
            _model!.mergeWith(peerModel);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _p2pSubscription?.cancel(); // 購読をキャンセル
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final j = await Storage.loadJson('settings.json');
    if (j != null) {
      setState(() {
        _temperature = (j['temperature'] as num?)?.toDouble() ?? _temperature;
        _learningRate =
            (j['learning_rate'] as num?)?.toDouble() ?? _learningRate;
      });
    }
  }

  bool _isConfident(List<double> output, {double threshold = 0.1}) {
    if (output.isEmpty) return false;
    final maxVal =
        output.fold<double>(double.negativeInfinity, (p, e) => e > p ? e : p);
    final minVal =
        output.fold<double>(double.infinity, (p, e) => e < p ? e : p);
    final confidence = maxVal - minVal;
    debugPrint('Model confidence: $confidence');
    return confidence >= threshold;
  }

  Future<void> _saveModel() async {
    if (_model == null) return;
    await Storage.saveJson('model.json', _model!.toJson());
  }

  Future<void> _loadMessagesAndInitModel() async {
    await _storage.open();
    final records = await _storage.all();
    final msgs = records.reversed.map((m) {
      return {
        'role': (m['role'] as String?) ?? 'bot',
        'text': (m['text'] as String?) ?? '',
      };
    }).toList();

    final allTexts = msgs.map((m) => m['text']!).toList();
    _vectorizer.fit(allTexts);

    await _initModel();

    setState(() {
      _messages.clear();
      _messages.addAll(msgs);
    });
  }

  Future<void> _initModel() async {
    final loadedJson = await Storage.loadJson('model.json');
    if (loadedJson != null) {
      final model = LocalModel.fromJson(loadedJson);
      final vocabSize = _vectorizer.vocabularySize;
      if (model.neurons.isNotEmpty &&
          model.neurons.first.weights.length == vocabSize &&
          model.neurons.length == vocabSize) {
        setState(() {
          _model = model;
        });
        debugPrint('Loaded model with vocabulary size: $vocabSize');
        return;
      }
      debugPrint(
          'Vocabulary size mismatch or model structure changed. Creating a new model.');
    }

    setState(() {
      final inputSize =
          _vectorizer.vocabularySize > 0 ? _vectorizer.vocabularySize : 1;
      _model = LocalModel(inputSize: inputSize, neuronCount: inputSize);
    });
    debugPrint(
        'Created a new model with vocabulary size: ${_vectorizer.vocabularySize}');
  }

  void _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.insert(0, {'role': 'user', 'text': text});
    });
    _controller.clear();
    _scrollToTop();

    try {
      await _storage.open();
      await _storage.add({
        'role': 'user',
        'text': text,
        'timestamp': DateTime.now().toIso8601String()
      });
    } catch (e) {
      debugPrint('storage add user failed: $e');
    }

    final responsePayload = await _generateResponse(text);
    final reply = responsePayload['reply'] as String;
    final inputVector = responsePayload['input_vector'] as List<double>;

    setState(() {
      _messages.insert(0, {'role': 'bot', 'text': reply});
    });
    _scrollToTop();

    try {
      await _storage.open();
      await _storage.add({
        'role': 'bot',
        'text': reply,
        'timestamp': DateTime.now().toIso8601String()
      });
    } catch (e) {
      debugPrint('storage add bot failed: $e');
    }

    if (_model != null) {
      debugPrint("Starting model training...");
      if (inputVector.isNotEmpty) {
        _model!.train(inputVector, inputVector, _learningRate);
      }

      final userTextVector = _vectorizer.vectorize(text);
      final botReplyVector = _vectorizer.vectorize(reply);
      if (userTextVector.length == _model!.neurons.first.weights.length &&
          botReplyVector.length == _model!.neurons.length) {
        _model!.train(userTextVector, botReplyVector, _learningRate);
      }

      await _saveModel();
      debugPrint("Model training complete and saved.");

      if (_model != null) {
        P2pService().broadcast({
          'type': 'model_update',
          'model': _model!.toJson(),
        });
        print('📡 Broadcasted model update to peers.');
      }
    }
  }

  Future<Map<String, dynamic>> _generateResponse(String text,
      {bool isSearchAttempted = false}) async {
    final kb = LocalKB();
    String context = '';
    try {
      final relatedDocs = await kb.searchByText(text, topK: 1);
      if (relatedDocs.isNotEmpty) {
        final data = relatedDocs.first['data'];
        if (data != null && data['content'] is String) {
          context = data['content'] as String;
          debugPrint(
              "Found context from KB: ${context.substring(0, math.min(50, context.length))}...");
        }
      }
    } catch (e) {
      debugPrint("KB search failed: $e");
    } finally {
      await kb.close();
    }

    final combinedInputText = '$text $context';

    final vocabChanged = _vectorizer.update(combinedInputText);
    if (vocabChanged) {
      await _initModel();
    }
    if (_model == null) {
      return {'reply': "エラー: モデルが準備できていません。", 'input_vector': <double>[]};
    }

    final input = _vectorizer.vectorize(combinedInputText);

    final isPositiveReaction =
        _positiveKeywords.any((keyword) => text.contains(keyword));
    if (isPositiveReaction && _model!.lastInput != null) {
      debugPrint("Reinforcing based on positive reaction...");
      _model!.train(_model!.lastInput!, input, _learningRate);
    }

    final isRephrase =
        _rephraseKeywords.any((keyword) => text.contains(keyword));
    if (isRephrase && _model!.lastInput != null) {
      debugPrint("Associating rephrased terms...");
      _model!.train(_model!.lastInput!, input, _learningRate);
      _model!.train(input, _model!.lastInput!, _learningRate);
    }

    final out = _model!.forward(input);
    _model!.updateLastInput(input);

    if (!_isConfident(out) && !isSearchAttempted) {
      debugPrint(
          "Model is not confident. Delegating to _searchAndRegenerate...");
      return _searchAndRegenerate(text);
    }

    final reply = _interpret(out);

    return {'reply': reply, 'input_vector': input};
  }

  Future<Map<String, dynamic>> _searchAndRegenerate(
      String originalQuery) async {
    setState(() {
      _messages.insert(0, {'role': 'bot', 'text': '興味深い質問ですね。少し調べてみます...'});
    });
    _scrollToTop();

    final fetchedContent = await _webFetcher.search(originalQuery);

    final kb = LocalKB();
    try {
      final vector = vectorizeForKB(fetchedContent, dim: 128);
      await kb.addDocument({
        'content': fetchedContent,
        'source': 'web_search',
        'query': originalQuery,
        'vector': vector,
      });
    } catch (e) {
      debugPrint("Failed to save web content to KB: $e");
    } finally {
      await kb.close();
    }

    setState(() {
      _messages.removeAt(0);
    });

    return _generateResponse(originalQuery, isSearchAttempted: true);
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    try {
      _scrollController.animateTo(0.0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    } catch (_) {}
  }

  String _interpret(List<double> out) {
    final adjusted =
        out.map((v) => v / (_temperature <= 0 ? 1e-6 : _temperature)).toList();
    final maxVal =
        adjusted.fold<double>(double.negativeInfinity, (p, e) => e > p ? e : p);
    final exps = adjusted.map((v) => math.exp(v - maxVal)).toList();
    final sumExp = exps.fold<double>(0.0, (p, e) => p + e);

    if (sumExp == 0) {
      return "思考中です...";
    }
    final probs = exps.map((e) => e / sumExp).toList();

    final responseTokens = <String>{};
    const responseLength = 5;
    final random = math.Random();

    final indexToWord = {
      for (var entry in _vectorizer.vocabulary.entries) entry.value: entry.key
    };

    if (indexToWord.isEmpty) {
      return "まだ言葉を知りません。";
    }

    for (int i = 0; i < responseLength; i++) {
      final r = random.nextDouble();
      double cumulative = 0.0;
      for (int j = 0; j < probs.length; j++) {
        cumulative += probs[j];
        if (r <= cumulative) {
          final word = indexToWord[j];
          if (word != null) {
            responseTokens.add(word);
          }
          break;
        }
      }
    }

    if (responseTokens.isEmpty) {
      final fallbackResponses = [
        'そうですか。',
        'なるほど。',
        'うーん…',
        '面白いですね。',
        'よくわかりません。'
      ];
      return fallbackResponses[random.nextInt(fallbackResponses.length)];
    }

    return responseTokens.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neuron Chat'), actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () async {
            final changed = await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SettingsPage(
                  initialTemperature: _temperature,
                  initialLearningRate: _learningRate),
            ));
            if (changed == true) {
              await _loadSettings();
            }
          },
        )
      ]),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (c, i) {
                  final m = _messages[i];
                  return ListTile(
                    title: Text(m['text'] ?? ''),
                    subtitle: Text(m['role'] ?? ''),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(onPressed: _send, icon: const Icon(Icons.send))
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
