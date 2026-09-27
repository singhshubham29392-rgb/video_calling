import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';
import 'login_page.dart';
import 'call_options_page.dart';
import 'models/call_model.dart';
import 'services/call_service.dart';
import 'screens/incoming_call_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CallService _callService = CallService();
  StreamSubscription<List<CallModel>>? _incomingCallSubscription;
  String? _activeIncomingCallId;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _listenForIncomingCalls();
  }

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  void _listenForIncomingCalls() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _incomingCallSubscription =
        _callService.listenForIncomingCalls(currentUser.uid).listen((calls) {
      if (!mounted || calls.isEmpty) return;

      final incomingCall = calls.first;

      if (_activeIncomingCallId != incomingCall.id) {
        _activeIncomingCallId = incomingCall.id;
        _navigateToIncomingCallScreen(incomingCall);
      }
    });
  }

  Future<void> _navigateToIncomingCallScreen(CallModel call) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IncomingCallScreen(call: call),
      ),
    );
    _activeIncomingCallId = null;
  }

  Future<void> _logout(BuildContext context) async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Users"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No users found"));
          }

          final users = snapshot.data!.docs.where((doc) => doc.id != currentUser?.uid).toList();

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final String name = userData['displayName'] ?? "Unknown";
              final String? photo = userData['photoURL'];
              final String uid = userData['uid'];

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: photo != null ? NetworkImage(photo) : null,
                  child: photo == null ? const Icon(Icons.person) : null,
                ),
                title: Text(name),
                subtitle: Text(userData['email'] ?? ""),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CallOptionsPage(
                        receiverUid: uid,
                        userName: name,
                        photoURL: photo,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
