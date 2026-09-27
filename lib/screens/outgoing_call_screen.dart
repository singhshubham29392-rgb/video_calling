import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/call_model.dart';
import '../services/call_service.dart';
import '../services/webrtc_service.dart';
import 'video_call_screen.dart';

class OutgoingCallScreen extends StatefulWidget {
  final String receiverUid;
  final String receiverName;
  final String? receiverPhoto;
  final String type;

  const OutgoingCallScreen({
    super.key,
    required this.receiverUid,
    required this.receiverName,
    this.receiverPhoto,
    required this.type,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  final CallService _callService = CallService();
  final WebRtcService _webrtcService = WebRtcService();

  String? _callId;
  String _statusText = 'Initializing...';
  StreamSubscription<CallModel?>? _callSubscription;
  bool _isAnswerSet = false;
  bool _isTerminated = false;
  final List<RTCIceCandidate> _localCandidatesQueue = [];

  bool get isVideo => widget.type == 'video';

  @override
  void initState() {
    super.initState();
    _startOutgoingCall();
  }

  Future<void> _startOutgoingCall() async {
    try {
      setState(() => _statusText = 'Setting up media...');

      await _webrtcService.initializeRenderers();
      await _webrtcService.openUserMedia(isVideo: isVideo);
      await _webrtcService.createPeerConnectionInstance(isVideo: isVideo);

      setState(() => _statusText = 'Creating offer...');
      final offer = await _webrtcService.createOffer(isVideo: isVideo);

      setState(() => _statusText = 'Calling...');
      final callId = await _callService.createCall(
        receiverId: widget.receiverUid,
        receiverName: widget.receiverName,
        receiverPhoto: widget.receiverPhoto,
        type: widget.type,
        offer: offer,
      );

      _callId = callId;

      _webrtcService.onIceCandidate = (candidate) {
        if (_callId != null) {
          _callService.addCandidate(
            callId: _callId!,
            isCaller: true,
            candidate: candidate,
          );
        } else {
          _localCandidatesQueue.add(candidate);
        }
      };

      final candidateSub = _callService.listenToRemoteCandidates(
        callId: callId,
        isCaller: true,
        onCandidateReceived: (candidate) {
          _webrtcService.addCandidate(candidate);
        },
      );
      _webrtcService.attachCandidateSubscription(candidateSub);

      for (final candidate in _localCandidatesQueue) {
        _callService.addCandidate(
          callId: callId,
          isCaller: true,
          candidate: candidate,
        );
      }
      _localCandidatesQueue.clear();

      _callSubscription = _callService.streamCall(callId).listen((call) async {
        if (call == null || !mounted || _isTerminated) return;

        if (call.status == CallStatus.rejected) {
          _handleTermination('Call declined');
          return;
        }

        if (call.status == CallStatus.ended) {
          _handleTermination('Call ended');
          return;
        }

        if (call.answer != null && !_isAnswerSet) {
          _isAnswerSet = true;
          setState(() => _statusText = 'Connecting...');

          await _webrtcService.setRemoteAnswer(call.answer!);

          if (!mounted || _isTerminated) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VideoCallScreen(
                callId: call.id,
                isCaller: true,
                peerName: widget.receiverName,
                peerPhoto: widget.receiverPhoto,
                type: widget.type,
                webrtcService: _webrtcService,
                callService: _callService,
              ),
            ),
          );
        } else if (call.status == CallStatus.ringing) {
          setState(() => _statusText = 'Ringing...');
        }
      });
    } catch (e) {
      debugPrint('OutgoingCallScreen: Error initiating call: $e');
      _handleTermination('Failed to initiate call: $e');
    }
  }

  void _handleTermination(String reason) {
    if (_isTerminated) return;
    _isTerminated = true;

    _callSubscription?.cancel();
    _webrtcService.dispose();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason)),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _cancelCall() async {
    if (_isTerminated) return;
    _isTerminated = true;

    _callSubscription?.cancel();

    if (_callId != null) {
      await _callService.endCall(_callId!);
    }
    await _webrtcService.dispose();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    if (!_isAnswerSet) {
      _webrtcService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  border: Border.all(color: Colors.white24, width: 3),
                ),
                child: CircleAvatar(
                  radius: 70,
                  backgroundImage: widget.receiverPhoto != null && widget.receiverPhoto!.isNotEmpty
                      ? NetworkImage(widget.receiverPhoto!)
                      : null,
                  backgroundColor: const Color(0xFF1E293B),
                  child: widget.receiverPhoto == null || widget.receiverPhoto!.isEmpty
                      ? const Icon(Icons.person, size: 70, color: Colors.white70)
                      : null,
                ),
              ),
              const SizedBox(height: 28),

              Text(
                widget.receiverName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                _statusText,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(flex: 3),

              Padding(
                padding: const EdgeInsets.only(bottom: 48.0),
                child: Column(
                  children: [
                    FloatingActionButton(
                      heroTag: 'cancelCallBtn',
                      backgroundColor: const Color(0xFFEF4444),
                      elevation: 4,
                      shape: const CircleBorder(),
                      onPressed: _cancelCall,
                      child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
