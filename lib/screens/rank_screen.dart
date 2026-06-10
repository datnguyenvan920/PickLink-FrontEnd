import 'package:flutter/material.dart';

class RankScreen extends StatefulWidget {
  final bool isDarkMode;
  const RankScreen({super.key, required this.isDarkMode});

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankPlayer {
  final int id;
  final String username;
  final int rating;
  final String avatar;
  const _RankPlayer({required this.id, required this.username, required this.rating, required this.avatar});
}

class _RankScreenState extends State<RankScreen> {
  static const _currentUserRank = 8;
  final _scrollController = ScrollController();
  final _userRankKey = GlobalKey();
  String _floatPos = 'bottom'; // 'none' | 'top' | 'bottom'

  static const _players = [
    _RankPlayer(id:  1, username: 'ProPlayer99',  rating: 2850, avatar: 'PP'),
    _RankPlayer(id:  2, username: 'SportMaster',  rating: 2720, avatar: 'SM'),
    _RankPlayer(id:  3, username: 'AceStriker',   rating: 2650, avatar: 'AS'),
    _RankPlayer(id:  4, username: 'QuickShot',    rating: 2580, avatar: 'QS'),
    _RankPlayer(id:  5, username: 'GameChanger',  rating: 2540, avatar: 'GC'),
    _RankPlayer(id:  6, username: 'ThunderBolt',  rating: 2490, avatar: 'TB'),
    _RankPlayer(id:  7, username: 'NinjaKick',    rating: 2450, avatar: 'NK'),
    _RankPlayer(id:  8, username: 'DragonFist',   rating: 2420, avatar: 'DF'),
    _RankPlayer(id:  9, username: 'SwiftWing',    rating: 2380, avatar: 'SW'),
    _RankPlayer(id: 10, username: 'IronWall',     rating: 2350, avatar: 'IW'),
    _RankPlayer(id: 11, username: 'BlazeFury',    rating: 2310, avatar: 'BF'),
    _RankPlayer(id: 12, username: 'SilentStorm',  rating: 2280, avatar: 'SS'),
    _RankPlayer(id: 13, username: 'PhoenixRise',  rating: 2250, avatar: 'PR'),
    _RankPlayer(id: 14, username: 'TigerClaw',    rating: 2220, avatar: 'TC'),
    _RankPlayer(id: 15, username: 'ShadowDash',   rating: 2190, avatar: 'SD'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkFloating);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFloating());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkFloating);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkFloating() {
    final ctx = _userRankKey.currentContext;
    if (ctx == null) return;
    final rb = ctx.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final pos = rb.localToGlobal(Offset.zero);
    final screenH = MediaQuery.of(context).size.height;

    String next;
    if (pos.dy >= 80 && pos.dy + rb.size.height <= screenH - 100) {
      next = 'none';
    } else if (pos.dy > screenH - 100) {
      next = 'bottom';
    } else {
      next = 'top';
    }
    if (next != _floatPos) setState(() => _floatPos = next);
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDarkMode;
    final currentUser = _players[_currentUserRank - 1];

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              toolbarHeight: 72,
              backgroundColor: dark ? const Color(0xFF1F2937) : Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF1F2937) : Colors.white,
                    border: Border(bottom: BorderSide(color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB))),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Player Rankings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: dark ? Colors.white : const Color(0xFF111827))),
                      const SizedBox(height: 2),
                      Text('Top players by ELO rating', style: TextStyle(fontSize: 12, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563))),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final rank = i + 1;
                    final isCurrentUser = rank == _currentUserRank;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: isCurrentUser
                          ? _RankTile(key: _userRankKey, player: _players[i], rank: rank, isCurrentUser: true, dark: dark)
                          : _RankTile(player: _players[i], rank: rank, isCurrentUser: false, dark: dark),
                    );
                  },
                  childCount: _players.length,
                ),
              ),
            ),
          ],
        ),
        if (_floatPos != 'none')
          Positioned(
            top: _floatPos == 'top' ? 80 : null,
            bottom: _floatPos == 'bottom' ? 100 : null,
            left: 16, right: 16,
            child: _FloatingRank(player: currentUser, rank: _currentUserRank, dark: dark),
          ),
      ],
    );
  }
}

class _RankTile extends StatelessWidget {
  final _RankPlayer player;
  final int rank;
  final bool isCurrentUser;
  final bool dark;

  const _RankTile({super.key, required this.player, required this.rank, required this.isCurrentUser, required this.dark});

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;

    final List<Color> gradColors;
    final Color borderColor;

    if (isCurrentUser) {
      borderColor = const Color(0xFF22C55E);
      gradColors = dark ? [const Color(0xFF374151), const Color(0xFF374151)] : [Colors.white, Colors.white];
    } else if (rank == 1) {
      borderColor = const Color(0xFFFACC15);
      gradColors = dark ? [const Color(0xFF78350F).withValues(alpha: 0.3), const Color(0xFF92400E).withValues(alpha: 0.3)] : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)];
    } else if (rank == 2) {
      borderColor = const Color(0xFFD1D5DB);
      gradColors = dark ? [const Color(0xFF374151), const Color(0xFF374151)] : [const Color(0xFFF9FAFB), const Color(0xFFF1F5F9)];
    } else if (rank == 3) {
      borderColor = const Color(0xFF4ADE80);
      gradColors = dark ? [const Color(0xFF14532D).withValues(alpha: 0.3), const Color(0xFF14532D).withValues(alpha: 0.3)] : [const Color(0xFFF0FDF4), const Color(0xFFF0FDF4)];
    } else {
      borderColor = dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB);
      gradColors = dark ? [const Color(0xFF374151), const Color(0xFF374151)] : [Colors.white, Colors.white];
    }

    final List<Color> avatarGrad = isCurrentUser
        ? [const Color(0xFF4ADE80), const Color(0xFF22C55E)]
        : rank == 1 ? [const Color(0xFFFBBF24), const Color(0xFFD97706)]
        : rank == 2 ? [const Color(0xFFD1D5DB), const Color(0xFF9CA3AF)]
        : rank == 3 ? [const Color(0xFF4ADE80), const Color(0xFF16A34A)]
        : [const Color(0xFF4ADE80), const Color(0xFF22C55E)];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradColors),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: (isTop3 || isCurrentUser) ? 2 : 1),
        boxShadow: isTop3 ? [BoxShadow(color: borderColor.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))] : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Center(
              child: isTop3
                  ? Icon(
                      rank == 1 ? Icons.emoji_events : rank == 2 ? Icons.military_tech : Icons.workspace_premium,
                      size: 26,
                      color: rank == 1 ? const Color(0xFFEAB308) : rank == 2 ? const Color(0xFF9CA3AF) : const Color(0xFF22C55E),
                    )
                  : Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold,
                        color: isCurrentUser ? const Color(0xFF22C55E) : dark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                      ),
                    ),
            ),
          ),
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: avatarGrad),
              shape: BoxShape.circle,
              boxShadow: isCurrentUser ? [const BoxShadow(color: Color(0x4022C55E), blurRadius: 8)] : null,
            ),
            child: Center(child: Text(player.avatar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.username, style: TextStyle(fontWeight: FontWeight.w600, color: dark ? Colors.white : const Color(0xFF111827)), overflow: TextOverflow.ellipsis),
                if (isTop3) Text(
                  rank == 1 ? 'Champion' : rank == 2 ? 'Runner-up' : '3rd Place',
                  style: TextStyle(fontSize: 11, color: rank == 1 ? const Color(0xFFD97706) : rank == 2 ? const Color(0xFF9CA3AF) : const Color(0xFF22C55E)),
                ),
                if (isCurrentUser) const Text('You', style: TextStyle(fontSize: 11, color: Color(0xFF22C55E), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${player.rating}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: dark ? Colors.white : const Color(0xFF111827))),
              Text('ELO', style: TextStyle(fontSize: 11, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }
}

class _FloatingRank extends StatelessWidget {
  final _RankPlayer player;
  final int rank;
  final bool dark;
  const _FloatingRank({required this.player, required this.rank, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF374151) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF22C55E), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          SizedBox(width: 44, child: Center(child: Text('#$rank', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF22C55E))))),
          Container(
            width: 46, height: 46,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4ADE80), Color(0xFF22C55E)]), shape: BoxShape.circle),
            child: Center(child: Text(player.avatar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(player.username, style: TextStyle(fontWeight: FontWeight.w600, color: dark ? Colors.white : const Color(0xFF111827))),
              const Text('You', style: TextStyle(fontSize: 11, color: Color(0xFF22C55E), fontWeight: FontWeight.w600)),
            ],
          )),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${player.rating}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: dark ? Colors.white : const Color(0xFF111827))),
              Text('ELO', style: TextStyle(fontSize: 11, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }
}
