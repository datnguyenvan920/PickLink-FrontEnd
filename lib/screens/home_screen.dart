import 'dart:async';
import 'package:flutter/material.dart';
import 'map_screen.dart';
import '../services/auth_api.dart';
import '../services/match_api.dart';
import 'match_voting_screen.dart';

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

/// Converts a backend tier string to a [PlayerTier] enum value.
PlayerTier _tierFromString(String tier) {
  switch (tier.toLowerCase()) {
    case 'silver':   return PlayerTier.silver;
    case 'gold':     return PlayerTier.gold;
    case 'platinum': return PlayerTier.platinum;
    case 'diamond':  return PlayerTier.diamond;
    default:         return PlayerTier.bronze;
  }
}

/// Builds the initial players list.
/// Slot 0 is always null initially; it will be filled with real data once
/// the backend call completes (or left null for guests).
List<_Player?> _makeInitialPlayers(int size) {
  if (size == 2) {
    return [null, null];
  }
  return [null, null, null, null];
}

const _adPosts = [
  _AdPost(id: 1, isAd: true,  brand: 'PicklePro Gear',         brandIcon: '🏓', title: 'Mùa hè này – Nâng cấp cú đánh của bạn!',    body: 'Bộ vợt PicklePro Carbon Series giảm 30% – chỉ trong tuần này. Nhẹ hơn, kiểm soát tốt hơn.', cta: 'Mua ngay',     likes: 142, comments: 18),
  _AdPost(id: 2, isAd: false, brand: 'Hà Nội Pickleball Club', brandIcon: '🏅', title: 'Giải đấu cuối tuần – Đăng ký còn 3 suất', body: 'Sân Cầu Giấy Arena • Chủ Nhật 08/06 • Giải thưởng lên tới 5 triệu đồng.',                 cta: 'Đăng ký',      likes: 87,  comments: 34),
  _AdPost(id: 3, isAd: true,  brand: 'SportDrink VN',           brandIcon: '⚡', title: 'Giữ phong độ suốt trận đấu',              body: 'SportDrink Electrolyte – bù nước nhanh, cung cấp năng lượng tức thì. Thử ngay miễn phí!',  cta: 'Nhận mẫu thử', likes: 203, comments: 9),
];

// ─── Home Screen ──────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final AuthSession? authSession;
  const HomeScreen({super.key, required this.isDarkMode, this.authSession});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _locationLabel = 'Hà Nội';
  String _locationDistance = '3km';
  bool _searching = false;
  int _lobbySize = 4;
  double _availableHours = 3.0;
  double _startHour = 8.0;
  late List<_Player?> _players;
  Timer? _searchTimer;
  bool _loadingMe = false; // true while fetching lobby-me
  String? _activeQueueId;  // set once createLobby succeeds

  /// Venue IDs returned by MapScreen — sent to matchmaking as PrefferedVenue.
  List<int> _selectedVenueIds = [];


  @override
  void initState() {
    super.initState();
    _players = _makeInitialPlayers(_lobbySize);
    _fetchMe();
  }

  /// Fetches the real user's lobby card and populates slot 0.
  Future<void> _fetchMe() async {
    final token = widget.authSession?.token;
    if (token == null) return;

    setState(() => _loadingMe = true);
    try {
      final data = await AuthApi().lobbyMe(token);
      if (!mounted) return;
      final player = _Player(
        id: data.userId,
        name: data.username,
        avatar: data.avatarInitials,
        rating: data.skillLevel,
        tier: _tierFromString(data.tier),
        isCurrentUser: true,
      );
      setState(() {
        _players = List.from(_players)..[0] = player;
      });
    } catch (_) {
      // Silently ignore — slot 0 stays empty if the call fails
    } finally {
      if (mounted) setState(() => _loadingMe = false);
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _changeLobbySize(int size) {
    _searchTimer?.cancel();
    setState(() {
      _lobbySize = size;
      _searching = false;
      _players = _makeInitialPlayers(size);
    });
    _fetchMe(); // re-populate slot 0 with the real user
  }

  /// Formats a start‐hour double (e.g. 8.5) as an HH:mm:ss string.
  String _hourToTimeString(double h) {
    final hh = h.toInt().toString().padLeft(2, '0');
    final mm = ((h % 1) * 60).toInt().toString().padLeft(2, '0');
    return '$hh:$mm:00';
  }

  /// Guards matchmaking: blocks and notifies user if no venues are selected,
  /// then runs the real matchmaking flow.
  Future<void> _findMatch() async {
    // ── Guard: require at least one venue ────────────────────────────────
    if (_selectedVenueIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 4),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66EF4444),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              children: [
                const Text('🏕️', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Chưa chọn sân!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hãy chọn sân trước khi tìm trận. Nhấn nút vị trí ở góc trên bên trái.',
                        style: TextStyle(
                          color: Color(0xFFFECACA),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      );
      return;
    }

    final token = widget.authSession?.token;
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn cần đăng nhập để tìm trận.')),
        );
      }
      return;
    }

    setState(() {
      _searching = true;
      _activeQueueId = null;
    });

    try {
      // ── Step 1: fetch current user's player data ─────────────────────────
      final me = await AuthApi().lobbyMe(token);
      if (!mounted) return;

      final endHour = (_startHour + _availableHours).clamp(0.0, 24.0);

      // Build the players array — one entry for the current user
      final myPlayer = LobbyPlayerDto(
        playerId:   me.userId,
        playerName: me.username,
        playerSkill: me.skillLevel,
        playerProfilePictureUrl: me.profileImageUrl,
        preferredTimeStart: _hourToTimeString(_startHour),
        preferredTimeEnd:   _hourToTimeString(endHour),
        prefferedVenue:     _selectedVenueIds,
      );

      final req = CreateLobbyRequest(
        players:   [myPlayer],
        lobbyType: 'normal',
        lobbySize: _lobbySize,
      );

      // ── Step 2: enqueue on FindMatchModule (port 5063) ───────────────────
      final enqueued = await MatchApi().enqueue(req);
      if (!mounted) return;

      setState(() => _activeQueueId = enqueued.queueId);

      // ── Step 3: poll every 10 s ──────────────────────────────────────────
      _searchTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        if (!mounted) return;
        final queueId = _activeQueueId;
        if (queueId == null) return;

        try {
          final status = await MatchApi().getMatch(queueId);
          if (!mounted) return;

          if (status.isMatched) {
            _searchTimer?.cancel();
            setState(() {
              _searching = false;
              _activeQueueId = null;
            });
            _showMatchFoundPopup(status);
          }
        } catch (_) {
          // Silently retry on next tick
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.message}'), backgroundColor: const Color(0xFFEF4444)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi kết nối: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  /// Shows the premium match-detail bottom sheet when a match is found.
  void _showMatchFoundPopup(LobbyStatusResponse match) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MatchFoundPopup(
        dark: widget.isDarkMode,
        match: match,
        onAccept: () {
          Navigator.of(context).pop();
          if (match.matchId != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MatchVotingScreen(
                  matchId: match.matchId!,
                  authSession: widget.authSession!,
                  isDarkMode: widget.isDarkMode,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không tìm thấy thông tin trận đấu để bầu chọn.')),
            );
          }
        },
        onDecline: () {
          Navigator.of(context).pop();
          _leaveSearch();
        },
      ),
    );
  }

  void _leaveSearch() {
    _searchTimer?.cancel();
    setState(() {
      _searching = false;
      _activeQueueId = null;
      _players = _makeInitialPlayers(_lobbySize);
    });
    _fetchMe(); // restore slot 0
  }

  int get _filled => _players.where((p) => p != null).length;

  void _openMapScreen() async {
    final result = await Navigator.of(context).push<MapResult>(
      MaterialPageRoute(
        builder: (_) => MapScreen(isDarkMode: widget.isDarkMode),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedVenueIds = result.venueIds;
        // Update the location badge with the real city name and radius
        _locationLabel = result.locationLabel;
        _locationDistance = '${result.radiusKm.toStringAsFixed(1)}km';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDarkMode;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeTopBar(
            dark: dark,
            label: _locationLabel,
            distance: _locationDistance,
            venueCount: _selectedVenueIds.length,
            onLocationTap: _openMapScreen,
          ),
          _LobbySection(
            dark: dark,
            players: _players,
            filled: _filled,
            searching: _searching,
            loadingMe: _loadingMe,
            lobbySize: _lobbySize,
            availableHours: _availableHours,
            startHour: _startHour,
            onFindMatch: _findMatch,
            onLeave: _leaveSearch,
            onLobbySizeChanged: _changeLobbySize,
            onAvailableHoursChanged: (h) => setState(() => _availableHours = h),
            onStartHourChanged: (h) => setState(() => _startHour = h),
          ),
          _Divider(dark: dark),
          _AdsFeed(dark: dark),
        ],
      ),
    );
  }
}

// ─── Top Bar ─────────────────────────────────────────────────────────────────

class _HomeTopBar extends StatefulWidget {
  final bool dark;
  final String label;
  final String distance;
  final int venueCount;
  final VoidCallback onLocationTap;
  const _HomeTopBar({
    required this.dark,
    required this.label,
    required this.distance,
    required this.venueCount,
    required this.onLocationTap,
  });

  @override
  State<_HomeTopBar> createState() => _HomeTopBarState();
}

class _HomeTopBarState extends State<_HomeTopBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final noVenues = widget.venueCount == 0;
    final bg = dark ? const Color(0xFF1F2937) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: border))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Location pill — glows amber when no venues selected
          GestureDetector(
            onTap: widget.onLocationTap,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: noVenues
                        ? Color.lerp(
                            const Color(0xFFF59E0B),
                            const Color(0xFFFCD34D),
                            _pulseAnim.value,
                          )!
                        : dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
                    width: noVenues ? 1.5 : 1.0,
                  ),
                  boxShadow: noVenues
                      ? [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(
                              alpha: _pulseAnim.value * 0.4,
                            ),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: child,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                // Dot indicator: amber when no venues, green otherwise
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: noVenues ? const Color(0xFFF59E0B) : const Color(0xFF22C55E),
                  ),
                ),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: noVenues ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    noVenues ? 'Chọn sân' : widget.distance,
                    style: TextStyle(
                      fontSize: 9,
                      color: noVenues ? const Color(0xFFB45309) : const Color(0xFF15803D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_outlined,
                  size: 13,
                  color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
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
            Text('Picklink', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))),
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
  final bool loadingMe;
  final int lobbySize;
  final double availableHours;
  final double startHour;
  final VoidCallback onFindMatch;
  final VoidCallback onLeave;
  final ValueChanged<int> onLobbySizeChanged;
  final ValueChanged<double> onAvailableHoursChanged;
  final ValueChanged<double> onStartHourChanged;

  const _LobbySection({
    required this.dark,
    required this.players,
    required this.filled,
    required this.searching,
    required this.loadingMe,
    required this.lobbySize,
    required this.availableHours,
    required this.startHour,
    required this.onFindMatch,
    required this.onLeave,
    required this.onLobbySizeChanged,
    required this.onAvailableHoursChanged,
    required this.onStartHourChanged,
  });

  Widget _vsDivider(bool dark) {
    return Row(children: [
      Expanded(child: Divider(color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB))),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF16A34A)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x3322C55E), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: const Text('── VS ──', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
      ),
      Expanded(child: Divider(color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // Detect web/wide screen to use smaller slots
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;

    // Slot aspect ratios: wider screen → taller ratio (shorter card)
    final slotAspect = isWide
        ? (lobbySize == 2 ? 2.2 : 1.8)
        : (lobbySize == 2 ? 1.05 : 0.88);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        children: [
          // ── Header row ────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('🏓 Phòng chờ trận', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dark ? Colors.white : const Color(0xFF111827))),
                const SizedBox(height: 2),
                Text('$filled/$lobbySize người chơi đã sẵn sàng', style: TextStyle(fontSize: 11, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
              ]),
              _SearchingBadge(dark: dark, searching: searching),
            ],
          ),
          const SizedBox(height: 12),

          // ── Lobby size selector ───────────────────────────────────────
          Row(
            children: [
              Icon(Icons.groups_outlined, size: 14, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text('Cỡ lobby:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
              const SizedBox(width: 10),
              _LobbySizeToggle(lobbySize: lobbySize, dark: dark, onChanged: onLobbySizeChanged),
            ],
          ),
          const SizedBox(height: 12),

          // ── Progress bar ──────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: filled / lobbySize,
              minHeight: 6,
              backgroundColor: dark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
            ),
          ),
          const SizedBox(height: 16),

          // ── Team A slots ──────────────────────────────────────────────
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: slotAspect,
            children: List.generate(
              lobbySize == 2 ? 1 : 2,
              (i) => _PlayerSlot(
                player: players[i],
                index: i,
                dark: dark,
                isWeb: isWide,
                shimmer: i == 0 && loadingMe,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── VS divider (between teams) ────────────────────────────────
          _vsDivider(dark),
          const SizedBox(height: 14),

          // ── Team B slots ──────────────────────────────────────────────
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: slotAspect,
            children: List.generate(
              lobbySize == 2 ? 1 : 2,
              (i) {
                final idx = lobbySize == 2 ? i + 1 : i + 2;
                return _PlayerSlot(player: players[idx], index: idx, dark: dark, isWeb: isWide);
              },
            ),
          ),
          const SizedBox(height: 20),

          // ── Court info ────────────────────────────────────────────────
          _CourtCard(dark: dark),
          const SizedBox(height: 14),

          // ── Time availability sliders ──────────────────────────────────
          _TimeAvailabilitySlider(
            hours: availableHours,
            startHour: startHour,
            dark: dark,
            onHoursChanged: onAvailableHoursChanged,
            onStartHourChanged: onStartHourChanged,
          ),
          const SizedBox(height: 14),

          // ── Action buttons ────────────────────────────────────────────
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
                      onPressed: filled == lobbySize ? null : onFindMatch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: filled == lobbySize ? const Color(0xFFD1D5DB) : const Color(0xFF22C55E),
                        disabledBackgroundColor: const Color(0xFFD1D5DB),
                        foregroundColor: filled == lobbySize ? const Color(0xFF9CA3AF) : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: filled == lobbySize ? 0 : 4,
                        shadowColor: const Color(0x6622C55E),
                      ),
                      child: Text(filled == lobbySize ? '🎉 Đủ người!' : '🔍 Tìm người chơi', style: const TextStyle(fontWeight: FontWeight.bold)),
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

class _PlayerSlot extends StatefulWidget {
  final _Player? player;
  final int index;
  final bool dark;
  final bool isWeb;
  final bool shimmer;
  const _PlayerSlot({
    required this.player,
    required this.index,
    required this.dark,
    this.isWeb = false,
    this.shimmer = false,
  });

  @override
  State<_PlayerSlot> createState() => _PlayerSlotState();
}

class _PlayerSlotState extends State<_PlayerSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimCtrl;
  late final Animation<double> _shimAnim;

  @override
  void initState() {
    super.initState();
    _shimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _shimAnim = CurvedAnimation(parent: _shimCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _shimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.shimmer) {
      return AnimatedBuilder(
        animation: _shimAnim,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Color.lerp(
              widget.dark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
              widget.dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
              _shimAnim.value,
            ),
            border: Border.all(
              color: widget.dark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
              width: 2,
            ),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: widget.isWeb ? 34 : 52,
              height: widget.isWeb ? 34 : 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.dark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
              ),
            ),
            SizedBox(height: widget.isWeb ? 3 : 6),
            Container(
              width: 60, height: 8,
              decoration: BoxDecoration(
                color: widget.dark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ]),
        ),
      );
    }
    // Use smaller avatar/font sizes on wide (web) screens
    final bool dark   = widget.dark;
    final bool isWeb  = widget.isWeb;
    final double avatarSize     = isWeb ? 34 : 52;
    final double plusSize       = isWeb ? 14 : 22;
    final double nameFontSize   = isWeb ? 9  : 10;
    final double tierFontSize   = isWeb ? 7  : 8;
    final double ratingFontSize = isWeb ? 8  : 9;
    final double tierIconSize   = isWeb ? 7  : 9;
    final double starSize       = isWeb ? 7  : 9;

    // ─── Empty slot ────────────────────────────────────────────────
    if (widget.player == null) {
      return Container(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF374151).withValues(alpha: 0.5) : const Color(0xFFF3F4F6).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB), width: 2),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: avatarSize, height: avatarSize,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: dark ? const Color(0xFF6B7280) : const Color(0xFFD1D5DB), width: 2)),
            child: Center(child: Text('+', style: TextStyle(fontSize: plusSize, color: dark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)))),
          ),
          SizedBox(height: isWeb ? 3 : 6),
          Text('Chờ người chơi', style: TextStyle(fontSize: nameFontSize, color: dark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF))),
          SizedBox(height: isWeb ? 2 : 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(10)),
            child: Text('Slot ${widget.index + 1}', style: TextStyle(fontSize: 9, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
          ),
        ]),
      );
    }

    // ─── Filled slot ───────────────────────────────────────────────
    final p    = widget.player!;
    final grad = _tierGradient(p.tier);
    final tc   = _tierTextColor(p.tier);

    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF374151) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: p.isCurrentUser ? const Color(0xFF4ADE80) : dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
          width: p.isCurrentUser ? 2 : 1,
        ),
        boxShadow: p.isCurrentUser ? [const BoxShadow(color: Color(0x4D4ADE80), blurRadius: 12)] : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: avatarSize, height: avatarSize,
            decoration: BoxDecoration(gradient: grad, shape: BoxShape.circle),
            child: Center(child: Text(p.avatar, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isWeb ? 10 : 15))),
          ),
          if (p.isCurrentUser)
            Positioned(
              top: -4, right: -4,
              child: Container(
                width: isWeb ? 13 : 18, height: isWeb ? 13 : 18,
                decoration: BoxDecoration(color: const Color(0xFF22C55E), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: Center(child: Text('Y', style: TextStyle(color: Colors.white, fontSize: isWeb ? 5 : 7, fontWeight: FontWeight.bold))),
              ),
            ),
        ]),
        SizedBox(height: isWeb ? 3 : 5),
        Text(p.name, style: TextStyle(fontSize: nameFontSize, fontWeight: FontWeight.w600, color: dark ? Colors.white : const Color(0xFF111827))),
        SizedBox(height: isWeb ? 2 : 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(gradient: grad, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_tierIcon(p.tier), size: tierIconSize, color: tc),
            const SizedBox(width: 2),
            Text(_tierName(p.tier), style: TextStyle(fontSize: tierFontSize, color: tc, fontWeight: FontWeight.w600)),
          ]),
        ),
        SizedBox(height: isWeb ? 1 : 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.star, size: starSize, color: const Color(0xFFFACC15)),
          const SizedBox(width: 2),
          Text(p.rating.toStringAsFixed(1), style: TextStyle(fontSize: ratingFontSize, color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563))),
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



// ─── Lobby Size Toggle ────────────────────────────────────────────────────────

class _LobbySizeToggle extends StatelessWidget {
  final int lobbySize;
  final bool dark;
  final ValueChanged<int> onChanged;
  const _LobbySizeToggle({required this.lobbySize, required this.dark, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [2, 4].map((size) {
          final isSelected = lobbySize == size;
          final label = size == 2 ? '1v1' : '2v2';
          return GestureDetector(
            onTap: () => onChanged(size),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF16A34A)])
                    : null,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected
                    ? [const BoxShadow(color: Color(0x4022C55E), blurRadius: 8, offset: Offset(0, 2))]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    size == 2 ? Icons.person : Icons.group,
                    size: 12,
                    color: isSelected ? Colors.white : dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Time Availability Slider ─────────────────────────────────────────────────

class _TimeAvailabilitySlider extends StatelessWidget {
  final double hours;      // duration willing to spend (2‒8 h)
  final double startHour;  // start of preferred window (0‒22)
  final bool dark;
  final ValueChanged<double> onHoursChanged;
  final ValueChanged<double> onStartHourChanged;

  const _TimeAvailabilitySlider({
    required this.hours,
    required this.startHour,
    required this.dark,
    required this.onHoursChanged,
    required this.onStartHourChanged,
  });

  String _qualityLabel(double h) {
    if (h < 4.5) return 'Tối thiểu';
    if (h < 6) return 'Tốt';
    if (h < 7.5) return 'Rất tốt';
    return 'Xuất sắc ✨';
  }

  Color _qualityColor(double h) {
    if (h < 4.5) return const Color(0xFFEF4444);
    if (h < 6) return const Color(0xFFF59E0B);
    if (h < 7.5) return const Color(0xFF84CC16);
    return const Color(0xFF22C55E);
  }

  String _formatHour(double h) {
    final hh = h.toInt().toString().padLeft(2, '0');
    final mm = ((h % 1) * 60).round() == 30 ? '30' : '00';
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final qual = _qualityColor(hours);
    final hoursLabel = hours % 1 == 0 ? '${hours.toInt()}' : hours.toStringAsFixed(1);
    final cardBg = dark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    // Window position as fraction of 24h bar
    final winStart = startHour / 24.0;
    final winEnd   = ((startHour + hours) / 24.0).clamp(0.0, 1.0);
    final endHour  = (startHour + hours).clamp(0.0, 24.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title + quality badge ────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Text('⏰', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text('Thời gian rảnh', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: dark ? Colors.white : const Color(0xFF111827))),
              ]),
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: qual.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: qual.withValues(alpha: 0.45)),
                ),
                child: Text(
                  _qualityLabel(hours),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: qual),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Slider 1: Duration ───────────────────────────────────────
          Row(children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(color: qual.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Center(child: Icon(Icons.timelapse_rounded, size: 12, color: qual)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Thời lượng sẵn sàng', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
                      Text(
                        '$hoursLabel tiếng',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: qual),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: qual,
                      inactiveTrackColor: dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
                      thumbColor: qual,
                      overlayColor: qual.withValues(alpha: 0.18),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: hours,
                      min: 3.0,
                      max: 8.0,
                      divisions: 10, // 0.5h steps from 3.0 to 8.0
                      onChanged: onHoursChanged,
                    ),
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 6),

          // ── Slider 2: Start time ─────────────────────────────────────
          Row(children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Center(child: Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF6366F1))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Khung giờ bắt đầu', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
                      Text(
                        '${_formatHour(startHour)} – ${_formatHour(endHour)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF6366F1)),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF6366F1),
                      inactiveTrackColor: dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
                      thumbColor: const Color(0xFF6366F1),
                      overlayColor: const Color(0xFF6366F1).withValues(alpha: 0.18),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: startHour,
                      min: 0.0,
                      max: 22.0,
                      divisions: 44, // 30-min steps
                      onChanged: onStartHourChanged,
                    ),
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 10),

          // ── 24h day bar showing the selected window ──────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vị trí trong ngày', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (context, constraints) {
                  final total = constraints.maxWidth;
                  final leftPx  = total * winStart;
                  final widthPx = (total * (winEnd - winStart)).clamp(4.0, total);
                  return Stack(
                    children: [
                      // Background bar (gradient – full day)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 14,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                dark ? const Color(0xFF1E3A5F) : const Color(0xFFDBEAFE), // night/morning
                                const Color(0xFFFDE68A), // noon
                                const Color(0xFFFB923C), // afternoon
                                dark ? const Color(0xFF1E1B4B) : const Color(0xFFE0E7FF), // evening
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Highlight window
                      Positioned(
                        left: leftPx,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: widthPx,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF6366F1), width: 1),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 3),
              // Hour labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['00:00', '06:00', '12:00', '18:00', '24:00'].map((t) =>
                  Text(t, style: TextStyle(fontSize: 8, color: dark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF))),
                ).toList(),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // ── Footer hint ──────────────────────────────────────────────
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.trending_up_rounded, size: 10, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
            const SizedBox(width: 3),
            Text(
              'Thời gian nhiều hơn → Cặp đấu tốt hơn',
              style: TextStyle(fontSize: 9, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Match Found Popup ───────────────────────────────────────────────────────

class _MatchFoundPopup extends StatefulWidget {
  final bool dark;
  final LobbyStatusResponse match;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _MatchFoundPopup({
    required this.dark,
    required this.match,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_MatchFoundPopup> createState() => _MatchFoundPopupState();
}

class _MatchFoundPopupState extends State<_MatchFoundPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Split players into two teams of lobbySize/2
  List<List<LobbyPlayerDto>> _teams() {
    final players = widget.match.players;
    final half = (widget.match.lobbySize / 2).ceil();
    if (players.isEmpty) return [[], []];
    final a = players.take(half).toList();
    final b = players.skip(half).toList();
    return [a, b];
  }

  @override
  Widget build(BuildContext context) {
    final dark  = widget.dark;
    final teams = _teams();
    final bg    = dark ? const Color(0xFF111827) : Colors.white;
    final border= dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF22C55E).withValues(alpha: 0.18),
              blurRadius: 40,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle
            const SizedBox(height: 10),
            Container(
              width: 38, height: 4,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 18),

            // ── Trophy + headline
            ScaleTransition(
              scale: _scaleAnim,
              child: Column(children: [
                Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x6622C55E), blurRadius: 20, offset: Offset(0, 6)),
                    ],
                  ),
                  child: const Center(child: Text('🏆', style: TextStyle(fontSize: 30))),
                ),
                const SizedBox(height: 10),
                Text(
                  'Trận đấu đã tìm được!',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900,
                    color: dark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.match.lobbyType == 'ranked'
                      ? '🏅 Trận xếp hạng • ${widget.match.lobbySize} người'
                      : '🏓 Trận thường • ${widget.match.lobbySize} người',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ]),
            ),
            const SizedBox(height: 22),

            // ── Teams
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team A
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _teamLabel('Nhóm A', const Color(0xFF22C55E), dark),
                        const SizedBox(height: 8),
                        ...teams[0].map((p) => _MatchPlayerCard(player: p, dark: dark, accentColor: const Color(0xFF22C55E))),
                        if (teams[0].isEmpty)
                          _emptySlot(dark),
                      ],
                    ),
                  ),
                  // VS divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: const Text(
                        'VS',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ),
                  // Team B
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _teamLabel('Nhóm B', const Color(0xFF6366F1), dark),
                        const SizedBox(height: 8),
                        ...teams[1].map((p) => _MatchPlayerCard(player: p, dark: dark, accentColor: const Color(0xFF6366F1))),
                        if (teams[1].isEmpty)
                          _emptySlot(dark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Match time info
            if (widget.match.matchedAt != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF1F2937) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: dark ? const Color(0xFF374151) : const Color(0xFFBBF7D0)),
                  ),
                  child: Row(children: [
                    const Text('⏰', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Thời điểm khớp',
                        style: TextStyle(fontSize: 10, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
                      Text(
                        _formatMatchedAt(widget.match.matchedAt!),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                            color: dark ? Colors.white : const Color(0xFF111827)),
                      ),
                    ]),
                  ]),
                ),
              ),
            const SizedBox(height: 20),

            // ── Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onDecline,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFF87171), width: 2),
                      foregroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('❌ Từ chối', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: widget.onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: const Color(0x6622C55E),
                    ),
                    child: const Text('✅ Chấp nhận', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamLabel(String label, Color color, bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _emptySlot(bool dark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 58,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF374151).withValues(alpha: 0.4) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB)),
      ),
      child: const Center(child: Text('?', style: TextStyle(fontSize: 20, color: Color(0xFF9CA3AF)))),
    );
  }

  String _formatMatchedAt(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final mo= local.month.toString().padLeft(2, '0');
    return '$h:$m, $d/$mo/${local.year}';
  }
}

// ─── Match Player Card ────────────────────────────────────────────────────────

class _MatchPlayerCard extends StatelessWidget {
  final LobbyPlayerDto player;
  final bool dark;
  final Color accentColor;

  const _MatchPlayerCard({
    required this.player,
    required this.dark,
    required this.accentColor,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'[\s_.]'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  /// Maps a raw skill score (0–5+) to a star rating display (1.0–5.0).
  double _skillToStars(double skill) =>
      (skill / 5.0 * 4.0 + 1.0).clamp(1.0, 5.0);

  @override
  Widget build(BuildContext context) {
    final stars = _skillToStars(player.playerSkill);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        // Avatar circle
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentColor, accentColor.withValues(alpha: 0.6)],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _initials(player.playerName),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Name + skill
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              player.playerName,
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: dark ? Colors.white : const Color(0xFF111827),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.star, size: 9, color: Color(0xFFFACC15)),
              const SizedBox(width: 2),
              Text(
                stars.toStringAsFixed(1),
                style: TextStyle(fontSize: 9, color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563)),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
