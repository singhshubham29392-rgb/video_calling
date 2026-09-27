import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRtcService {
  final Map<String, dynamic> _rtcConfiguration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
          'stun:stun3.l.google.com:19302',
          'stun:stun4.l.google.com:19302',
        ],
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  StreamSubscription? _remoteCandidatesSubscription;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  final List<RTCIceCandidate> _pendingIceCandidates = [];
  bool _isDisposed = false;

  bool isAudioMuted = false;
  bool isVideoMuted = false;
  bool isSpeakerOn = true;

  Function(RTCIceCandidate candidate)? onIceCandidate;
  Function(RTCPeerConnectionState state)? onConnectionStateChange;
  Function(bool isConnected)? onCallConnected;

  bool get isInitialized => _peerConnection != null;

  Future<RTCPeerConnectionState> getConnectionState() async {
    if (_peerConnection == null) return RTCPeerConnectionState.RTCPeerConnectionStateClosed;
    final state = await _peerConnection!.getConnectionState();
    return state ?? RTCPeerConnectionState.RTCPeerConnectionStateClosed;
  }

  Future<void> initializeRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<void> openUserMedia({required bool isVideo}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': isVideo
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;

      if (isVideo) {
        Helper.setSpeakerphoneOn(true);
        isSpeakerOn = true;
      }
    } catch (e) {
      debugPrint('WebRtcService: Error accessing media devices: $e');
      rethrow;
    }
  }

  Future<void> createPeerConnectionInstance({required bool isVideo}) async {
    _peerConnection = await createPeerConnection(_rtcConfiguration);

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        onIceCandidate?.call(candidate);
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
      }
    };

    _peerConnection!.onAddStream = (MediaStream stream) {
      _remoteStream = stream;
      remoteRenderer.srcObject = _remoteStream;
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('WebRtcService: PeerConnectionState -> $state');
      onConnectionStateChange?.call(state);
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onCallConnected?.call(true);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        onCallConnected?.call(false);
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('WebRtcService: IceConnectionState -> $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        onCallConnected?.call(true);
      }
    };
  }

  Future<RTCSessionDescription> createOffer({required bool isVideo}) async {
    if (_peerConnection == null) {
      throw StateError('PeerConnection is not initialized');
    }

    final Map<String, dynamic> offerConstraints = {
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': isVideo ? 1 : 0,
    };

    final RTCSessionDescription offer = await _peerConnection!.createOffer(offerConstraints);
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswer({
    required Map<String, dynamic> remoteOffer,
    required bool isVideo,
  }) async {
    if (_peerConnection == null) {
      throw StateError('PeerConnection is not initialized');
    }

    final RTCSessionDescription offerDesc = RTCSessionDescription(
      remoteOffer['sdp'],
      remoteOffer['type'],
    );
    await _peerConnection!.setRemoteDescription(offerDesc);

    await _drainPendingCandidates();

    final Map<String, dynamic> answerConstraints = {
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': isVideo ? 1 : 0,
    };

    final RTCSessionDescription answer = await _peerConnection!.createAnswer(answerConstraints);
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteAnswer(Map<String, dynamic> remoteAnswer) async {
    if (_peerConnection == null) return;

    try {
      final RTCSessionDescription answerDesc = RTCSessionDescription(
        remoteAnswer['sdp'],
        remoteAnswer['type'],
      );
      await _peerConnection!.setRemoteDescription(answerDesc);
      await _drainPendingCandidates();
    } catch (e) {
      debugPrint('WebRtcService: Error setting remote answer: $e');
    }
  }

  Future<void> addCandidate(RTCIceCandidate candidate) async {
    if (_peerConnection == null) return;
    if (candidate.candidate == null || candidate.candidate!.trim().isEmpty) return;

    final remoteDescription = await _peerConnection!.getRemoteDescription();
    if (remoteDescription == null) {
      _pendingIceCandidates.add(candidate);
    } else {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (e) {
        debugPrint('WebRtcService: Error adding ICE candidate: $e');
      }
    }
  }

  Future<void> _drainPendingCandidates() async {
    final toDrain = List<RTCIceCandidate>.from(_pendingIceCandidates);
    _pendingIceCandidates.clear();
    for (final candidate in toDrain) {
      try {
        await _peerConnection?.addCandidate(candidate);
      } catch (e) {
        debugPrint('WebRtcService: Error adding queued candidate: $e');
      }
    }
  }

  void attachCandidateSubscription(StreamSubscription subscription) {
    _remoteCandidatesSubscription?.cancel();
    _remoteCandidatesSubscription = subscription;
  }

  bool toggleMic() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        isAudioMuted = !isAudioMuted;
        audioTracks[0].enabled = !isAudioMuted;
      }
    }
    return isAudioMuted;
  }

  bool toggleCamera() {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        isVideoMuted = !isVideoMuted;
        videoTracks[0].enabled = !isVideoMuted;
      }
    }
    return isVideoMuted;
  }

  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        await Helper.switchCamera(videoTracks[0]);
      }
    }
  }

  bool toggleSpeaker() {
    isSpeakerOn = !isSpeakerOn;
    Helper.setSpeakerphoneOn(isSpeakerOn);
    return isSpeakerOn;
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    try {
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          track.stop();
        }
        await _localStream!.dispose();
        _localStream = null;
      }

      if (_remoteStream != null) {
        for (final track in _remoteStream!.getTracks()) {
          track.stop();
        }
        await _remoteStream!.dispose();
        _remoteStream = null;
      }

      if (_peerConnection != null) {
        await _peerConnection!.close();
        await _peerConnection!.dispose();
        _peerConnection = null;
      }

      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
      await localRenderer.dispose();
      await remoteRenderer.dispose();

      _remoteCandidatesSubscription?.cancel();
      _remoteCandidatesSubscription = null;
      _pendingIceCandidates.clear();
    } catch (e) {
      debugPrint('WebRtcService: Error during disposal: $e');
    }
  }
}
