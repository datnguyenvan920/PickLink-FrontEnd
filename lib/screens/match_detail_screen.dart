import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_api.dart';

/// Full-page match detail screen showing teams and lobby chat.
class MatchDetailScreen extends StatefulWidget {
  final int matchId;
  final AuthSession authSession;
  final bool isDarkMode;

  const MatchDetailScreen({
    super.key,
    required this.matchId,
    required this.authSession,
    required this.isDarkMode,
  });

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  MatchDetailDto? _detail;
  List<MatchMessageDto> _messages = [];
  bool _loadingDetail = true;
  bool _sendingMessage = false;
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await AuthApi().fetchMatchDetail(widget.authSession.token, widget.matchId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loadingDetail = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await AuthApi().fetchMatchMessages(widget.authSession.token, widget.matchId);
      if (!mounted) return;
      final oldLen = _messages.length;
      setState(() => _messages = msgs);
      if (msgs.length > oldLen) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _sendingMessage) return;

    setState(() => _sendingMessage = true);
    try {
      final sent = await AuthApi().sendMatchMessage(widget.authSession.token, widget.matchId, text);
      if (sent != null && mounted) {
        _msgController.clear();
        setState(() => _messages = [..._messages, sent]);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {}
    if (mounted) setState(() => _sendingMessage = false);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDarkMode;
    final bg = dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: dark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: dark ? Colors.white : const Color(0xFF111827)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Chi tiết trận đấu',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: dark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        centerTitle: true,
      ),
      body: _loadingDetail
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E)))
          : _detail == null
              ? Center(
                  child: Text(
                    'Không tìm thấy thông tin trận đấu.',
                    style: TextStyle(color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                  ),
                )
              : Column(
                  children: [
                    // Top: match info + teams (scrollable)
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(
                          children: [
                            _MatchInfoBanner(detail: _detail!, dark: dark),
                            const SizedBox(height: 16),
                            _TeamVsSection(detail: _detail!, dark: dark),
                          ],
                        ),
                      ),
                    ),

                    // Bottom: chat
                    Expanded(
                      flex: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: dark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Chat header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Row(children: [
                                Icon(Icons.chat_bubble_outline, size: 16, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                                const SizedBox(width: 6),
                                Text(
                                  'Trò chuyện',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: dark ? Colors.white : const Color(0xFF111827),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_messages.length} tin nhắn',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                  ),
                                ),
                              ]),
                            ),
                            Divider(color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB), height: 1),

                            // Messages list
                            Expanded(
                              child: _messages.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.forum_outlined, size: 40, color: dark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB)),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Chưa có tin nhắn',
                                            style: TextStyle(color: dark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF), fontSize: 13),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Hãy bắt đầu cuộc trò chuyện!',
                                            style: TextStyle(color: dark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB), fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      itemCount: _messages.length,
                                      itemBuilder: (_, i) => _ChatBubble(
                                        message: _messages[i],
                                        dark: dark,
                                        showAvatar: i == 0 || _messages[i].senderId != _messages[i - 1].senderId,
                                      ),
                                    ),
                            ),

                            // Input bar
                            Container(
                              padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
                              decoration: BoxDecoration(
                                color: dark ? const Color(0xFF1E293B) : Colors.white,
                                border: Border(top: BorderSide(color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB))),
                              ),
                              child: Row(children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: TextField(
                                      controller: _msgController,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: dark ? Colors.white : const Color(0xFF111827),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Nhập tin nhắn...',
                                        hintStyle: TextStyle(color: dark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF), fontSize: 14),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      onSubmitted: (_) => _sendMessage(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _sendMessage,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF059669)]),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(color: const Color(0xFF22C55E).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
                                      ],
                                    ),
                                    child: _sendingMessage
                                        ? const Padding(
                                            padding: EdgeInsets.all(10),
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                                  ),
                                ),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ─── Match Info Banner ────────────────────────────────────────────────────────

class _MatchInfoBanner extends StatelessWidget {
  final MatchDetailDto detail;
  final bool dark;

  const _MatchInfoBanner({required this.detail, required this.dark});

  @override
  Widget build(BuildContext context) {
    final statusColor = detail.status.toLowerCase() == 'scheduled'
        ? const Color(0xFF22C55E)
        : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [Colors.white, const Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              detail.status.toLowerCase() == 'scheduled' ? '✅ Đã xếp lịch' : '🗳 Đang bầu chọn',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
            ),
          ),
          const SizedBox(height: 12),
          // Info rows
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _infoChip(Icons.access_time, _formatTime(detail.matchTime), dark),
              if (detail.venueName != null)
                _infoChip(Icons.location_on_outlined, detail.venueName!, dark),
              if (detail.courtNumber != null)
                _infoChip(Icons.sports_tennis, 'Sân ${detail.courtNumber}', dark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, bool dark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151)),
        ),
      ],
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Team VS Section ──────────────────────────────────────────────────────────

class _TeamVsSection extends StatelessWidget {
  final MatchDetailDto detail;
  final bool dark;

  const _TeamVsSection({required this.detail, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Team 1
        Expanded(child: _TeamCard(team: detail.team1, dark: dark, color: const Color(0xFF3B82F6))),
        // VS divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.3), blurRadius: 8),
                  ],
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
                ),
              ),
            ],
          ),
        ),
        // Team 2
        Expanded(child: _TeamCard(team: detail.team2, dark: dark, color: const Color(0xFFEF4444))),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  final TeamDetailDto? team;
  final bool dark;
  final Color color;

  const _TeamCard({required this.team, required this.dark, required this.color});

  @override
  Widget build(BuildContext context) {
    if (team == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
        ),
        child: Center(
          child: Text('Chưa có đội', style: TextStyle(color: dark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF), fontSize: 12)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Team name header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              team!.teamName.replaceFirst(RegExp(r' – Match #\d+'), ''),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          const SizedBox(height: 10),
          // Player list
          ...team!.players.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.15),
                  backgroundImage: p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
                  child: p.avatarUrl == null
                      ? Text(
                          p.playerName.isNotEmpty ? p.playerName[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.playerName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ─── Chat Bubble ──────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final MatchMessageDto message;
  final bool dark;
  final bool showAvatar;

  const _ChatBubble({required this.message, required this.dark, required this.showAvatar});

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final time = '${message.sentAt.toLocal().hour.toString().padLeft(2, '0')}:'
        '${message.sentAt.toLocal().minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(
        bottom: 4,
        left: isMine ? 48 : 0,
        right: isMine ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Other user avatar
          if (!isMine && showAvatar)
            CircleAvatar(
              radius: 14,
              backgroundColor: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
              backgroundImage: message.senderAvatarUrl != null ? NetworkImage(message.senderAvatarUrl!) : null,
              child: message.senderAvatarUrl == null
                  ? Text(
                      message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151)),
                    )
                  : null,
            )
          else if (!isMine)
            const SizedBox(width: 28),
          if (!isMine) const SizedBox(width: 6),

          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showAvatar && !isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, left: 4),
                    child: Text(
                      message.senderName,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMine
                        ? const Color(0xFF22C55E)
                        : dark
                            ? const Color(0xFF374151)
                            : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message.content ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: isMine ? Colors.white : (dark ? const Color(0xFFE5E7EB) : const Color(0xFF111827)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Text(
                    time,
                    style: TextStyle(fontSize: 9, color: dark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
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
