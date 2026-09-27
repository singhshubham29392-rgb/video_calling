import 'dart:async';
import 'package:flutter/material.dart';
import '../models/call_model.dart';
import '../services/call_service.dart';
import '../services/webrtc_service.dart';
import 'video_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final CallModel call;

  const IncomingCallScreen({
    super.key,
    required this.call,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final CallService _callService = CallService();
  StreamSubscription<CallModel?>? _callSubscription;
  bool _isProcessing = false;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _listenToCallStatus();
  }

  void _listenToCallStatus() {
    _callSubscription = _callService.streamCall(widget.call.id).listen((call) {
      if (call == null || !mounted || _isDismissed) return;

      if (call.status == CallStatus.ended || call.status == CallStatus.missed) {
        _dismiss('Call cancelled by caller');
      }
    });
  }

  void _dismiss(String message) {
    if (_isDismissed) return;
    _isDismissed = true;

    _callSubscription?.cancel();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pop(context);
    }
  }

  Future<void> _acceptCall() async {
    if (_isProcessing || _isDismissed) return;
    setState(() => _isProcessing = true);

    final webrtcService = WebRtcService();

    try {
      if (widget.call.offer == null) {
        throw StateError('Call offer is missing');
      }

      await webrtcService.initializeRenderers();
      await webrtcService.openUserMedia(isVideo: widget.call.isVideo);
      await webrtcService.createPeerConnectionInstance(isVideo: widget.call.isVideo);

      final candidateSub = _callService.listenToRemoteCandidates(
        callId: widget.call.id,
        isCaller: false,
        onCandidateReceived: (candidate) {
          webrtcService.addCandidate(candidate);
        },
      );
      webrtcService.attachCandidateSubscription(candidateSub);

      webrtcService.onIceCandidate = (candidate) {
        _callService.addCandidate(
          callId: widget.call.id,
          isCaller: false,
          candidate: candidate,
        );
      };

      final answer = await webrtcService.createAnswer(
        remoteOffer: widget.call.offer!,
        isVideo: widget.call.isVideo,
      );

      await _callService.answerCall(
        callId: widget.call.id,
        answer: answer,
      );

      _callSubscription?.cancel();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            callId: widget.call.id,
            isCaller: false,
            peerName: widget.call.callerName,
            peerPhoto: widget.call.callerPhoto,
            type: widget.call.type,
            webrtcService: webrtcService,
            callService: _callService,
          ),
        ),
      );
    } catch (e) {
      debugPrint('IncomingCallScreen: Error accepting call: $e');
      await webrtcService.dispose();
      _dismiss('Failed to accept call: $e');
    }
  }

  Future<void> _rejectCall() async {
    if (_isProcessing || _isDismissed) return;
    setState(() => _isProcessing = true);

    try {
      await _callService.rejectCall(widget.call.id);
    } catch (e) {
      debugPrint('IncomingCallScreen: Error rejecting call: $e');
    } finally {
      _dismiss('Call declined');
    }
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String callTypeLabel = widget.call.isVideo ? 'Video Call' : 'Voice Call';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF246BFF), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF246BFF).withAlpha(100),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 70,
                    backgroundImage: widget.call.callerPhoto != null &&
                            widget.call.callerPhoto!.isNotEmpty
                        ? NetworkImage(widget.call.callerPhoto!)
                        : null,
                    backgroundColor: const Color(0xFF1E293B),
                    child: widget.call.callerPhoto == null ||
                            widget.call.callerPhoto!.isEmpty
                        ? const Icon(Icons.person, size: 70, color: Colors.white70)
                        : null,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  widget.call.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Incoming $callTypeLabel...',
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const Spacer(flex: 3),

                if (_isProcessing)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 48.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FloatingActionButton(
                              heroTag: 'rejectCallBtn',
                              backgroundColor: const Color(0xFFEF4444),
                              elevation: 4,
                              shape: const CircleBorder(),
                              onPressed: _rejectCall,
                              child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Decline',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FloatingActionButton(
                              heroTag: 'acceptCallBtn',
                              backgroundColor: const Color(0xFF22C55E),
                              elevation: 4,
                              shape: const CircleBorder(),
                              onPressed: _acceptCall,
                              child: Icon(
                                widget.call.isVideo ? Icons.videocam : Icons.call,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Accept',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
