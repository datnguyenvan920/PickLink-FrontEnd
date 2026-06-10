import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/rank_screen.dart';
import 'screens/social_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
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
  int _activeTab = 2; // Start on Home (centre)

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PickleMatch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: _RootScaffold(
        isDarkMode: _isDarkMode,
        activeTab: _activeTab,
        onTabChanged: (i) => setState(() => _activeTab = i),
        onDarkModeChanged: (v) => setState(() => _isDarkMode = v),
      ),
    );
  }
}

// ─── Root Scaffold ────────────────────────────────────────────────────────────

class _RootScaffold extends StatelessWidget {
  final bool isDarkMode;
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<bool> onDarkModeChanged;

  const _RootScaffold({
    required this.isDarkMode,
    required this.activeTab,
    required this.onTabChanged,
    required this.onDarkModeChanged,
  });

  Widget _buildScreen() {
    switch (activeTab) {
      case 0: return RankScreen(isDarkMode: isDarkMode);
      case 1: return SocialScreen(isDarkMode: isDarkMode);
      case 2: return HomeScreen(isDarkMode: isDarkMode);
      case 3: return MapScreen(isDarkMode: isDarkMode);
      case 4: return ProfileScreen(isDarkMode: isDarkMode, onDarkModeChanged: onDarkModeChanged);
      default: return HomeScreen(isDarkMode: isDarkMode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg      = isDarkMode ? AppColors.gray800 : Colors.white;
    final outerBg = isDarkMode ? AppColors.gray900 : const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: outerBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: ColoredBox(
            color: bg,
            child: Stack(
              children: [
                // Active screen (full height, padded at bottom for nav bar)
                Positioned.fill(child: _buildScreen()),
                // Parabolic bottom nav
                Positioned(
                  bottom: 0, left: 0, right: 0,
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

// ─── Parabolic Nav Bar ────────────────────────────────────────────────────────

class _ParabolicNavBar extends StatelessWidget {
  final int activeTab;
  final bool isDarkMode;
  final ValueChanged<int> onTabChanged;

  static const _items = [
    _NavItem(Icons.emoji_events_outlined, 'Rank',    0),
    _NavItem(Icons.people_outline,        'Social',  1),
    _NavItem(Icons.sports_tennis,         'Play',    2), // centre
    _NavItem(Icons.map_outlined,          'Map',     3),
    _NavItem(Icons.person_outline,        'Profile', 4),
  ];

  const _ParabolicNavBar({
    required this.activeTab,
    required this.isDarkMode,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final navBg      = isDarkMode ? AppColors.gray800 : Colors.white;
    final borderColor = isDarkMode ? AppColors.borderDark : AppColors.borderLight;

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
            bottom: 0, left: 0, right: 0,
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
                              width: 60, height: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isActive
                                      ? [const Color(0xFF22C55E), const Color(0xFF16A34A)]
                                      : [const Color(0xFF4ADE80), const Color(0xFF22C55E)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(color: Color(0x8022C55E), blurRadius: 16, offset: Offset(0, 4)),
                                ],
                              ),
                              child: Icon(item.icon, color: Colors.white, size: 28),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isActive ? AppColors.green500 : isDarkMode ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: EdgeInsets.only(bottom: (item.index == 0 || item.index == 4) ? 10 : 4),
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
                                  : isDarkMode ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: isActive
                                  ? [BoxShadow(color: AppColors.green500.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))]
                                  : null,
                            ),
                            child: Icon(
                              item.icon, size: 21,
                              color: isActive ? Colors.white : isDarkMode ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isActive ? AppColors.green500 : isDarkMode ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
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
    final fill = Paint()..color = color..style = PaintingStyle.fill;
    final border = Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 1;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.42)
      ..quadraticBezierTo(size.width * 0.12, size.height * 0.10, size.width * 0.25, size.height * 0.26)
      ..quadraticBezierTo(size.width * 0.38, size.height * 0.36, size.width * 0.5,  0)
      ..quadraticBezierTo(size.width * 0.62, size.height * 0.36, size.width * 0.75, size.height * 0.26)
      ..quadraticBezierTo(size.width * 0.88, size.height * 0.10, size.width,        size.height * 0.42)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(_ParabolaPainter old) => old.color != color || old.borderColor != borderColor;
}
