import 'package:cloud_firestore/cloud_firestore.dart';

enum CallStatus {
  ringing,
  accepted,
  connecting,
  connected,
  rejected,
  ended,
  missed,
  failed;

  String toValue() => name;

  static CallStatus fromString(String? value) {
    switch (value) {
      case 'ringing':
        return CallStatus.ringing;
      case 'accepted':
        return CallStatus.accepted;
      case 'connecting':
        return CallStatus.connecting;
      case 'connected':
        return CallStatus.connected;
      case 'rejected':
        return CallStatus.rejected;
      case 'ended':
        return CallStatus.ended;
      case 'missed':
        return CallStatus.missed;
      case 'failed':
        return CallStatus.failed;
      default:
        return CallStatus.ringing;
    }
  }
}

class CallModel {
  final String id;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final String receiverId;
  final String receiverName;
  final String? receiverPhoto;
  final String type;
  final CallStatus status;
  final DateTime? createdAt;
  final DateTime? endedAt;
  final Map<String, dynamic>? offer;
  final Map<String, dynamic>? answer;

  const CallModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhoto,
    required this.type,
    required this.status,
    this.createdAt,
    this.endedAt,
    this.offer,
    this.answer,
  });

  bool get isVideo => type == 'video';

  Map<String, dynamic> toMap() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverPhoto': receiverPhoto,
      'type': type,
      'status': status.toValue(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'offer': offer,
      'answer': answer,
    };
  }

  factory CallModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return CallModel(
      id: doc.id,
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? 'Unknown',
      callerPhoto: data['callerPhoto'],
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? 'Unknown',
      receiverPhoto: data['receiverPhoto'],
      type: data['type'] ?? 'video',
      status: CallStatus.fromString(data['status']),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      endedAt: data['endedAt'] != null
          ? (data['endedAt'] as Timestamp).toDate()
          : null,
      offer: data['offer'] != null ? Map<String, dynamic>.from(data['offer']) : null,
      answer: data['answer'] != null ? Map<String, dynamic>.from(data['answer']) : null,
    );
  }

  CallModel copyWith({
    String? id,
    String? callerId,
    String? callerName,
    String? callerPhoto,
    String? receiverId,
    String? receiverName,
    String? receiverPhoto,
    String? type,
    CallStatus? status,
    DateTime? createdAt,
    DateTime? endedAt,
    Map<String, dynamic>? offer,
    Map<String, dynamic>? answer,
  }) {
    return CallModel(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerPhoto: callerPhoto ?? this.callerPhoto,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverPhoto: receiverPhoto ?? this.receiverPhoto,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      endedAt: endedAt ?? this.endedAt,
      offer: offer ?? this.offer,
      answer: answer ?? this.answer,
    );
  }
}
