import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_config.dart';
import '../auth/token_storage.dart';

/// Backend'deki ChatGateway (/chat namespace) ile gerçek zamanlı bağlantı.
/// Tek bir socket bağlantısı uygulama boyunca yaşar; ekranlar sadece
/// ilgili conversationId odasına join/leave olur.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  final TokenStorage _tokenStorage = TokenStorage();

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<String>.broadcast();
  // Mesajlar dışındaki TÜM bildirimler (randevu, eğitim içeriği, sertifika
  // uyarısı vb.) için — Firebase push yapılandırılmamışsa bile uygulama
  // açıkken anlık ulaşmasını sağlayan birincil kanal.
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  // Canlı video destek (WebRTC) sinyalleşme olayları.
  final _callIncomingController = StreamController<Map<String, dynamic>>.broadcast();
  final _callAcceptedController = StreamController<Map<String, dynamic>>.broadcast();
  final _callRejectedController = StreamController<Map<String, dynamic>>.broadcast();
  final _callIceCandidateController = StreamController<Map<String, dynamic>>.broadcast();
  final _callEndedController = StreamController<Map<String, dynamic>>.broadcast();

  /// Her yeni mesajda (AI veya kullanıcı) tetiklenir. Dinleyen ekran
  /// conversationId'ye göre kendi listesini filtrelemeli.
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<String> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onNotification => _notificationController.stream;
  Stream<Map<String, dynamic>> get onCallIncoming => _callIncomingController.stream;
  Stream<Map<String, dynamic>> get onCallAccepted => _callAcceptedController.stream;
  Stream<Map<String, dynamic>> get onCallRejected => _callRejectedController.stream;
  Stream<Map<String, dynamic>> get onCallIceCandidate => _callIceCandidateController.stream;
  Stream<Map<String, dynamic>> get onCallEnded => _callEndedController.stream;
  // Kullanıcı isteği: "slayt eklediğimde/pasif yaptığımda uygulama açık
  // bile olsa hemen gelmeli/gitmeli" — admin panelden slayt
  // ekleme/güncelleme/silme olduğunda backend'in TÜM bağlı istemcilere
  // yayınladığı genel sinyal.
  final _slidesUpdatedController = StreamController<void>.broadcast();
  Stream<void> get onSlidesUpdated => _slidesUpdatedController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await _tokenStorage.getAccessToken();
    if (token == null) return;

    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      // ignore: avoid_print
      debugPrint('[socket] bağlandı');
    });

    _socket!.on('message:new', (data) {
      if (data is Map<String, dynamic>) {
        _messageController.add(data);
      } else if (data is Map) {
        _messageController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('typing', (data) {
      final userId = (data is Map) ? data['userId']?.toString() : null;
      if (userId != null) _typingController.add(userId);
    });

    _socket!.on('notification:new', (data) {
      if (data is Map<String, dynamic>) {
        _notificationController.add(data);
      } else if (data is Map) {
        _notificationController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('slides:updated', (_) {
      _slidesUpdatedController.add(null);
    });

    _socket!.on('call:incoming', (data) {
      if (data is Map) _callIncomingController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('call:accepted', (data) {
      if (data is Map) _callAcceptedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('call:rejected', (data) {
      if (data is Map) _callRejectedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('call:ice-candidate', (data) {
      if (data is Map) _callIceCandidateController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('call:ended', (data) {
      if (data is Map) _callEndedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.onDisconnect((_) {
      // ignore: avoid_print
      debugPrint('[socket] bağlantı kesildi');
    });

    _socket!.onConnectError((err) {
      // ignore: avoid_print
      debugPrint('[socket] bağlantı hatası: $err');
    });

    _socket!.connect();
  }

  void joinConversation(String conversationId) {
    _socket?.emit('join', conversationId);
  }

  void leaveConversation(String conversationId) {
    _socket?.emit('leave', conversationId);
  }

  void sendTyping(String conversationId) {
    _socket?.emit('typing', {'conversationId': conversationId});
  }

  // ---- Canlı video destek (WebRTC sinyalleşme) ----
  void sendCallInvite({required String targetUserId, required String callId, required Map<String, dynamic> offer}) {
    _socket?.emit('call:invite', {'targetUserId': targetUserId, 'callId': callId, 'offer': offer});
  }

  void sendCallAccept({required String callerId, required String callId, required Map<String, dynamic> answer}) {
    _socket?.emit('call:accept', {'callerId': callerId, 'callId': callId, 'answer': answer});
  }

  void sendCallReject({required String callerId, required String callId, String? reason}) {
    _socket?.emit('call:reject', {'callerId': callerId, 'callId': callId, 'reason': reason});
  }

  void sendCallIceCandidate({required String targetUserId, required String callId, required Map<String, dynamic> candidate}) {
    _socket?.emit('call:ice-candidate', {'targetUserId': targetUserId, 'callId': callId, 'candidate': candidate});
  }

  void sendCallEnd({required String targetUserId, required String callId}) {
    _socket?.emit('call:end', {'targetUserId': targetUserId, 'callId': callId});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
