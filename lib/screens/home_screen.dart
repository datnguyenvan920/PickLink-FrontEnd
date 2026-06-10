import 'dart:async';
import 'package:flutter/material.dart';

// ─── Enums & Models ──────────────────────────────────────────────────────────

enum PlayerTier { bronze, silver, gold, platinum, diamond }

class _Player {
  final int id;
  final String name;
  final String avatar;
  final double rating;
  final PlayerTier tier;
  final bool isCurrentUser;
  const _Player({required this.id, required this.name, required this.avatar, required this.rating, required this.tier, this.isCurrentUser = false});
}

class _AdPost {
  final int id;
  final bool isAd;
  final String brand;
  final String brandIcon;
  final String title;
  final String body;
  final String cta;
  final int likes;
  final int comments;
  const _AdPost({required this.id, required this.isAd, required this.brand, required this.brandIcon, required this.title, required this.body, required this.cta, required this.likes, required this.comments});
}

// ─── Tier helpers ─────────────────────────────────────────────────────────────

LinearGradient _tierGradient(PlayerTier t) {
  switch (t) {
    case PlayerTier.bronze:   return const LinearGradient(colors: [Color(0xFFB45309), Color(0xFFF59E0B)]);
    case PlayerTier.silver:   return const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFFCBD5E1)]);
    case PlayerTier.gold:     return const LinearGradient(colors: [Color(0xFFEAB308), Color(0xFFF59E0B)]);
    case PlayerTier.platinum: return const LinearGradient(colors: [Color(0xFF22D3EE), Color(0xFF2DD4BF)]);
    case PlayerTier.diamond:  return const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)]);
  }
}

String _tierName(PlayerTier t) {
  switch (t) {
    case PlayerTier.bronze:   return 'Bronze';
    case PlayerTier.silver:   return 'Silver';
    case PlayerTier.gold:     return 'Gold';
    case PlayerTier.platinum: return 'Platinum';
    case PlayerTier.diamond:  return 'Diamond';
  }
}

Color _tierTextColor(PlayerTier t) {
  switch (t) {
    case PlayerTier.bronze:   return const Color(0xFFFDE68A);
    case PlayerTier.silver:   return const Color(0xFFF1F5F9);
    case PlayerTier.gold:     return const Color(0xFFFEF9C3);
    case PlayerTier.platinum: return const Color(0xFFCFFAFE);
    case PlayerTier.diamond:  return const Color(0xFFEDE9FE);
  }
}

IconData _tierIcon(PlayerTier t) {
  switch (t) {
    case PlayerTier.diamond:  return Icons.diamond_outlined;
    case PlayerTier.platinum: return Icons.star_outline;
    case PlayerTier.gold:     return Icons.emoji_events_outlined;
    default:                  return Icons.bolt_outlined;
  }
}

// ─── Static Data ─────────────────────────────────────────────────────────────

const _initialPlayers = <_Player?>[
  _Player(id: 1, name: 'Minh Tú', avatar: 'MT', rating: 4.2, tier: PlayerTier.gold, isCurrentUser: true),
  _Player(id: 2, name: 'Lan Anh', avatar: 'LA', rating: 3.8, tier: PlayerTier.silver),
  null,
  null,
];

const _adPosts = [
  _AdPost(id: 1, isAd: true,  brand: 'PicklePro Gear',         brandIcon: '🏓', title: 'Mùa hè này – Nâng cấp cú đánh của bạn!',    body: 'Bộ vợt PicklePro Carbon Series giảm 30% – chỉ trong tuần này. Nhẹ hơn, kiểm soát tốt hơn.', cta: 'Mua ngay',     likes: 142, comments: 18),
  _AdPost(id: 2, isAd: false, brand: 'Hà Nội Pickleball Club', brandIcon: '🏅', title: 'Giải đấu cuối tuần – Đăng ký còn 3 suất', body: 'Sân Cầu Giấy Arena • Chủ Nhật 08/06 • Giải thưởng lên tới 5 triệu đồng.',                 cta: 'Đăng ký',      likes: 87,  comments: 34),
  _AdPost(id: 3, isAd: true,  brand: 'SportDrink VN',           brandIcon: '⚡', title: 'Giữ phong độ suốt trận đấu',              body: 'SportDrink Electrolyte – bù nước nhanh, cung cấp năng lượng tức thì. Thử ngay miễn phí!',  cta: 'Nhận mẫu thử', likes: 203, comments: 9),
];

// ─── Home Screen ──────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  const HomeScreen({super.key, required this.isDarkMode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showMapModal = false;
  String _locationLabel = 'Hà Nội';
  String _locationDistance = '3km';
  bool _searching = false;
  List<_Player?> _players = List.from(_initialPlayers);
  Timer? _searchTimer;

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _findMatch() {
    setState(() => _searching = true);
    _searchTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() {
        final idx = _players.indexWhere((p) => p == null);
        if (idx != -1) {
          _players = List.from(_players);
          _players[idx] = const _Player(id: 99, name: 'Quang Hải', avatar: 'QH', rating: 4.5, tier: PlayerTier.platinum);
        }
        _searching = false;
      });
    });
  }

  void _leaveSearch() {
    _searchTimer?.cancel();
    setState(() { _searching = false; _players = List.from(_initialPlayers); });
  }

  int get _filled => _players.where((p) => p != null).length;

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDarkMode;

    return Stack(
      children: [
        // Main scrollable content
        SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeTopBar(dark: dark, label: _locationLabel, distance: _locationDistance, onLocationTap: () => setState(() => _showMapModal = true)),
              _LobbySection(dark: dark, players: _players, filled: _filled, searching: _searching, onFindMatch: _findMatch, onLeave: _leaveSearch),
              _Divider(dark: dark),
              _AdsFeed(dark: dark),
            ],
          ),
        ),
        // Map modal overlay
        if (_showMapModal)
          _MockMapModal(
            dark: dark,
            onClose: () => setState(() => _showMapModal = false),
            onConfirm: (label) => setState(() { _locationLabel = label; _locationDistance = 'Tuỳ chỉnh'; _showMapModal = false; }),
          ),
      ],
    );
  }
}

// ─── Top Bar ─────────────────────────────────────────────────────────────────

class _HomeTopBar extends StatelessWidget {
  final bool dark;
  final String label;
  final String distance;
  final VoidCallback onLocationTap;
  const _HomeTopBar({required this.dark, required this.label, required this.distance, required this.onLocationTap});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1F2937) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: border))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Location pill
          GestureDetector(
            onTap: onLocationTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF22C55E)),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dark ? Colors.white : const Color(0xFF111827))),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                  child: Text(distance, style: const TextStyle(fontSize: 9, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_outlined, size: 13, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              ]),
            ),
          ),
          // Branding
          Row(children: [
            Container(
              width: 30, height: 30,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4ADE80), Color(0xFF059669)]), shape: BoxShape.circle),
              child: const Center(child: Text('PB', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 5),
            Text('PickleMatch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))),
          ]),
        ],
      ),
    );
  }
}

// ─── Lobby Section ────────────────────────────────────────────────────────────

class _LobbySection extends StatelessWidget {
  final bool dark;
  final List<_Player?> players;
  final int filled;
  final bool searching;
  final VoidCallback onFindMatch;
  final VoidCallback onLeave;

  const _LobbySection({required this.dark, required this.players, required this.filled, required this.searching, required this.onFindMatch, required this.onLeave});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('🏓 Phòng chờ trận', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dark ? Colors.white : const Color(0xFF111827))),
                const SizedBox(height: 2),
                Text('$filled/4 người chơi đã sẵn sàng', style: TextStyle(fontSize: 11, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
              ]),
              _SearchingBadge(dark: dark, searching: searching),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: filled / 4,
              minHeight: 6,
              backgroundColor: dark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
            ),
          ),
          const SizedBox(height: 20),
          // 2×2 Player grid
          GridView.count(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 0.88,
            children: List.generate(4, (i) => _PlayerSlot(player: players[i], index: i, dark: dark)),
          ),
          const SizedBox(height: 20),
          // VS divider
          Row(children: [
            Expanded(child: Divider(color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB))),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: dark ? const Color(0xFF374151) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(14)),
              child: Text('VS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280))),
            ),
            Expanded(child: Divider(color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB))),
          ]),
          const SizedBox(height: 20),
          // Court info
          _CourtCard(dark: dark),
          const SizedBox(height: 14),
          // Action buttons
          Row(children: [
            Expanded(
              child: searching
                  ? OutlinedButton(
                      onPressed: onLeave,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFF87171), width: 2),
                        foregroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Hủy tìm', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  : ElevatedButton(
                      onPressed: filled == 4 ? null : onFindMatch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: filled == 4 ? const Color(0xFFD1D5DB) : const Color(0xFF22C55E),
                        disabledBackgroundColor: const Color(0xFFD1D5DB),
                        foregroundColor: filled == 4 ? const Color(0xFF9CA3AF) : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: filled == 4 ? 0 : 4,
                        shadowColor: const Color(0x6622C55E),
                      ),
                      child: Text(filled == 4 ? '🎉 Đủ người!' : '🔍 Tìm người chơi', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB), width: 2),
                foregroundColor: dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                padding: const EdgeInsets.all(13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Icon(Icons.people_outline, size: 18),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Searching Badge (animated) ───────────────────────────────────────────────

class _SearchingBadge extends StatefulWidget {
  final bool dark;
  final bool searching;
  const _SearchingBadge({required this.dark, required this.searching});

  @override
  State<_SearchingBadge> createState() => _SearchingBadgeState();
}

class _SearchingBadgeState extends State<_SearchingBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _fade = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF14532D).withValues(alpha: 0.35) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? const Color(0xFF166534) : const Color(0xFFBBF7D0)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        FadeTransition(
          opacity: widget.searching ? _fade : const AlwaysStoppedAnimation(1.0),
          child: Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: widget.searching ? const Color(0xFF22C55E) : dark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          widget.searching ? 'Đang tìm…' : 'Chờ',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: widget.searching ? const Color(0xFF22C55E) : dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
        ),
      ]),
    );
  }
}

// ─── Player Slot ─────────────────────────────────────────────────────────────

class _PlayerSlot extends StatelessWidget {
  final _Player? player;
  final int index;
  final bool dark;
  const _PlayerSlot({required this.player, required this.index, required this.dark});

  @override
  Widget build(BuildContext context) {
    if (player == null) {
      return Container(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF374151).withValues(alpha: 0.5) : const Color(0xFFF3F4F6).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB), width: 2),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: dark ? const Color(0xFF6B7280) : const Color(0xFFD1D5DB), width: 2)),
            child: Center(child: Text('+', style: TextStyle(fontSize: 22, color: dark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)))),
          ),
          const SizedBox(height: 6),
          Text('Chờ người chơi', style: TextStyle(fontSize: 10, color: dark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF))),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(10)),
            child: Text('Slot ${index + 1}', style: TextStyle(fontSize: 9, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
          ),
        ]),
      );
    }

    final p = player!;
    final grad = _tierGradient(p.tier);
    final tc = _tierTextColor(p.tier);

    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF374151) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.isCurrentUser ? const Color(0xFF4ADE80) : dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB), width: p.isCurrentUser ? 2 : 1),
        boxShadow: p.isCurrentUser ? [const BoxShadow(color: Color(0x4D4ADE80), blurRadius: 12)] : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(gradient: grad, shape: BoxShape.circle),
            child: Center(child: Text(p.avatar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
          ),
          if (p.isCurrentUser)
            Positioned(top: -4, right: -4,
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(color: const Color(0xFF22C55E), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: const Center(child: Text('Y', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold))),
              )),
        ]),
        const SizedBox(height: 5),
        Text(p.name, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: dark ? Colors.white : const Color(0xFF111827))),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(gradient: grad, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_tierIcon(p.tier), size: 9, color: tc),
            const SizedBox(width: 2),
            Text(_tierName(p.tier), style: TextStyle(fontSize: 8, color: tc, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.star, size: 9, color: Color(0xFFFACC15)),
          const SizedBox(width: 2),
          Text(p.rating.toStringAsFixed(1), style: TextStyle(fontSize: 9, color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563))),
        ]),
      ]),
    );
  }
}

// ─── Court Card ───────────────────────────────────────────────────────────────

class _CourtCard extends StatelessWidget {
  final bool dark;
  const _CourtCard({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF374151).withValues(alpha: 0.6) : const Color(0xFFF0FDF4).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? const Color(0xFF4B5563) : const Color(0xFFBBF7D0)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF4ADE80), Color(0xFF059669)]), borderRadius: BorderRadius.circular(10)),
          child: const Center(child: Text('🏟️', style: TextStyle(fontSize: 17))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sân Cầu Giấy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: dark ? Colors.white : const Color(0xFF111827))),
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.access_time, size: 9, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
            const SizedBox(width: 3),
            Text('Hôm nay, 18:00 · 1.2 km', style: TextStyle(fontSize: 10, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Phí/người', style: TextStyle(fontSize: 9, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
          Text('50K', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))),
        ]),
      ]),
    );
  }
}

// ─── Ads/Posts Divider ────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  final bool dark;
  const _Divider({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Expanded(child: Divider(color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            Icon(Icons.campaign_outlined, size: 13, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
            const SizedBox(width: 4),
            Text('Khuyến mãi & Sự kiện', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
          ]),
        ),
        Expanded(child: Divider(color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB))),
      ]),
    );
  }
}

// ─── Ads Feed ─────────────────────────────────────────────────────────────────

class _AdsFeed extends StatelessWidget {
  final bool dark;
  const _AdsFeed({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        children: _adPosts.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _AdCard(post: p, dark: dark),
        )).toList(),
      ),
    );
  }
}

class _AdCard extends StatefulWidget {
  final _AdPost post;
  final bool dark;
  const _AdCard({required this.post, required this.dark});

  @override
  State<_AdCard> createState() => _AdCardState();
}

class _AdCardState extends State<_AdCard> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final p = widget.post;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final cardBg = dark ? const Color(0xFF1F2937) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: dark ? null : [const BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(children: [
        // Brand header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(
                width: 34, height: 34,
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4ADE80), Color(0xFF059669)]), shape: BoxShape.circle),
                child: Center(child: Text(p.brandIcon, style: const TextStyle(fontSize: 15))),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.brand, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: dark ? Colors.white : const Color(0xFF111827))),
                Text(p.isAd ? '🔖 Quảng cáo' : '📣 Thông báo', style: TextStyle(fontSize: 9, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
              ]),
            ]),
            if (p.isAd)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                child: const Text('Được tài trợ', style: TextStyle(fontSize: 9, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        Divider(height: 1, color: border),
        // Content
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Banner
            Container(
              height: 110, width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFF22C55E).withValues(alpha: 0.15), const Color(0xFF2DD4BF).withValues(alpha: 0.08)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
              ),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(p.brandIcon, style: const TextStyle(fontSize: 34)),
                const SizedBox(height: 3),
                Text(p.brand, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563))),
              ])),
            ),
            const SizedBox(height: 10),
            Text(p.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: dark ? Colors.white : const Color(0xFF111827))),
            const SizedBox(height: 3),
            Text(p.body, style: TextStyle(fontSize: 11, height: 1.5, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563))),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  shadowColor: const Color(0x4422C55E),
                ),
                child: Text(p.cta, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ]),
        ),
        Divider(height: 1, color: border),
        // Action row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            GestureDetector(
              onTap: () => setState(() => _liked = !_liked),
              child: Row(children: [
                Icon(Icons.favorite, size: 15, color: _liked ? const Color(0xFFEF4444) : dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text('${p.likes + (_liked ? 1 : 0)}', style: TextStyle(fontSize: 11, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563))),
              ]),
            ),
            const SizedBox(width: 14),
            Row(children: [
              Icon(Icons.chat_bubble_outline, size: 15, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text('${p.comments}', style: TextStyle(fontSize: 11, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563))),
            ]),
            const Spacer(),
            Icon(Icons.share_outlined, size: 15, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
          ]),
        ),
      ]),
    );
  }
}

// ─── Mock Map Modal ───────────────────────────────────────────────────────────

class _MockMapModal extends StatelessWidget {
  final bool dark;
  final VoidCallback onClose;
  final ValueChanged<String> onConfirm;
  const _MockMapModal({required this.dark, required this.onClose, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final hdrBg = dark ? const Color(0xFF111827) : Colors.white;
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Column(children: [
        // Header
        Container(
          color: hdrBg,
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Chọn khu vực tìm trận', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: dark ? Colors.white : const Color(0xFF111827))),
              Text('Nhấn để đặt vị trí thủ công', style: TextStyle(fontSize: 11, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
            ]),
            IconButton(onPressed: onClose, icon: Icon(Icons.close, color: dark ? Colors.white : const Color(0xFF1F2937))),
          ]),
        ),
        // Map canvas
        Expanded(child: Stack(children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF065F46), Color(0xFF0F766E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
          CustomPaint(painter: _GridPainter(), size: Size.infinite),
          // Centre pin
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.85), shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFF22C55E).withValues(alpha: 0.5), blurRadius: 20)]),
              child: const Icon(Icons.location_on, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 8),
            const Text('Hà Nội', style: TextStyle(color: Color(0xFFBBF7D0), fontSize: 12, fontWeight: FontWeight.w600)),
          ])),
          // Fake venue dots
          ...const [Alignment(-0.6, -0.5), Alignment(0.5, -0.2), Alignment(-0.7, 0.4), Alignment(0.6, 0.5), Alignment(0.2, -0.7)].map(
            (a) => Align(alignment: a, child: Container(width: 11, height: 11,
              decoration: const BoxDecoration(color: Color(0xFFFACC15), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x80FACC15), blurRadius: 6)]))),
          ),
          Positioned(bottom: 12, left: 0, right: 0, child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
              child: const Text('Thêm API key Google Maps để tương tác đầy đủ', style: TextStyle(color: Colors.white70, fontSize: 10)),
            ),
          )),
        ])),
        // Confirm
        Container(
          color: hdrBg,
          padding: const EdgeInsets.all(14),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onConfirm('Hà Nội'),
              icon: const Icon(Icons.location_on_outlined, size: 17),
              label: const Text('Xác nhận vị trí: Hà Nội', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: const Color(0x6622C55E),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.07)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 40) { canvas.drawLine(Offset(x, 0), Offset(x, size.height), p); }
    for (double y = 0; y < size.height; y += 40) { canvas.drawLine(Offset(0, y), Offset(size.width, y), p); }
  }
  @override bool shouldRepaint(_GridPainter _) => false;
}
