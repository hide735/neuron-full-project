// P2Pネットワーク通信を管理するサービスクラス (UDPブロードキャスト版)
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class P2pService {
  // シングルトンインスタンス
  static final P2pService _instance = P2pService._internal();
  factory P2pService() => _instance;
  P2pService._internal();

  // --- 定数 ---
  static const int _discoveryPort = 55370; // UDPブロードキャスト用ポート
  static const int _servicePort = 55369; // TCP通信用ポート
  static const String _discoveryMessage = 'NEURON_APP_DISCOVERY';

  // --- ネットワーク関連 ---
  RawDatagramSocket? _udpSocket;
  ServerSocket? _serverSocket;
  final List<Socket> _sockets = [];
  final Map<String, Socket> _peers = {}; // 接続済みPeerの管理用 (IP Address -> Socket)
  Timer? _broadcastTimer;

  // --- データストリーム ---
  final _dataStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get dataStream => _dataStreamController.stream;

  /// サービスを初期化し、UDPによる発見とTCPによる通信を開始する
  Future<void> initialize() async {
    // 1. TCPサーバーを起動して接続を待つ
    try {
      _serverSocket =
          await ServerSocket.bind(InternetAddress.anyIPv4, _servicePort);
      _serverSocket!.listen(_handleConnection);
      print('✅ TCP Service listening on port $_servicePort');
    } catch (e) {
      print('❗️TCP Service failed to bind to port $_servicePort: $e');
    }

    // 2. UDPソケットを起動して発見メッセージを待つ
    try {
      _udpSocket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort);
      _udpSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            final message = utf8.decode(datagram.data);
            if (message == _discoveryMessage) {
              _handleDiscovery(datagram.address);
            }
          }
        }
      });
      _udpSocket!.broadcastEnabled = true;
      print('✅ UDP Discovery listening on port $_discoveryPort');
    } catch (e) {
      print('❗️UDP Discovery failed to bind to port $_discoveryPort: $e');
    }

    // 3. 定期的に自身の存在をブロードキャストする
    _startBroadcasting();
  }

  /// 発見メッセージを受信した際の処理
  void _handleDiscovery(InternetAddress remoteAddress) {
    // 自分自身からのメッセージは無視
    _getLocalIpAddresses().then((localAddresses) {
      if (localAddresses.contains(remoteAddress.address)) return;

      // まだ接続していない相手ならTCP接続を試みる
      if (!_peers.containsKey(remoteAddress.address)) {
        print(
            '💡 Discovered peer: ${remoteAddress.address}. Attempting to connect...');
        _connectToPeer(remoteAddress.address);
      }
    });
  }

  /// ローカルのIPアドレス一覧を取得するヘルパー
  Future<List<String>> _getLocalIpAddresses() async {
    final interfaces = await NetworkInterface.list(
        includeLoopback: false, type: InternetAddressType.IPv4);
    final addresses = <String>[];
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        addresses.add(addr.address);
      }
    }
    return addresses;
  }

  /// 発見したピアにTCP接続する
  Future<void> _connectToPeer(String host) async {
    try {
      final socket = await Socket.connect(host, _servicePort,
          timeout: const Duration(seconds: 5));
      _handleConnection(socket);
    } catch (e) {
      print('❗️Failed to connect to $host: $e');
    }
  }

  /// 定期的に発見メッセージをブロードキャストするタイマーを開始
  void _startBroadcasting() {
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _udpSocket?.send(
        utf8.encode(_discoveryMessage),
        InternetAddress('255.255.255.255'), // ブロードキャストアドレス
        _discoveryPort,
      );
    });
    print('📢 Broadcasting presence every 10 seconds...');
  }

  /// 他のデバイスからのTCP接続をハンドリングする
  void _handleConnection(Socket client) {
    final peerId = client.remoteAddress.address;

    if (_peers.containsKey(peerId)) {
      client.destroy();
      return;
    }
    print('⚡️ TCP Connection from $peerId');
    _sockets.add(client);
    _peers[peerId] = client;

    // Stream<String>を正しく生成する
    const Utf8Decoder().bind(client).transform(const LineSplitter()).listen(
      (line) {
        try {
          if (line.isNotEmpty) {
            final message = jsonDecode(line);
            _dataStreamController.add(message as Map<String, dynamic>);
          }
        } catch (e) {
          print('Invalid data received: "$line" - Error: $e');
        }
      },
      onError: (error) {
        print('Connection error with $peerId: $error');
        _sockets.remove(client);
        _peers.remove(peerId);
        client.close();
      },
      onDone: () {
        print('Connection with $peerId closed.');
        _sockets.remove(client);
        _peers.remove(peerId);
        client.close();
      },
    );
  }

  /// 接続している全てのPeerにメッセージをブロードキャストする
  void broadcast(Map<String, dynamic> message) {
    final jsonString = jsonEncode(message);
    final data = utf8.encode('$jsonString\n');

    final currentSockets = List<Socket>.from(_sockets);
    for (final socket in currentSockets) {
      try {
        socket.add(data);
        socket.flush();
      } catch (e) {
        print('Failed to send data to a peer: $e');
      }
    }
  }

  /// サービスを停止する
  void dispose() {
    _broadcastTimer?.cancel();
    _udpSocket?.close();
    for (final socket in _sockets) {
      socket.destroy();
    }
    _serverSocket?.close();
    _dataStreamController.close();
    print('🛑 P2P Service disposed.');
  }
}
