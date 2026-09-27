import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/call_model.dart';
import '../services/call_service.dart';
import '../services/webrtc_service.dart';
import '../widgets/call_controls.dart';
import '../widgets/local_video_view.dart';
import '../widgets/remote_video_view.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final bool isCaller;
  final String peerName;
  final String? peerPhoto;
  final String type;
  final WebRtcService webrtcService;
  final CallService callService;

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.isCaller,
    required this.peerName,
    this.peerPhoto,
    required this.type,
    required this.webrtcService,
    required this.callService,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  StreamSubscription<CallModel?>? _callSubscription;
  Timer? _durationTimer;
  int _callSeconds = 0;
  bool _isConnected = false;
  bool _isEnding = false;

  Offset _localVideoPosition = const Offset(20, 50);

  bool get isVideo => widget.type == 'video';

  @override
  void initState() {
    super.initState();
    _setupCall();
  }

  void _setupCall() async {
    final currentState = await widget.webrtcService.getConnectionState();
    if (currentState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      if (mounted) {
        setState(() => _isConnected = true);
        _startTimer();
      }
    }

    widget.webrtcService.onCallConnected = (connected) {
      if (!mounted) return;
      setState(() {
        _isConnected = connected;
      });
      if (connected) {
        _startTimer();
        widget.callService.updateCallStatus(widget.callId, CallStatus.connected);
      }
    };

    widget.webrtcService.onConnectionStateChange = (state) {
      debugPrint('VideoCallScreen: PeerConnectionState = $state');
      if (!mounted) return;

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        setState(() => _isConnected = true);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        setState(() => _isConnected = false);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _handleCallEnded('Call ended');
      }
    };

    _callSubscription = widget.callService.streamCall(widget.callId).listen((call) {
      if (call == null || !mounted) return;

      if (call.status == CallStatus.ended) {
        _handleCallEnded('Call ended');
      } else if (call.status == CallStatus.rejected) {
        _handleCallEnded('Call was declined');
      }
    });
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _callSeconds++;
      });
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _handleCallEnded(String reason) {
    if (_isEnding) return;
    _isEnding = true;

    _durationTimer?.cancel();
    _callSubscription?.cancel();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason), duration: const Duration(seconds: 2)),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _endCall() async {
    if (_isEnding) return;
    _isEnding = true;

    _durationTimer?.cancel();
    await _callSubscription?.cancel();

    await widget.callService.endCall(widget.callId);
    await widget.webrtcService.dispose();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _callSubscription?.cancel();
    widget.webrtcService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldEnd = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('End Call?'),
            content: const Text('Are you sure you want to end this call?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('End Call', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (shouldEnd == true) {
          _endCall();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            RemoteVideoView(
              renderer: widget.webrtcService.remoteRenderer,
              peerName: widget.peerName,
              peerPhoto: widget.peerPhoto,
              isVideo: isVideo,
              isConnected: _isConnected,
            ),

            if (isVideo)
              Positioned(
                right: _localVideoPosition.dx,
                top: _localVideoPosition.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      final newX = _localVideoPosition.dx - details.delta.dx;
                      final newY = _localVideoPosition.dy + details.delta.dy;
                      _localVideoPosition = Offset(
                        newX.clamp(10.0, size.width - 130.0),
                        newY.clamp(40.0, size.height - 240.0),
                      );
                    });
                  },
                  child: LocalVideoView(
                    renderer: widget.webrtcService.localRenderer,
                    isVideoEnabled: !widget.webrtcService.isVideoMuted,
                  ),
                ),
              ),

            Positioned(
              top: 50,
              left: 20,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isConnected ? const Color(0xFF22C55E) : const Color(0xFFEAB308),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isConnected ? _formatDuration(_callSeconds) : 'Connecting...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: CallControls(
                  isAudioMuted: widget.webrtcService.isAudioMuted,
                  isVideoMuted: widget.webrtcService.isVideoMuted,
                  isSpeakerOn: widget.webrtcService.isSpeakerOn,
                  isVideoCall: isVideo,
                  onToggleMic: () {
                    setState(() {
                      widget.webrtcService.toggleMic();
                    });
                  },
                  onToggleCamera: () {
                    setState(() {
                      widget.webrtcService.toggleCamera();
                    });
                  },
                  onSwitchCamera: () async {
                    await widget.webrtcService.switchCamera();
                  },
                  onToggleSpeaker: () {
                    setState(() {
                      widget.webrtcService.toggleSpeaker();
                    });
                  },
                  onEndCall: _endCall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
