import 'package:flutter_test/flutter_test.dart';
import 'package:video_calling/models/call_model.dart';

void main() {
  test('CallModel serialization and status conversion', () {
    const call = CallModel(
      id: 'call_123',
      callerId: 'user_a',
      callerName: 'User A',
      receiverId: 'user_b',
      receiverName: 'User B',
      type: 'video',
      status: CallStatus.ringing,
    );

    final map = call.toMap();
    expect(map['callerId'], 'user_a');
    expect(map['receiverId'], 'user_b');
    expect(map['status'], 'ringing');
    expect(map['type'], 'video');
    expect(CallStatus.fromString('connected'), CallStatus.connected);
    expect(CallStatus.fromString('rejected'), CallStatus.rejected);
  });
}
