import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;

  const ProfileScreen({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode;
    final textPrimary   = dark ? Colors.white : const Color(0xFF111827);
    final textSecondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg        = dark ? const Color(0xFF374151) : const Color(0xFFF9FAFB);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          // ── Avatar ──
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 96, height: 96,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x4022C55E), blurRadius: 16, offset: Offset(0, 4))],
                ),
                child: const Center(
                  child: Text('JD', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                ),
              ),
              Positioned(
                bottom: 2, right: 2,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('John Doe', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 4),
          Text('@johndoe_sports', style: TextStyle(fontSize: 13, color: textSecondary)),
          const SizedBox(height: 20),

          // ── Bio ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
            child: Text(
              'Passionate athlete | Love playing football and badminton | Always up for a match!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151)),
            ),
          ),
          const SizedBox(height: 20),

          // ── Stats ──
          Row(
            children: [
              _StatCard(icon: Icons.emoji_events, iconColor: const Color(0xFF22C55E), value: '47',   label: 'Matches', dark: dark, cardBg: cardBg),
              const SizedBox(width: 10),
              _StatCard(icon: Icons.star,         iconColor: const Color(0xFFFACC15), value: '4.8',  label: 'Rating',  dark: dark, cardBg: cardBg),
              const SizedBox(width: 10),
              _StatCard(icon: Icons.military_tech, iconColor: const Color(0xFFA855F7), value: 'Gold', label: 'ELO Rank', dark: dark, cardBg: cardBg),
            ],
          ),
          const SizedBox(height: 20),

          // ── Contact Info ──
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Contact Information', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textPrimary)),
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              _ContactRow(icon: Icons.mail_outline,    text: 'john.doe@email.com', dark: dark, cardBg: cardBg),
              const SizedBox(height: 8),
              _ContactRow(icon: Icons.phone_outlined,  text: '+84 123 456 789',   dark: dark, cardBg: cardBg),
              const SizedBox(height: 8),
              _ContactRow(icon: Icons.location_on_outlined, text: 'Hanoi, Vietnam', dark: dark, cardBg: cardBg),
              const SizedBox(height: 8),
              _ContactRow(icon: Icons.calendar_today_outlined, text: 'Joined March 2024', dark: dark, cardBg: cardBg),
            ],
          ),
          const SizedBox(height: 20),

          // ── Dark Mode Toggle ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    size: 22, color: dark ? const Color(0xFF60A5FA) : const Color(0xFF22C55E)),
                const SizedBox(width: 12),
                Expanded(child: Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary))),
                // Custom toggle switch
                GestureDetector(
                  onTap: () => onDarkModeChanged(!dark),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 52, height: 28,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF22C55E) : const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      alignment: dark ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 24, height: 24,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Color(0x30000000), blurRadius: 4)]),
                      ),
                    ),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool dark;
  final Color cardBg;

  const _StatCard({required this.icon, required this.iconColor, required this.value, required this.label, required this.dark, required this.cardBg});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: dark ? Colors.white : const Color(0xFF111827))),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool dark;
  final Color cardBg;

  const _ContactRow({required this.icon, required this.text, required this.dark, required this.cardBg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 13, color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151))),
        ],
      ),
    );
  }
}
