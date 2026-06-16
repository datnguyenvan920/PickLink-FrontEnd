import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/rank_screen.dart';
import 'screens/social_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'services/auth_api.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const PickleMatchApp());
}

class PickleMatchApp extends StatefulWidget {
  const PickleMatchApp({super.key});

  @override
  State<PickleMatchApp> createState() => _PickleMatchAppState();
}

class _PickleMatchAppState extends State<PickleMatchApp> {
  bool _isDarkMode = false;
  int _activeTab = 2; // Start on Play (centre)

  // null  = show auth screen
  // false = show profile setup
  // true  = show main app
  bool? _authed;
  bool _needsSetup = false;
  AuthSession? _authSession;

  void _onAuthSuccess(AuthSession? session) async {
    if (session == null) {
      // Skipped auth → go straight to main app
      setState(() {
        _authSession = null;
        _authed = true;
        _needsSetup = false;
      });
      return;
    }

    // Real login / register → check role assignment
    bool needsSetup = true; // default: show setup
    try {
      final api = AuthApi();
      final status = await api.roleStatus(session.token);
      needsSetup = !status.hasRole; // skip setup if role already exists
    } catch (_) {
      // If the check fails, be safe and show setup
    }

    setState(() {
      _authSession = session;
      _authed = needsSetup ? false : true;
      _needsSetup = needsSetup;
    });
  }

  void _onSetupComplete(ProfileSetupResult result) {
    // TODO: send result (role, skillLevel, affiliationCode) to backend
    setState(() {
      _authed = true;
      _needsSetup = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PickleMatch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: _authed == null
          ? AuthScreen(onAuthSuccess: _onAuthSuccess)
          : (_needsSetup
              ? ProfileSetupScreen(
                  authSession: _authSession,
                  onComplete: _onSetupComplete,
                )
              : _RootScaffold(
                  isDarkMode: _isDarkMode,
                  activeTab: _activeTab,
                  authSession: _authSession,
                  onTabChanged: (i) => setState(() => _activeTab = i),
                  onDarkModeChanged: (v) => setState(() => _isDarkMode = v),
                )),
    );
  }
}

// ─── Root Scaffold ────────────────────────────────────────────────────────────

class _RootScaffold extends StatelessWidget {
  final bool isDarkMode;
  final int activeTab;
  final AuthSession? authSession;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<bool> onDarkModeChanged;

  const _RootScaffold({
    required this.isDarkMode,
    required this.activeTab,
    required this.authSession,
    required this.onTabChanged,
    required this.onDarkModeChanged,
  });

  Widget _buildScreen() {
    switch (activeTab) {
      case 0:
        return RankScreen(isDarkMode: isDarkMode);
      case 1:
        return SocialScreen(
          isDarkMode: isDarkMode,
          authSession: authSession,
        );
      case 2:
        return HomeScreen(isDarkMode: isDarkMode, authSession: authSession);
      case 3:
        return MapScreen(isDarkMode: isDarkMode);
      case 4:
        return ProfileScreen(
            isDarkMode: isDarkMode,
            user: authSession?.user,
            token: authSession?.token,
            onDarkModeChanged: onDarkModeChanged);
      default:
        return HomeScreen(isDarkMode: isDarkMode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDarkMode ? AppColors.gray800 : Colors.white;
    final outerBg = isDarkMode ? AppColors.gray900 : const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: outerBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;

          if (isDesktop) {
            // ── Desktop layout ──────────────────────────────────────────
            return Row(
              children: [
                _DesktopSideNav(
                  activeTab: activeTab,
                  isDarkMode: isDarkMode,
                  onTabChanged: onTabChanged,
                  onDarkModeChanged: onDarkModeChanged,
                ),
                // Thin divider line
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: isDarkMode
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB),
                ),
                // Main content — expands to fill remaining space
                Expanded(
                  child: ColoredBox(
                    color: bg,
                    child: _buildScreen(),
                  ),
                ),
              ],
            );
          }

          // ── Mobile layout (unchanged) ────────────────────────────────
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: ColoredBox(
                color: bg,
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildScreen()),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _ParabolicNavBar(
                        activeTab: activeTab,
                        isDarkMode: isDarkMode,
                        onTabChanged: onTabChanged,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Nav Item model ───────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  final int index;
  const _NavItem(this.icon, this.label, this.index);
}

// ─── Desktop Side Nav ─────────────────────────────────────────────────────────

class _DesktopSideNav extends StatelessWidget {
  final int activeTab;
  final bool isDarkMode;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<bool> onDarkModeChanged;

  static const _items = [
    _NavItem(Icons.emoji_events_outlined, 'Rank', 0),
    _NavItem(Icons.people_outline, 'Social', 1),
    _NavItem(Icons.sports_tennis, 'Play', 2),
    _NavItem(Icons.map_outlined, 'Map', 3),
    _NavItem(Icons.person_outline, 'Profile', 4),
  ];

  const _DesktopSideNav({
    required this.activeTab,
    required this.isDarkMode,
    required this.onTabChanged,
    required this.onDarkModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDarkMode ? const Color(0xFF111827) : Colors.white;
    const active = Color(0xFF22C55E);

    return SizedBox(
      width: 220,
      child: ColoredBox(
        color: bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Logo / brand ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF4ADE80), Color(0xFF059669)]),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('PB',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'PickleMatch',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFF16A34A),
                  ),
                ),
              ]),
            ),

            // ── Section label ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'NAVIGATION',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: isDarkMode
                      ? const Color(0xFF6B7280)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ),

            // ── Nav items ──────────────────────────────────────────────
            ...List.generate(_items.length, (i) {
              final item = _items[i];
              final isActive = activeTab == item.index;
              final isCentre = item.index == 2;

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onTabChanged(item.index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: isActive
                            ? const LinearGradient(
                                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            : null,
                        color: isActive ? null : Colors.transparent,
                        boxShadow: isActive
                            ? [
                                const BoxShadow(
                                    color: Color(0x5022C55E),
                                    blurRadius: 12,
                                    offset: Offset(0, 4))
                              ]
                            : null,
                      ),
                      child: Row(children: [
                        Icon(
                          item.icon,
                          size: isCentre ? 22 : 20,
                          color: isActive
                              ? Colors.white
                              : isDarkMode
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive
                                ? Colors.white
                                : isDarkMode
                                    ? const Color(0xFFD1D5DB)
                                    : const Color(0xFF374151),
                          ),
                        ),
                        if (isCentre) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : active.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'PLAY',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: isActive ? Colors.white : active,
                              ),
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),
              );
            }),

            const Spacer(),

            // ── Dark mode toggle ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onDarkModeChanged(!isDarkMode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isDarkMode
                          ? const Color(0xFF1F2937)
                          : const Color(0xFFF3F4F6),
                      border: Border.all(
                        color: isDarkMode
                            ? const Color(0xFF374151)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        isDarkMode
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        size: 18,
                        color: isDarkMode
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isDarkMode ? 'Light Mode' : 'Dark Mode',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFF374151),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Parabolic Nav Bar ────────────────────────────────────────────────────────

class _ParabolicNavBar extends StatelessWidget {
  final int activeTab;
  final bool isDarkMode;
  final ValueChanged<int> onTabChanged;

  static const _items = [
    _NavItem(Icons.emoji_events_outlined, 'Rank', 0),
    _NavItem(Icons.people_outline, 'Social', 1),
    _NavItem(Icons.sports_tennis, 'Play', 2), // centre
    _NavItem(Icons.map_outlined, 'Map', 3),
    _NavItem(Icons.person_outline, 'Profile', 4),
  ];

  const _ParabolicNavBar({
    required this.activeTab,
    required this.isDarkMode,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final navBg = isDarkMode ? AppColors.gray800 : Colors.white;
    final borderColor =
        isDarkMode ? AppColors.borderDark : AppColors.borderLight;

    return SizedBox(
      height: 90,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Curved background
          CustomPaint(
            size: const Size(double.infinity, 90),
            painter: _ParabolaPainter(color: navBg, borderColor: borderColor),
          ),
          // Nav items row
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _items.map((item) {
                  final isActive = activeTab == item.index;
                  final isCentre = item.index == 2;

                  if (isCentre) {
                    return Transform.translate(
                      offset: const Offset(0, -18),
                      child: GestureDetector(
                        onTap: () => onTabChanged(item.index),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isActive
                                      ? [
                                          const Color(0xFF22C55E),
                                          const Color(0xFF16A34A)
                                        ]
                                      : [
                                          const Color(0xFF4ADE80),
                                          const Color(0xFF22C55E)
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x8022C55E),
                                      blurRadius: 16,
                                      offset: Offset(0, 4)),
                                ],
                              ),
                              child: Icon(item.icon,
                                  color: Colors.white, size: 28),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? AppColors.green500
                                    : isDarkMode
                                        ? AppColors.textDarkSecondary
                                        : AppColors.textLightSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: (item.index == 0 || item.index == 4) ? 10 : 4),
                    child: GestureDetector(
                      onTap: () => onTabChanged(item.index),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.green500
                                  : isDarkMode
                                      ? const Color(0xFF374151)
                                      : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                          color: AppColors.green500
                                              .withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2))
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              item.icon,
                              size: 21,
                              color: isActive
                                  ? Colors.white
                                  : isDarkMode
                                      ? AppColors.textDarkSecondary
                                      : AppColors.textLightSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? AppColors.green500
                                  : isDarkMode
                                      ? AppColors.textDarkSecondary
                                      : AppColors.textLightSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Parabola Painter ──────────────────────────────────────────────────

class _ParabolaPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  const _ParabolaPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.42)
      ..quadraticBezierTo(size.width * 0.12, size.height * 0.10,
          size.width * 0.25, size.height * 0.26)
      ..quadraticBezierTo(
          size.width * 0.38, size.height * 0.36, size.width * 0.5, 0)
      ..quadraticBezierTo(size.width * 0.62, size.height * 0.36,
          size.width * 0.75, size.height * 0.26)
      ..quadraticBezierTo(
          size.width * 0.88, size.height * 0.10, size.width, size.height * 0.42)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(_ParabolaPainter old) =>
      old.color != color || old.borderColor != borderColor;
}
