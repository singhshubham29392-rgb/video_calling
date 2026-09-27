import 'package:flutter/material.dart';
import 'screens/outgoing_call_screen.dart';

class CallOptionsPage extends StatefulWidget {
  final String receiverUid;
  final String userName;
  final String? photoURL;

  const CallOptionsPage({
    super.key,
    required this.receiverUid,
    required this.userName,
    this.photoURL,
  });

  @override
  State<CallOptionsPage> createState() => _CallOptionsPageState();
}

class _CallOptionsPageState extends State<CallOptionsPage> {
  void _initiateCall(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OutgoingCallScreen(
          receiverUid: widget.receiverUid,
          receiverName: widget.userName,
          receiverPhoto: widget.photoURL,
          type: type,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.photoURL != null)
              CircleAvatar(
                backgroundImage: NetworkImage(widget.photoURL!),
                radius: 60,
              )
            else
              const CircleAvatar(
                radius: 60,
                child: Icon(Icons.person, size: 60),
              ),
            const SizedBox(height: 30),
            Text(
              widget.userName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallButton(
                  icon: Icons.call,
                  label: "Voice Call",
                  color: Colors.green,
                  onPressed: () => _initiateCall('voice'),
                ),
                _buildCallButton(
                  icon: Icons.videocam,
                  label: "Video Call",
                  color: const Color(0xFF246BFF),
                  onPressed: () => _initiateCall('video'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(24),
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          child: Icon(icon, size: 32),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
