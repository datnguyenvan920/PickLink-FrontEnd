import 'package:flutter/material.dart';

class ChatBottomSheet extends StatefulWidget {
  final bool isDarkMode;
  final String otherUserName;
  final String otherUserAvatar;
  final bool online;

  const ChatBottomSheet({
    super.key,
    required this.isDarkMode,
    required this.otherUserName,
    required this.otherUserAvatar,
    this.online = true,
  });

  @override
  State<ChatBottomSheet> createState() => _ChatBottomSheetState();
}

class _Message {
  final int id;
  final String text;
  final bool isMe;
  final String time;
  const _Message({required this.id, required this.text, required this.isMe, required this.time});
}

class _ChatBottomSheetState extends State<ChatBottomSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<_Message> _messages = const [
    _Message(id: 1, text: 'Hey! Are you available for a match tomorrow?', isMe: false, time: '10:30 AM'),
    _Message(id: 2, text: 'Sure! What time works for you?',                isMe: true,  time: '10:32 AM'),
    _Message(id: 3, text: 'How about 6 PM at Central Stadium?',            isMe: false, time: '10:33 AM'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final now = TimeOfDay.now();
    final h = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final m = now.minute.toString().padLeft(2, '0');
    final period = now.period == DayPeriod.am ? 'AM' : 'PM';

    setState(() {
      _messages = [
        ..._messages,
        _Message(id: _messages.length + 1, text: text, isMe: true, time: '$h:$m $period'),
      ];
    });
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDarkMode;
    final bg    = dark ? const Color(0xFF1F2937) : Colors.white;
    final hdrBg = dark ? const Color(0xFF374151) : Colors.white;
    final divider = dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              decoration: BoxDecoration(
                color: hdrBg,
                border: Border(bottom: BorderSide(color: divider)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF4ADE80), Color(0xFF059669)]),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(widget.otherUserAvatar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.otherUserName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: dark ? Colors.white : const Color(0xFF111827))),
                        Text(widget.online ? 'Active now' : 'Offline', style: TextStyle(fontSize: 11, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563))),
                ],
              ),
            ),
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _MessageBubble(message: _messages[i], dark: dark),
              ),
            ),
            // Input
            Container(
              padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).viewInsets.bottom + 12),
              decoration: BoxDecoration(
                color: hdrBg,
                border: Border(top: BorderSide(color: divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      style: TextStyle(fontSize: 13, color: dark ? Colors.white : const Color(0xFF111827)),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(fontSize: 13, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF9CA3AF)),
                        filled: true,
                        fillColor: dark ? const Color(0xFF4B5563) : const Color(0xFFF3F4F6),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _Message message;
  final bool dark;
  const _MessageBubble({required this.message, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: message.isMe
                    ? const Color(0xFF22C55E)
                    : dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isMe ? 16 : 4),
                  bottomRight: Radius.circular(message.isMe ? 4 : 16),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(fontSize: 13, color: message.isMe ? Colors.white : dark ? Colors.white : const Color(0xFF111827)),
              ),
            ),
            const SizedBox(height: 2),
            Text(message.time, style: TextStyle(fontSize: 10, color: dark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }
}
