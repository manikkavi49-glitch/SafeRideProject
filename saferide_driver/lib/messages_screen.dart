import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'chat_page.dart';

class MessagesScreen extends StatefulWidget {
  final bool isTripActive;
  const MessagesScreen({super.key, required this.isTripActive});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String? _vanId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVanId();
  }

  // Driver ගේ Firebase record එකෙන් vanId dynamically read කරනවා
  Future<void> _loadVanId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _vanId = 'van01'; _loading = false; });
      return;
    }
    try {
      final snap = await FirebaseDatabase.instance.ref('drivers/${user.uid}').get();
      if (snap.exists) {
        final d = snap.value as Map;
        final v = d['vanId']?.toString() ??
            (d['profile'] as Map?)?['vehicle']?.toString();
        setState(() {
          _vanId = (v != null && v.isNotEmpty) ? v.toLowerCase() : 'van01';
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    setState(() { _vanId = 'van01'; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final vanId = _vanId!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Parent Chats · ${vanId.toUpperCase()}',
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder(
        // මේ van එකේ students විතරක් filter කරනවා vanId by
        stream: FirebaseDatabase.instance
            .ref('students')
            .orderByChild('vanId')
            .equalTo(vanId)
            .onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> studentSnapshot) {
          if (!studentSnapshot.hasData ||
              studentSnapshot.data!.snapshot.value == null) {
            return Center(
              child: Text(
                'No students assigned to ${vanId.toUpperCase()} yet.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }

          final studentData = Map<dynamic, dynamic>.from(
              studentSnapshot.data!.snapshot.value as Map);
          final List<Map<String, dynamic>> studentList = studentData.entries.map((e) {
            final v = e.value as Map;
            return {
              'id': e.key,
              'name': v['name'] ?? 'Unknown Student',
              'parentEmail': v['parentEmail'] ?? '',
            };
          }).toList();

          if (studentList.isEmpty) {
            return Center(
              child: Text(
                'No students assigned to ${vanId.toUpperCase()} yet.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }

          return ListView.builder(
            itemCount: studentList.length,
            itemBuilder: (context, index) {
              final student = studentList[index];

              return StreamBuilder(
                // ඒ van ේ messages path ේ last message preview
                stream: FirebaseDatabase.instance
                    .ref('messages/$vanId')
                    .orderByChild('parentEmail')
                    .equalTo(student['parentEmail'])
                    .limitToLast(1)
                    .onValue,
                builder: (context, AsyncSnapshot<DatabaseEvent> msgSnapshot) {
                  String lastMsg = 'Start a conversation';
                  if (msgSnapshot.hasData &&
                      msgSnapshot.data!.snapshot.value != null) {
                    final msgData = Map<dynamic, dynamic>.from(
                        msgSnapshot.data!.snapshot.value as Map);
                    lastMsg = msgData.values.first['text'] ?? '';
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade600,
                      child: Text(
                        student['name'][0],
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      student['name'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    subtitle: Text(
                      lastMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatPage(
                            parentName: student['name'],
                            parentEmail: student['parentEmail'],
                            vanId: vanId, // dynamic — van01 hardcode නෙවෙයි
                          ),
                        ),
                      );
                    },
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