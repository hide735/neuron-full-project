import 'package:flutter/material.dart';
import 'package:flutter_neuron_app/services/p2p_service.dart';
import 'ui/chat_page.dart';

/// アプリケーションのエントリポイント
void main() async {
  // main関数で非同期処理を呼び出すためのおまじない
  WidgetsFlutterBinding.ensureInitialized();

  // P2Pサービスを初期化する
  await P2pService().initialize();

  runApp(const MyApp());
}

/// ルートウィジェット。現在は `ChatPage` をホームにセットしている。
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Neuron App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ChatPage(),
    );
  }
}
