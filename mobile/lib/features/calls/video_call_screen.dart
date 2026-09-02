import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/calls/video_call_service.dart';
import '../../core/theme/app_theme.dart';

/// Canlı video destek ekranı — arama çalarken, görüşme sırasında ve
/// bağlantı kurulurken tek bir ekranda üç farklı görünüm gösterir.
/// [remoteName] sadece gösterim amaçlı (aranan/arayan kişinin adı).
class VideoCallScreen extends StatefulWidget {
  final String remoteName;
  final bool isIncoming;

  const VideoCallScreen({super.key, required this.remoteName, this.isIncoming = false});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _micOn = true;
  bool _cameraOn = true;
  CallState _callState = VideoCallService().state;

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    _remoteRenderer.initialize();

    VideoCallService().onLocalStream.listen((stream) {
      _localRenderer.srcObject = stream;
      if (mounted) setState(() {});
    });
    VideoCallService().onRemoteStream.listen((stream) {
      _remoteRenderer.srcObject = stream;
      if (mounted) setState(() {});
    });
    VideoCallService().onStateChange.listen((state) {
      if (!mounted) return;
      setState(() => _callState = state);
      if (state == CallState.ended || state == CallState.idle) {
        // Karşı taraf kapattı/reddetti — bir saniye "görüşme sona erdi"
        // gösterip otomatik geri dönüyoruz.
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    });

    if (widget.isIncoming) {
      _callState = CallState.ringing;
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  String get _statusText {
    switch (_callState) {
      case CallState.calling:
        return 'Aranıyor...';
      case CallState.ringing:
        return widget.isIncoming ? 'Gelen Arama' : 'Çalıyor...';
      case CallState.connected:
        return 'Görüşme devam ediyor';
      case CallState.ended:
        return 'Görüşme sona erdi';
      case CallState.idle:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final showRemoteVideo = _callState == CallState.connected;
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Stack(
          children: [
            // Uzak taraf video görüntüsü — bağlanana kadar sade bir profil
            // avatarı + isim gösteriliyor.
            Positioned.fill(
              child: showRemoteVideo
                  ? RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                  : Container(
                      color: AppColors.ink,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 52,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              child: Text(
                                widget.remoteName.isNotEmpty ? widget.remoteName[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(widget.remoteName, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text(_statusText, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
                          ],
                        ),
                      ),
                    ),
            ),

            // Kendi kamera önizlemesi — küçük, sağ üst köşe.
            if (_cameraOn)
              Positioned(
                top: 16,
                right: 16,
                width: 100,
                height: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                ),
              ),

            // Alt kontrol çubuğu.
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: widget.isIncoming && _callState == CallState.ringing
                  ? _buildIncomingControls()
                  : _buildActiveControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CallButton(
          icon: Icons.call_end,
          color: AppColors.danger,
          onTap: () {
            VideoCallService().rejectCall();
            Navigator.of(context).pop();
          },
        ),
        _CallButton(
          icon: Icons.videocam,
          color: AppColors.success,
          onTap: () async {
            await VideoCallService().acceptCall();
          },
        ),
      ],
    );
  }

  Widget _buildActiveControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CallButton(
          icon: _micOn ? Icons.mic : Icons.mic_off,
          color: Colors.white.withValues(alpha: 0.15),
          onTap: () {
            setState(() => _micOn = !_micOn);
            VideoCallService().toggleMic(_micOn);
          },
        ),
        _CallButton(
          icon: Icons.call_end,
          color: AppColors.danger,
          size: 64,
          onTap: () {
            VideoCallService().hangUp();
            Navigator.of(context).pop();
          },
        ),
        _CallButton(
          icon: _cameraOn ? Icons.videocam : Icons.videocam_off,
          color: Colors.white.withValues(alpha: 0.15),
          onTap: () {
            setState(() => _cameraOn = !_cameraOn);
            VideoCallService().toggleCamera(_cameraOn);
          },
        ),
        _CallButton(
          icon: Icons.cameraswitch,
          color: Colors.white.withValues(alpha: 0.15),
          onTap: () => VideoCallService().switchCamera(),
        ),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  const _CallButton({required this.icon, required this.color, required this.onTap, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.42),
      ),
    );
  }
}
