import 'dart:async';

import 'package:flutter/material.dart';
import '../services/auth_api.dart';

// ─── Public entry-point ───────────────────────────────────────────────────────

enum UserRole { player, owner, venueStaff }

enum SkillLevel { beginner, intermediate, master }

/// Holds the choices the user made in the setup wizard.
class ProfileSetupResult {
  final UserRole role;
  final SkillLevel? skillLevel; // Player only
  final String? affiliationCode; // Venue Staff only

  const ProfileSetupResult({
    required this.role,
    this.skillLevel,
    this.affiliationCode,
  });
}

class ProfileSetupScreen extends StatefulWidget {
  /// Called when the wizard is complete.
  final ValueChanged<ProfileSetupResult> onComplete;

  /// The session of the currently logged-in user.
  /// Used to authenticate the assign-role API call.
  final AuthSession? authSession;

  const ProfileSetupScreen({
    super.key,
    required this.onComplete,
    this.authSession,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with TickerProviderStateMixin {
  // Step: 0 = role selection, 1 = role-specific follow-up
  int _step = 0;
  UserRole? _selectedRole;
  SkillLevel? _selectedSkill;
  bool _showAffiliationField = false;
  final _affiliationCtrl = TextEditingController();
  bool _affiliationError = false;
  bool _isLoading = false;

  // Slide / fade animation when advancing steps
  late AnimationController _slideCtrl;

  // Background animated gradient
  late AnimationController _bgCtrl;
  late Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _slideCtrl.dispose();
    _affiliationCtrl.dispose();
    super.dispose();
  }

  // ── Role selected on step 0 ──────────────────────────────────────────────
  void _onRoleTap(UserRole role) {
    setState(() {
      _selectedRole = role;
      _showAffiliationField = role == UserRole.venueStaff;
      _affiliationError = false;
    });
  }

  // ── "Continue" from step 0 ───────────────────────────────────────────────
  Future<void> _advanceFromStep0() async {
    if (_selectedRole == null || _isLoading) return;

    // Venue staff must fill in affiliation code
    if (_selectedRole == UserRole.venueStaff) {
      if (_affiliationCtrl.text.trim().isEmpty) {
        setState(() => _affiliationError = true);
        return;
      }
    }

    // Player needs to pick skill level — go to step 1 without calling API yet
    if (_selectedRole == UserRole.player) {
      _slideCtrl.forward(from: 0);
      setState(() => _step = 1);
      return;
    }

    // Owner & Venue Staff: call the API immediately
    await _submitRole();
  }

  // ── Skill selected on step 1 ─────────────────────────────────────────────
  void _onSkillTap(SkillLevel level) {
    setState(() => _selectedSkill = level);
  }

  // ── "Continue" from step 1 ───────────────────────────────────────────────
  Future<void> _advanceFromStep1() async {
    if (_selectedSkill == null || _isLoading) return;
    await _submitRole();
  }

  // ── Map enums → API strings ──────────────────────────────────────────────
  String _roleToApi(UserRole role) => switch (role) {
        UserRole.player     => 'Player',
        UserRole.owner      => 'VenueOwner',
        UserRole.venueStaff => 'Staff',
      };

  ExperienceLevel? _skillToExperience(SkillLevel? skill) => switch (skill) {
        SkillLevel.beginner     => ExperienceLevel.beginner,
        SkillLevel.intermediate => ExperienceLevel.intermediate,
        SkillLevel.master       => ExperienceLevel.advanced, // master → Advanced
        null                    => null,
      };

  // ── Call the backend then notify parent ──────────────────────────────────
  Future<void> _submitRole() async {
    setState(() => _isLoading = true);
    try {
      final token = widget.authSession?.token;
      if (token != null) {
        await AuthApi().assignRole(
          token,
          role: _roleToApi(_selectedRole!),
          experience: _skillToExperience(_selectedSkill),
        );
      }
      widget.onComplete(ProfileSetupResult(
        role: _selectedRole!,
        skillLevel: _selectedSkill,
        affiliationCode: _selectedRole == UserRole.venueStaff
            ? _affiliationCtrl.text.trim()
            : null,
      ));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AnimatedBuilder(
        animation: _bgAnim,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    const Color(0xFF064E3B),
                    const Color(0xFF065F46),
                    _bgAnim.value,
                  )!,
                  Color.lerp(
                    const Color(0xFF047857),
                    const Color(0xFF059669),
                    _bgAnim.value,
                  )!,
                  Color.lerp(
                    const Color(0xFF10B981),
                    const Color(0xFF34D399),
                    _bgAnim.value,
                  )!,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _FloatingOrbs(),
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                transitionBuilder: (child, anim) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0.25, 0),
                    end: Offset.zero,
                  ).animate(
                      CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: _step == 0
                    ? _Step0(
                        key: const ValueKey('step0'),
                        selectedRole: _selectedRole,
                        showAffiliationField: _showAffiliationField,
                        affiliationCtrl: _affiliationCtrl,
                        affiliationError: _affiliationError,
                        isLoading: _isLoading,
                        onRoleTap: _onRoleTap,
                        onContinue: _advanceFromStep0,
                      )
                    : _Step1Player(
                        key: const ValueKey('step1'),
                        selectedSkill: _selectedSkill,
                        isLoading: _isLoading,
                        onSkillTap: _onSkillTap,
                        onContinue: _advanceFromStep1,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 0 — Role Selection ──────────────────────────────────────────────────

class _Step0 extends StatelessWidget {
  final UserRole? selectedRole;
  final bool showAffiliationField;
  final TextEditingController affiliationCtrl;
  final bool affiliationError;
  final bool isLoading;
  final ValueChanged<UserRole> onRoleTap;
  final VoidCallback onContinue;

  const _Step0({
    super.key,
    required this.selectedRole,
    required this.showAffiliationField,
    required this.affiliationCtrl,
    required this.affiliationError,
    required this.isLoading,
    required this.onRoleTap,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom,
        ),
        child: IntrinsicHeight(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // ── Step indicator
              _StepIndicator(current: 0, total: 2),
              const SizedBox(height: 36),

              // ── Heading
              _QuestionHeading(
                step: '01',
                question: 'Which role do you fill?',
                subtitle: 'Choose the role that best describes you.',
              ),
              const SizedBox(height: 32),

              // ── Owner card
              _RoleCard(
                icon: Icons.business_center_outlined,
                title: 'Owner',
                subtitle: 'Manage your venue & staff',
                isSelected: selectedRole == UserRole.owner,
                onTap: () => onRoleTap(UserRole.owner),
              ),
              const SizedBox(height: 14),

              // ── Player card
              _RoleCard(
                icon: Icons.sports_tennis,
                title: 'Player',
                subtitle: 'Join matches & compete',
                isSelected: selectedRole == UserRole.player,
                onTap: () => onRoleTap(UserRole.player),
              ),
              const SizedBox(height: 20),

              // ── Venue Staff (smaller)
              _VenueStaffTile(
                isSelected: selectedRole == UserRole.venueStaff,
                onTap: () => onRoleTap(UserRole.venueStaff),
              ),

              // ── Affiliation code (animated expand)
              AnimatedSize(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOut,
                child: showAffiliationField
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _AffiliationField(
                          controller: affiliationCtrl,
                          hasError: affiliationError,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 36),

              // ── Continue button
              _ContinueButton(
                enabled: selectedRole != null && !isLoading,
                isLoading: isLoading,
                onTap: onContinue,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Step 1 — Player Skill ────────────────────────────────────────────────────

class _Step1Player extends StatelessWidget {
  final SkillLevel? selectedSkill;
  final bool isLoading;
  final ValueChanged<SkillLevel> onSkillTap;
  final VoidCallback onContinue;

  const _Step1Player({
    super.key,
    required this.selectedSkill,
    required this.isLoading,
    required this.onSkillTap,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom,
        ),
        child: IntrinsicHeight(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              _StepIndicator(current: 1, total: 2),
              const SizedBox(height: 36),

              _QuestionHeading(
                step: '02',
                question: 'What\'s your skill level?',
                subtitle: 'Help us match you with the right players.',
              ),
              const SizedBox(height: 36),

              _SkillCard(
                level: SkillLevel.beginner,
                icon: Icons.emoji_events_outlined,
                title: 'Beginner',
                subtitle: 'Just getting started',
                accentColor: const Color(0xFF34D399),
                isSelected: selectedSkill == SkillLevel.beginner,
                onTap: () => onSkillTap(SkillLevel.beginner),
              ),
              const SizedBox(height: 14),

              _SkillCard(
                level: SkillLevel.intermediate,
                icon: Icons.flash_on,
                title: 'Intermediate',
                subtitle: 'Comfortable with the basics',
                accentColor: const Color(0xFFFBBF24),
                isSelected: selectedSkill == SkillLevel.intermediate,
                onTap: () => onSkillTap(SkillLevel.intermediate),
              ),
              const SizedBox(height: 14),

              _SkillCard(
                level: SkillLevel.master,
                icon: Icons.workspace_premium,
                title: 'Master',
                subtitle: 'Experienced & competitive',
                accentColor: const Color(0xFFF97316),
                isSelected: selectedSkill == SkillLevel.master,
                onTap: () => onSkillTap(SkillLevel.master),
              ),

              const SizedBox(height: 40),

              _ContinueButton(
                enabled: selectedSkill != null && !isLoading,
                isLoading: isLoading,
                label: 'Finish Setup',
                onTap: onContinue,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared UI atoms ──────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        final isDone = i < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 32 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive || isDone
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }
}

class _QuestionHeading extends StatelessWidget {
  final String step;
  final String question;
  final String subtitle;
  const _QuestionHeading(
      {required this.step, required this.question, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Text(
            'STEP $step',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          question,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// ─── Role Card (Owner / Player) ───────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.09),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF4ADE80), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.white.withValues(alpha: 0.15),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: isSelected ? 1 : 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Icon(Icons.check,
                    color: Color(0xFF059669), size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Venue Staff Tile (smaller) ───────────────────────────────────────────────

class _VenueStaffTile extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _VenueStaffTile({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.badge_outlined,
              color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.6),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Venue Staff',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: isSelected ? 1 : 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Work at a venue — affiliation code required',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: isSelected ? 1 : 0,
              child: Icon(Icons.check_circle,
                  color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Affiliation Code Field ───────────────────────────────────────────────────

class _AffiliationField extends StatelessWidget {
  final TextEditingController controller;
  final bool hasError;

  const _AffiliationField({required this.controller, required this.hasError});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFFCA5A5)
                  : Colors.white.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Affiliation code',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 15,
              ),
              prefixIcon: Icon(Icons.vpn_key_outlined,
                  color: Colors.white.withValues(alpha: 0.6), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFFCA5A5), size: 14),
              const SizedBox(width: 6),
              Text(
                'Please enter your affiliation code to continue.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── Skill Card ───────────────────────────────────────────────────────────────

class _SkillCard extends StatelessWidget {
  final SkillLevel level;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _SkillCard({
    required this.level,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? accentColor.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.09),
          border: Border.all(
            color: isSelected
                ? accentColor.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? accentColor.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.12),
                border: isSelected
                    ? Border.all(
                        color: accentColor.withValues(alpha: 0.6), width: 1.5)
                    : null,
              ),
              child: Icon(icon,
                  color: isSelected ? accentColor : Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? accentColor : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: isSelected ? 1 : 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Continue Button ──────────────────────────────────────────────────────────

class _ContinueButton extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final VoidCallback onTap;
  final String label;

  const _ContinueButton({
    required this.enabled,
    required this.onTap,
    this.isLoading = false,
    this.label = 'Continue',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFF4ADE80), Color(0xFF059669)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: enabled ? null : Colors.white.withValues(alpha: 0.12),
          boxShadow: enabled
              ? [
                  const BoxShadow(
                    color: Color(0x6022C55E),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else ...[  
              Text(
                label,
                style: TextStyle(
                  color: enabled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: enabled
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.35),
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Floating Orbs (reused from auth screen) ──────────────────────────────────

class _FloatingOrbs extends StatefulWidget {
  const _FloatingOrbs();

  @override
  State<_FloatingOrbs> createState() => _FloatingOrbsState();
}

class _FloatingOrbsState extends State<_FloatingOrbs>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;
  final List<Timer> _startTimers = [];

  static const _orbs = [
    _OrbConfig(top: -60, left: -40, size: 200, delay: 0.0, alpha: 0.10),
    _OrbConfig(top: 120, right: -60, size: 160, delay: 0.4, alpha: 0.08),
    _OrbConfig(bottom: 180, left: -30, size: 140, delay: 0.8, alpha: 0.09),
    _OrbConfig(bottom: -40, right: -20, size: 220, delay: 0.2, alpha: 0.07),
    _OrbConfig(top: 300, left: 60, size: 80, delay: 1.0, alpha: 0.12),
  ];

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(_orbs.length, (i) {
      final c = AnimationController(
        vsync: this,
        duration: Duration(seconds: 4 + (i * 2) % 4),
      );
      final timer =
          Timer(Duration(milliseconds: (500 * _orbs[i].delay).round()), () {
        if (mounted) c.repeat(reverse: true);
      });
      _startTimers.add(timer);
      return c;
    });
    _anims = _ctrls
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeInOut))
        .toList();
  }

  @override
  void dispose() {
    for (final t in _startTimers) {
      t.cancel();
    }
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(_orbs.length, (i) {
        final o = _orbs[i];
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) {
            final dy = (_anims[i].value - 0.5) * 30;
            return Positioned(
              top: o.top != null ? o.top! + dy : null,
              bottom: o.bottom != null ? o.bottom! - dy : null,
              left: o.left,
              right: o.right,
              child: Container(
                width: o.size,
                height: o.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: o.alpha),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class _OrbConfig {
  final double? top, bottom, left, right;
  final double size, delay, alpha;
  const _OrbConfig({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
    required this.delay,
    required this.alpha,
  });
}
