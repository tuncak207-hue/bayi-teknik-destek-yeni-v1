import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../api/socket_service.dart';
import '../auth/current_user.dart';

enum CallState { idle, calling, ringing, connected, ended }

/// Canlı video destek — WebRTC üzerinden bayi↔bayi ve bayi↔destek arasında
/// gerçek zamanlı görüntülü/sesli görüşme. Gerçek ses/görüntü verisi bu
/// sunucudan HİÇ geçmiyor; backend'deki ChatGateway sadece bağlantı
/// kurulumu için gereken "sinyalleşme" mesajlarını (SDP teklif/cevap,
/// ICE adayları) iki taraf arasında iletiyor.
///
/// NOT: Sadece halka açık STUN sunucusu kullanılıyor (Google'ın ücretsiz
/// STUN'u). Bazı çok kısıtlayıcı ağlarda (kurumsal güvenlik duvarları vb.)
/// doğrudan bağlantı kurulamayabilir — bu durumda görüşme başlamaz. Tam
/// güvenilirlik için ayrıca bir TURN sunucusu gerekir, bu ilk sürümde yok.
class VideoCallService {
  static final VideoCallService _instance = VideoCallService._internal();
  factory VideoCallService() => _instance;
  VideoCallService._internal();

  static const _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _callId;
  String? _remoteUserId;
  bool _isCaller = false;

  StreamSubscription? _incomingSub;
  StreamSubscription? _acceptedSub;
  StreamSubscription? _rejectedSub;
  StreamSubscription? _iceSub;
  StreamSubscription? _endedSub;

  final _stateController = StreamController<CallState>.broadcast();
  final _incomingCallController = StreamController<Map<String, dynamic>>.broadcast();
  final _localRendererController = StreamController<MediaStream?>.broadcast();
  final _remoteRendererController = StreamController<MediaStream?>.broadcast();

  Stream<CallState> get onStateChange => _stateController.stream;
  Stream<Map<String, dynamic>> get onIncomingCall => _incomingCallController.stream;
  Stream<MediaStream?> get onLocalStream => _localRendererController.stream;
  Stream<MediaStream?> get onRemoteStream => _remoteRendererController.stream;

  CallState _state = CallState.idle;
  CallState get state => _state;
  String? get remoteUserId => _remoteUserId;

  /// Uygulama açılışında bir kez çağrılır — gelen aramaları dinlemeye başlar.
  /// RootShell her zaman açık olduğu için oradan çağrılır.
  void startListening() {
    _incomingSub?.cancel();
    _acceptedSub?.cancel();
    _rejectedSub?.cancel();
    _iceSub?.cancel();
    _endedSub?.cancel();

    _incomingSub = SocketService().onCallIncoming.listen((data) {
      // Zaten görüşmedeyken gelen ikinci bir arama otomatik reddedilir.
      if (_state != CallState.idle) {
        SocketService().sendCallReject(callerId: data['callerId'], callId: data['callId'], reason: 'busy');
        return;
      }
      _callId = data['callId'];
      _remoteUserId = data['callerId'];
      _isCaller = false;
      _pendingOffer = data['offer'];
      _setState(CallState.ringing);
      _incomingCallController.add(data);
    });

    _acceptedSub = SocketService().onCallAccepted.listen((data) async {
      if (data['callId'] != _callId) return;
      final answer = data['answer'] as Map;
      await _peerConnection?.setRemoteDescription(
        RTCSessionDescription(answer['sdp'], answer['type']),
      );
      _setState(CallState.connected);
    });

    _rejectedSub = SocketService().onCallRejected.listen((data) {
      if (data['callId'] != _callId) return;
      _cleanup();
      _setState(CallState.ended);
    });

    _iceSub = SocketService().onCallIceCandidate.listen((data) async {
      if (data['callId'] != _callId) return;
      final c = data['candidate'] as Map;
      await _peerConnection?.addCandidate(
        RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']),
      );
    });

    _endedSub = SocketService().onCallEnded.listen((data) {
      if (data['callId'] != _callId) return;
      _cleanup();
      _setState(CallState.ended);
    });
  }

  Map? _pendingOffer;

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceServers);
    _peerConnection!.onIceCandidate = (candidate) {
      if (_remoteUserId == null || _callId == null) return;
      SocketService().sendCallIceCandidate(
        targetUserId: _remoteUserId!,
        callId: _callId!,
        candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        _remoteRendererController.add(_remoteStream);
      }
    };

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });
    _localRendererController.add(_localStream);
    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }
  }

  /// Bir kullanıcıyı arar — [targetUserId] hedef, [displayName] sadece
  /// UI'da gösterim için.
  Future<void> startCall(String targetUserId) async {
    if (_state != CallState.idle) return;
    _callId = _generateCallId();
    _remoteUserId = targetUserId;
    _isCaller = true;
    _setState(CallState.calling);

    await _createPeerConnection();
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    SocketService().sendCallInvite(
      targetUserId: targetUserId,
      callId: _callId!,
      offer: {'sdp': offer.sdp, 'type': offer.type},
    );
  }

  /// Gelen aramayı kabul eder.
  Future<void> acceptCall() async {
    if (_pendingOffer == null || _remoteUserId == null || _callId == null) return;
    await _createPeerConnection();
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(_pendingOffer!['sdp'], _pendingOffer!['type']),
    );
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    SocketService().sendCallAccept(
      callerId: _remoteUserId!,
      callId: _callId!,
      answer: {'sdp': answer.sdp, 'type': answer.type},
    );
    _setState(CallState.connected);
  }

  /// Gelen aramayı reddeder.
  void rejectCall() {
    if (_remoteUserId == null || _callId == null) return;
    SocketService().sendCallReject(callerId: _remoteUserId!, callId: _callId!);
    _cleanup();
    _setState(CallState.idle);
  }

  /// Devam eden görüşmeyi sonlandırır (her iki taraf da kullanabilir).
  void hangUp() {
    if (_remoteUserId != null && _callId != null) {
      SocketService().sendCallEnd(targetUserId: _remoteUserId!, callId: _callId!);
    }
    _cleanup();
    _setState(CallState.idle);
  }

  Future<void> toggleMic(bool enabled) async {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = enabled);
  }

  Future<void> toggleCamera(bool enabled) async {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = enabled);
  }

  Future<void> switchCamera() async {
    final videoTrack = _localStream?.getVideoTracks().firstOrNull;
    if (videoTrack != null) await Helper.switchCamera(videoTrack);
  }

  void _setState(CallState s) {
    _state = s;
    _stateController.add(s);
  }

  void _cleanup() {
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _localStream = null;
    _remoteStream = null;
    _peerConnection?.close();
    _peerConnection = null;
    _callId = null;
    _remoteUserId = null;
    _pendingOffer = null;
    _isCaller = false;
    _localRendererController.add(null);
    _remoteRendererController.add(null);
  }

  bool get isCallerRole => _isCaller;
  String? get myUserId => CurrentUser().id;

  String _generateCallId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return '${DateTime.now().millisecondsSinceEpoch}-${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }
}
