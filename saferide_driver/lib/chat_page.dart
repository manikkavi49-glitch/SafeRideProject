import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ChatPage extends StatefulWidget {
  final String parentName;
  final String parentEmail;
  final String vanId;

  const ChatPage({super.key, required this.parentName, required this.parentEmail, required this.vanId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late DatabaseReference _chatRef;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chatRef = FirebaseDatabase.instance.ref("messages/${widget.vanId}");
  }

void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    
    // මෙහිදී parentEmail එක අනිවාර්යයෙන්ම ඇතුළත් කළ යුතුයි
    _chatRef.push().set({
      'parentName': widget.parentName,
      'parentEmail': widget.parentEmail, // මෙය ඉතා වැදගත්
      'text': _controller.text,
      'fromDriver': true,
      'timestamp': ServerValue.timestamp,
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... AppBar කොටස ...
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              // මෙහිදී parentEmail එක පදනම් කරගෙන query එක සිදුකරයි
              stream: _chatRef.orderByChild('parentEmail').equalTo(widget.parentEmail).onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                  final data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
                  
                  // පණිවිඩ ලිස්ට් එකකට ගෙන කාලය අනුව sort කිරීම
                  final messages = data.entries.map((e) => Map<String, dynamic>.from(e.value)).toList();
                  messages.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));

                  return ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      // පණිවිඩය එවුවේ රියදුරුද නැද්ද යන්න පරීක්ෂා කිරීම
                      bool isMe = msg['fromDriver'] == true;

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.green.shade600 : Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: isMe ? null : Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            msg['text'] ?? "",
                            style: TextStyle(color: isMe ? Colors.white : Colors.black),
                          ),
                        ),
                      );
                    },
                  );
                }
                return const Center(child: Text("No messages yet. Send a message to start."));
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: "Type a message...", border: InputBorder.none),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Colors.green), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}