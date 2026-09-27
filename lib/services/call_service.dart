import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/call_model.dart';


class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _callsCollection =>
      _firestore.collection('calls');

  User? get currentUser => _auth.currentUser;

  Future<String> createCall({
    required String receiverId,
    required String receiverName,
    String? receiverPhoto,
    required String type,
    required RTCSessionDescription offer,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('User must be logged in to initiate a call');
    }

    final DocumentReference<Map<String, dynamic>> callRef = _callsCollection.doc();
    final callId = callRef.id;

    final CallModel call = CallModel(
      id: callId,
      callerId: user.uid,
      callerName: user.displayName ?? 'User',
      callerPhoto: user.photoURL,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverPhoto: receiverPhoto,
      type: type,
      status: CallStatus.ringing,
      createdAt: DateTime.now(),
      offer: offer.toMap(),
    );

    await callRef.set(call.toMap());
    return callId;
  }

  Future<void> addCandidate({
    required String callId,
    required bool isCaller,
    required RTCIceCandidate candidate,
  }) async {
    try {
      final collectionName = isCaller ? 'callerCandidates' : 'receiverCandidates';
      await _callsCollection
          .doc(callId)
          .collection(collectionName)
          .add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('CallService: Error saving candidate: $e');
    }
  }

  /// Listens for remote ICE candidates from counterpart
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>> listenToRemoteCandidates({
    required String callId,
    required bool isCaller,
    required Function(RTCIceCandidate candidate) onCandidateReceived,
  }) {
    final targetCollection = isCaller ? 'receiverCandidates' : 'callerCandidates';

    return _callsCollection
        .doc(callId)
        .collection(targetCollection)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null && data['candidate'] != null) {
            final candidate = RTCIceCandidate(
              data['candidate'] as String,
              data['sdpMid'] as String?,
              data['sdpMLineIndex'] as int?,
            );
            onCandidateReceived(candidate);
          }
        }
      }
    });
  }

  Future<void> answerCall({
    required String callId,
    required RTCSessionDescription answer,
  }) async {
    await _callsCollection.doc(callId).update({
      'answer': answer.toMap(),
      'status': CallStatus.connecting.toValue(),
    });
  }

  Future<void> updateCallStatus(String callId, CallStatus status) async {
    try {
      final Map<String, dynamic> updateData = {
        'status': status.toValue(),
      };
      if (status == CallStatus.ended || status == CallStatus.rejected) {
        updateData['endedAt'] = FieldValue.serverTimestamp();
      }
      await _callsCollection.doc(callId).update(updateData);
    } catch (e) {
      debugPrint('CallService: Error updating call status: $e');
    }
  }

  Future<void> rejectCall(String callId) async {
    await updateCallStatus(callId, CallStatus.rejected);
  }

  Future<void> endCall(String callId) async {
    try {
      await updateCallStatus(callId, CallStatus.ended);

      final callerCandidates = await _callsCollection
          .doc(callId)
          .collection('callerCandidates')
          .get();
      for (final doc in callerCandidates.docs) {
        await doc.reference.delete();
      }

      final receiverCandidates = await _callsCollection
          .doc(callId)
          .collection('receiverCandidates')
          .get();
      for (final doc in receiverCandidates.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('CallService: Error ending call: $e');
    }
  }

  Stream<CallModel?> streamCall(String callId) {
    return _callsCollection.doc(callId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return CallModel.fromFirestore(snapshot);
    });
  }

  Stream<List<CallModel>> listenForIncomingCalls(String currentUserId) {
    return _callsCollection
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: CallStatus.ringing.toValue())
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final calls = <CallModel>[];

      for (final doc in snapshot.docs) {
        final call = CallModel.fromFirestore(doc);
        if (call.createdAt != null) {
          final ageInSeconds = now.difference(call.createdAt!).inSeconds;
          if (ageInSeconds > 60) {
            doc.reference.update({
              'status': CallStatus.missed.toValue(),
              'endedAt': FieldValue.serverTimestamp(),
            }).catchError((_) {});
            continue;
          }
        }
        calls.add(call);
      }

      calls.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return calls;
    });
  }
}
