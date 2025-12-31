import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() async {
  // 接続されているクライアントのリスト
  final clients = <WebSocketChannel>[];
  // 各クライアントにユニークなIDを割り当てるためのカウンター
  int clientIdCounter = 0;
  // クライアントとそのIDをマッピングする
  final clientIds = <WebSocketChannel, String>{};

  final handler = webSocketHandler((WebSocketChannel webSocket) {
    // 新しいクライアントが接続した
    final clientId = 'peer_${clientIdCounter++}';
    clients.add(webSocket);
    clientIds[webSocket = clientId;
    print('✅ New client connected: $clientId (${clients.length} total)');

    final existingPeers = clients
        .where((c) => c != webSocket)
        .map((c) => clientIds[c])
        .toList();
    webSocket.sink.add(jsonEncode({
      'type': 'welcome',
      'id': clientId,
      'peers': existingPeers,
    }));

    for (final client in clients) {
      if (client != webSocket) {
        client.sink.add(jsonEncode({'type': 'new-peer', 'id': clientId}));
      }
    }

    webSocket.stream.listen(
      (message) {
        try {
          final Map<String, dynamic> data = json.decode(message);
          final String? toId = data['to'];

          if (toId != null) {
            // 宛先が指定されていれば、そのクライアントにのみ送信
            for (final client in clients) {
              if (clientIds[client == toId && client != webSocket) {
                client.sink.add(message);
                return; // 送信したらループを抜ける
              }
            }
            // 宛先が見つからない場合はエラーを出力
            print('❗️ Error: target client $toId not found');
          } else {
            // 宛先がなければブロードキャスト
        for (final client in clients) {
              if (client != webSocket) {
                client.sink.add(message);
              }
            }
          }
        } catch (e) {
          print('Error decoding message: $e');
        }
      },
      onDone: () {
        final disconnectedId = clientIds[webSocket];
        print('🔌 Client disconnected: $disconnectedId');
        clients.remove(webSocket);
        clientIds.remove(webSocket);

        for (final client in clients) {
          client.sink.add(
            jsonEncode({'type': 'peer-left', 'id': disconnectedId}),
    );
}
      },
      onError: (error) {
        print('❗️ Error: $error');
      },
    );
  });

  // サーバーを指定したポートで起動
  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('✅ Signaling server listening on port ${server.port}');
}

