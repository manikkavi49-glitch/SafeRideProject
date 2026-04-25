import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class MessagesScreen extends StatefulWidget {
  final bool isTripActive;
  const MessagesScreen({super.key, required this.isTripActive});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final DatabaseReference _messagesRef =
      FirebaseDatabase.instance.ref("messages/van01");

  // Pre-defined quick replies — driver taps one, it sends instantly
  final List<String> _quickReplies = [
    "I am 5 minutes away 🚌",
    "Stuck in traffic, please wait",
    "On my way now",
    "Arrived at school",
    "Trip completed — all students delivered safely ✅",
    "Running 10 minutes late",
    "Please wait at the pickup point",
  ];

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _listenToMessages();
  }

  void _listenToMessages() {
    _messagesRef.orderByChild('timestamp').limitToLast(50).onValue.listen(
      (event) {
        final data = event.snapshot.value as Map?;
        if (data == null) {
          setState(() {
            _messages = [];
            _loading = false;
          });
          return;
        }

        final List<Map<String, dynamic>> parsed = [];
        data.forEach((key, value) {
          if (value is Map) {
            parsed.add({
              'id': key,
              'sender': value['sender'] ?? 'Parent',
              'text': value['text'] ?? '',
              'timestamp': value['timestamp'] ?? 0,
              'fromDriver': value['fromDriver'] == true,
            });
          }
        });

        // Sort by timestamp ascending
        parsed.sort((a, b) =>
            (a['timestamp'] as int).compareTo(b['timestamp'] as int));

        setState(() {
          _messages = parsed;
          _loading = false;
        });
      },
    );
  }

  Future<void> _sendQuickReply(String text) async {
    await _messagesRef.push().set({
      'sender': 'Driver',
      'text': text,
      'fromDriver': true,
      'timestamp': ServerValue.timestamp,
    });
  }

  String _formatTime(int timestamp) {
    if (timestamp == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: Column(
        children: [
          // Quick replies section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Replies',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickReplies.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _sendQuickReply(_quickReplies[index]),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade700,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _quickReplies[index],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Message thread
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'No messages yet',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isFromDriver = msg['fromDriver'] == true;
                          return _MessageBubble(
                            text: msg['text'],
                            sender: msg['sender'],
                            time: _formatTime(msg['timestamp'] as int),
                            isFromDriver: isFromDriver,
                          );
                        },
                      ),
          ),

          // Driver cannot type freely — quick replies only (road safety)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: Colors.black38),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Use quick replies above to respond safely while driving.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final String sender;
  final String time;
  final bool isFromDriver;

  const _MessageBubble({
    required this.text,
    required this.sender,
    required this.time,
    required this.isFromDriver,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          isFromDriver ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              isFromDriver ? Colors.green.shade600 : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isFromDriver ? 16 : 4),
            bottomRight: Radius.circular(isFromDriver ? 4 : 16),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isFromDriver)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  sender,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: isFromDriver ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 11,
                color: isFromDriver
                    ? Colors.white60
                    : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
