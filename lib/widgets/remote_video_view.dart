import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class RemoteVideoView extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final String peerName;
  final String? peerPhoto;
  final bool isVideo;
  final bool isConnected;

  const RemoteVideoView({
    super.key,
    required this.renderer,
    required this.peerName,
    this.peerPhoto,
    required this.isVideo,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    if (isVideo && isConnected && renderer.srcObject != null) {
      return SizedBox.expand(
        child: RTCVideoView(
          renderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isConnected ? const Color(0xFF22C55E) : const Color(0xFF3B82F6),
                  width: 3,
                ),
              ),
              child: CircleAvatar(
                radius: 64,
                backgroundImage: peerPhoto != null && peerPhoto!.isNotEmpty
                    ? NetworkImage(peerPhoto!)
                    : null,
                backgroundColor: const Color(0xFF334155),
                child: peerPhoto == null || peerPhoto!.isEmpty
                    ? const Icon(Icons.person, size: 64, color: Colors.white70)
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              peerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isConnected ? 'Connected' : 'Connecting...',
              style: TextStyle(
                color: isConnected ? const Color(0xFF4ADE80) : Colors.white60,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
