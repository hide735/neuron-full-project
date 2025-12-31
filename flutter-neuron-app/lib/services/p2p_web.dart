// P2PサービスのWebRTC実装
import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class P2pService {
  // --- シングルトンと定数 ---
  static final P2pService _instance = P2pService._internal();
  factory P2pService() => _instance;
  P2pService._internal();

  static const String _signalingServerUrl = 'ws://localhost:8080';

  final _dataStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get dataStream => _dataStreamController.stream;

  WebSocketChannel? _ws;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCDataChannel> _dataChannels = {};
  String? _selfId;

  Future<void> initialize() async {
    print('ℹ️ P2P Service (WebRTC) initializing...');
    try {
      _ws = WebSocketChannel.connect(Uri.parse(_signalingServerUrl));
      _ws!.stream.listen(
        _onSignalingMessage,
        onDone: () => print('🔌 Signaling server connection closed.'),
        onError: (error) => print('❗️ Signaling server error: $error'),
      );
      print('✅ Connected to signaling server.');
    } catch (e) {
      print('❗️Failed to connect to signaling server: $e');
    }
  }

  void _onSignalingMessage(dynamic message) {
    final Map<String, dynamic> data = json.decode(message);
    final String type = data['type'];
    final String? fromId = data['from'];

    switch (type) {
      case 'welcome':
        _selfId = data['id'];
        print('👋 Welcome! My ID is $_selfId');
        if (data['peers'] != null) {
          final List<dynamic> peers = data['peers'];
          for (final peerId in peers) {
            _createPeerConnection(peerId, isOffer: true);
          }
        }
        break;
      case 'new-peer':
        final String peerId = data['id'];
        print('👨‍👩‍👧‍👦 New peer joined: $peerId. Creating offer...');
        _createPeerConnection(peerId, isOffer: true);
        break;
      case 'offer':
        final String peerId = fromId!;
        print('📩 Received offer from $peerId.');
        _createPeerConnection(peerId, isOffer: false).then((pc) async {
          await pc
              .setRemoteDescription(RTCSessionDescription(data['sdp'], type));
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          _sendSignalingMessage(
              {'type': 'answer', 'to': peerId, 'sdp': answer.sdp});
          print('📬 Sent answer to $peerId.');
        });
        break;
      case 'answer':
        final String peerId = fromId!;
        print('📩 Received answer from $peerId.');
        _peerConnections[peerId]
            ?.setRemoteDescription(RTCSessionDescription(data['sdp'], type));
        break;
      case 'ice-candidate':
        final String peerId = fromId!;
        _peerConnections[peerId]?.addCandidate(RTCIceCandidate(
            data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
        break;
      case 'peer-left':
        final String peerId = data['id'];
        print('👋 Peer left: $peerId');
        _peerConnections[peerId]?.close();
        _peerConnections.remove(peerId);
        _dataChannels.remove(peerId);
        break;
    }
  }

  Future<RTCPeerConnection> _createPeerConnection(String peerId,
      {required bool isOffer}) async {
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ]
    });

    pc.onIceCandidate = (candidate) {
      if (candidate != null) {
        _sendSignalingMessage({
          'type': 'ice-candidate',
          'to': peerId,
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    pc.onConnectionState = (state) {
      print('🔗 Connection state with $peerId: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        print('🎉 Successfully connected with $peerId!');
      }
    };

    if (isOffer) {
      final dc = await pc.createDataChannel('data', RTCDataChannelInit());
      _setDataChannel(peerId, dc);
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      _sendSignalingMessage({'type': 'offer', 'to': peerId, 'sdp': offer.sdp});
      print('📬 Sent offer to $peerId.');
    } else {
      pc.onDataChannel = (dc) => _setDataChannel(peerId, dc);
    }

    _peerConnections[peerId] = pc;
    return pc;
  }

  void _setDataChannel(String peerId, RTCDataChannel dc) {
    _dataChannels[peerId] = dc;
    dc.onMessage = (RTCDataChannelMessage message) {
      if (!message.isBinary) _onDataChannelMessage(message.text);
    };
    dc.onDataChannelState =
        (state) => print('📦 Data channel state with $peerId: $state');
  }

  void _onDataChannelMessage(String data) {
    try {
      final message = json.decode(data);
      _dataStreamController.add(message as Map<String, dynamic>);
    } catch (e) {
      print('❗️ Invalid data received via data channel: $e');
    }
  }

  void _sendSignalingMessage(Map<String, dynamic> data) {
    if (_ws != null) {
      data['from'] = _selfId;
      _ws!.sink.add(json.encode(data));
    }
  }

  void broadcast(Map<String, dynamic> message) {
    final jsonString = json.encode(message);
    _dataChannels.forEach((peerId, dc) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(jsonString));
      }
    });
  }

  void dispose() {
    _ws?.sink.close();
    _peerConnections.forEach((id, pc) => pc.close());
    _dataChannels.forEach((id, dc) => dc.close());
    _dataStreamController.close();
    print('🛑 P2P Service (WebRTC) disposed.');
  }
}
