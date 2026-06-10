import 'package:flutter/material.dart';

class _Comment {
  final int id;
  final String author;
  final String avatar;
  final String text;
  final String time;
  final int likes;
  const _Comment({required this.id, required this.author, required this.avatar, required this.text, required this.time, required this.likes});
}

class CommentBottomSheet extends StatefulWidget {
  final bool isDarkMode;
  final String postAuthor;
  const CommentBottomSheet({super.key, required this.isDarkMode, required this.postAuthor});

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<_Comment> _comments = const [
    _Comment(id: 1, author: 'Emma Wilson',   avatar: 'EW', text: 'This is awesome! Count me in for the next session! 🎯', time: '1h ago', likes: 5),
    _Comment(id: 2, author: 'David Lee',     avatar: 'DL', text: 'I\'m interested! What skill level are you looking for?',  time: '45m ago', likes: 3),
    _Comment(id: 3, author: 'Lisa Martinez', avatar: 'LM', text: 'Great initiative! I\'ve been looking for regular badminton partners.', time: '30m ago', likes: 7),
    _Comment(id: 4, author: 'Tom Brown',     avatar: 'TB', text: 'Saturdays work perfectly for me! See you there! 🏸', time: '15m ago', likes: 2),
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
    setState(() {
      _comments = [
        ..._comments,
        _Comment(id: _comments.length + 1, author: 'You', avatar: 'YO', text: text, time: 'Just now', likes: 0),
      ];
    });
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDarkMode;
    final bg   = dark ? const Color(0xFF1F2937) : Colors.white;
    final hdrBg = dark ? const Color(0xFF374151) : Colors.white;
    final divider = dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB);
    final textColor = dark ? Colors.white : const Color(0xFF111827);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
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
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: BoxDecoration(
                color: hdrBg,
                border: Border(bottom: BorderSide(color: divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Comments', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: textColor)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563))),
                ],
              ),
            ),
            // Comments list
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _comments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, i) => _CommentTile(comment: _comments[i], dark: dark),
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
                  // Your avatar
                  Container(
                    width: 32, height: 32,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF4ADE80), Color(0xFF22C55E)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(child: Text('YO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      style: TextStyle(fontSize: 13, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: TextStyle(fontSize: 13, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF9CA3AF)),
                        filled: true,
                        fillColor: dark ? const Color(0xFF4B5563) : const Color(0xFFF3F4F6),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (_, val, __) {
                      final hasText = val.text.trim().isNotEmpty;
                      return GestureDetector(
                        onTap: hasText ? _send : null,
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: hasText ? const Color(0xFF22C55E) : dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.send_rounded, size: 16, color: hasText ? Colors.white : const Color(0xFF9CA3AF)),
                        ),
                      );
                    },
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

class _CommentTile extends StatelessWidget {
  final _Comment comment;
  final bool dark;
  const _CommentTile({required this.comment, required this.dark});

  @override
  Widget build(BuildContext context) {
    final isMe = comment.author == 'You';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isMe ? [const Color(0xFF4ADE80), const Color(0xFF22C55E)] : [const Color(0xFF60A5FA), const Color(0xFF2563EB)],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(comment.avatar, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comment.author, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: dark ? Colors.white : const Color(0xFF111827))),
                    const SizedBox(height: 2),
                    Text(comment.text, style: TextStyle(fontSize: 13, color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151))),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(comment.time, style: TextStyle(fontSize: 11, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
                  const SizedBox(width: 12),
                  Text('Like', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563))),
                  const SizedBox(width: 12),
                  Text('Reply', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563))),
                  if (comment.likes > 0) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.favorite, size: 11, color: Color(0xFFEF4444)),
                    const SizedBox(width: 2),
                    Text('${comment.likes}', style: TextStyle(fontSize: 11, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
