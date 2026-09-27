import 'package:flutter/material.dart';

class CallControls extends StatelessWidget {
  final bool isAudioMuted;
  final bool isVideoMuted;
  final bool isSpeakerOn;
  final bool isVideoCall;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onEndCall;

  const CallControls({
    super.key,
    required this.isAudioMuted,
    required this.isVideoMuted,
    required this.isSpeakerOn,
    this.isVideoCall = true,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onSwitchCamera,
    required this.onToggleSpeaker,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildControlButton(
            icon: isAudioMuted ? Icons.mic_off : Icons.mic,
            isActive: !isAudioMuted,
            activeColor: Colors.white,
            inactiveColor: Colors.redAccent,
            onPressed: onToggleMic,
            tooltip: isAudioMuted ? 'Unmute' : 'Mute',
          ),
          const SizedBox(width: 14),

          if (isVideoCall) ...[
            _buildControlButton(
              icon: isVideoMuted ? Icons.videocam_off : Icons.videocam,
              isActive: !isVideoMuted,
              activeColor: Colors.white,
              inactiveColor: Colors.redAccent,
              onPressed: onToggleCamera,
              tooltip: isVideoMuted ? 'Turn Camera On' : 'Turn Camera Off',
            ),
            const SizedBox(width: 14),

            _buildControlButton(
              icon: Icons.switch_camera,
              isActive: true,
              activeColor: Colors.white,
              onPressed: onSwitchCamera,
              tooltip: 'Switch Camera',
            ),
            const SizedBox(width: 14),
          ],

          _buildControlButton(
            icon: isSpeakerOn ? Icons.volume_up : Icons.volume_down,
            isActive: isSpeakerOn,
            activeColor: Colors.white,
            onPressed: onToggleSpeaker,
            tooltip: isSpeakerOn ? 'Speaker On' : 'Earpiece',
          ),
          const SizedBox(width: 18),

          FloatingActionButton(
            heroTag: 'endCallButton',
            backgroundColor: const Color(0xFFEF4444),
            elevation: 4,
            shape: const CircleBorder(),
            onPressed: onEndCall,
            child: const Icon(Icons.call_end, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    Color? inactiveColor,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    final Color buttonBg = isActive
        ? Colors.white.withAlpha(40)
        : (inactiveColor ?? Colors.redAccent).withAlpha(180);

    final Color iconColor = isActive ? activeColor : Colors.white;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: buttonBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white24,
              width: 1,
            ),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
      ),
    );
  }
}
