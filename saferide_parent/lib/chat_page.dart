import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ChatPage extends StatefulWidget {
  final String vanId;
  final String parentEmail; // මෙය අලුතින් එක් කරන්න
  final String parentName;  // මෙය අලුතින් එක් කරන්න
  
  const ChatPage({
    super.key, 
    required this.vanId, 
    required this.parentEmail, 
    required this.parentName
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  late DatabaseReference _chatRef;

  @override
  void initState() {
    super.initState();
    // Connect to the same path used by the driver app
    _chatRef = FirebaseDatabase.instance.ref("messages/${widget.vanId}");
  }

 void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    // Driver App එකේ query එකට ගැලපෙන සේ 'parentEmail' අනිවාර්යයෙන්ම ඇතුළත් කරන්න
    await _chatRef.push().set({
      'parentName': widget.parentName,    // රියදුරුට හඳුනා ගැනීමට
      'parentEmail': widget.parentEmail, // Driver app එකේ filter එකට අවශ්‍ය වේ
      'text': _controller.text.trim(),
      'fromDriver': false, 
      'timestamp': ServerValue.timestamp,
    });

    _controller.clear();
  }

  String _formatTime(int timestamp) {
    if (timestamp == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chat: ${widget.vanId}"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _chatRef.orderByChild('timestamp').onValue,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                  final data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
                  final messages = data.entries.map((e) => Map<String, dynamic>.from(e.value)).toList();
                  
                  // Sort by time
                  messages.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isDriver = msg['fromDriver'] == true;
                      
                      return Align(
                        alignment: isDriver ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDriver ? Colors.white : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                          ),
                          child: Column(
                            crossAxisAlignment: isDriver ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                            children: [
                              Text(msg['text'], style: const TextStyle(fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(msg['timestamp'] ?? 0),
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
                return const Center(child: Text("No messages yet."));
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type to driver...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  mini: true,
                  backgroundColor: Colors.green.shade700,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}