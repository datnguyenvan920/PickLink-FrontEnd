import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/auth_api.dart';

// ─── Public entry-point ───────────────────────────────────────────────────────

class AuthScreen extends StatefulWidget {
  /// Called when the user successfully logs in / registers, or presses "Skip".
  final ValueChanged<AuthSession?> onAuthSuccess;

  const AuthScreen({super.key, required this.onAuthSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

// ─── State ────────────────────────────────────────────────────────────────────

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _showLogin = true; // toggle between Login / Register panels

  late final AnimationController _bgCtrl;
  late final Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
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
            // Animated floating orbs
            const _FloatingOrbs(),

            // Main scrollable content
            SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 32),

                          // ── Logo & brand ──────────────────────────────
                          _Logo(),

                          const SizedBox(height: 36),

                          // ── Card (login / register) ───────────────────
                          _AuthCard(
                            showLogin: _showLogin,
                            onToggle: () =>
                                setState(() => _showLogin = !_showLogin),
                            onSuccess: (session) =>
                                widget.onAuthSuccess(session),
                          ),

                          const SizedBox(height: 24),

                          // ── Skip button ───────────────────────────────
                          _SkipButton(onSkip: () => widget.onAuthSuccess(null)),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Floating Orbs ────────────────────────────────────────────────────────────

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
    for (final timer in _startTimers) {
      timer.cancel();
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

// ─── Logo ─────────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Pickleball icon ring
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.15),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.sports_tennis,
              size: 40,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'PickleMatch',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Connect · Play · Compete',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.75),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─── Auth Card ────────────────────────────────────────────────────────────────

class _AuthCard extends StatelessWidget {
  final bool showLogin;
  final VoidCallback onToggle;
  final ValueChanged<AuthSession> onSuccess;

  const _AuthCard({
    required this.showLogin,
    required this.onToggle,
    required this.onSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) {
        final isForward = child.key == const ValueKey('login');
        final slide = Tween<Offset>(
          begin: Offset(isForward ? -0.3 : 0.3, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: showLogin
          ? _LoginPanel(
              key: const ValueKey('login'),
              onSuccess: onSuccess,
              onSwitchToRegister: onToggle,
            )
          : _RegisterPanel(
              key: const ValueKey('register'),
              onSuccess: onSuccess,
              onSwitchToLogin: onToggle,
            ),
    );
  }
}

// ─── Shared card container ────────────────────────────────────────────────────

class _CardContainer extends StatelessWidget {
  final Widget child;
  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Login Panel ──────────────────────────────────────────────────────────────

void _showAuthSnackBar(BuildContext context, String message,
    {bool error = true}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            error ? const Color(0xFFDC2626) : const Color(0xFF059669),
      ),
    );
}

String _authErrorMessage(Object error, String fallback) {
  if (error is ApiException) {
    return error.message;
  }
  return fallback;
}

class _LoginPanel extends StatefulWidget {
  final ValueChanged<AuthSession> onSuccess;
  final VoidCallback onSwitchToRegister;

  const _LoginPanel({
    super.key,
    required this.onSuccess,
    required this.onSwitchToRegister,
  });

  @override
  State<_LoginPanel> createState() => _LoginPanelState();
}

class _LoginPanelState extends State<_LoginPanel> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _loading = true);
    try {
      final session = await AuthApi().login(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
      );
      if (mounted) widget.onSuccess(session);
    } catch (error) {
      if (mounted) {
        _showAuthSnackBar(
          context,
          _authErrorMessage(
              error, 'Could not sign in. Check that the backend is running.'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Welcome back!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sign in to continue playing',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 24),

            // Google sign-in
            _GoogleButton(
              onTap: () => _showAuthSnackBar(
                context,
                'Google sign-in is not connected to the backend yet.',
              ),
            ),
            const SizedBox(height: 18),

            // Divider
            _OrDivider(),
            const SizedBox(height: 18),

            // Email field
            _GlassField(
              controller: _emailCtrl,
              label: 'Email address',
              hint: 'you@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!v.contains('@')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Password field
            _GlassField(
              controller: _pwCtrl,
              label: 'Password',
              hint: '••••••••',
              icon: Icons.lock_outline,
              obscureText: _obscure,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Password is required';
                }
                if (v.length < 6) {
                  return 'At least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),

            // Forgot password
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {},
                child: Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
            _PrimaryButton(
              label: 'Sign In',
              loading: _loading,
              onTap: _submit,
            ),
            const SizedBox(height: 20),

            // Switch to register
            Center(
              child: GestureDetector(
                onTap: widget.onSwitchToRegister,
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13),
                    children: [
                      TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const TextSpan(
                        text: 'Create one',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Register Panel ───────────────────────────────────────────────────────────

class _RegisterPanel extends StatefulWidget {
  final ValueChanged<AuthSession> onSuccess;
  final VoidCallback onSwitchToLogin;

  const _RegisterPanel({
    super.key,
    required this.onSuccess,
    required this.onSwitchToLogin,
  });

  @override
  State<_RegisterPanel> createState() => _RegisterPanelState();
}

class _RegisterPanelState extends State<_RegisterPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: 'Ho Chi Minh');
  final _pwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    _pwCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _loading = true);
    try {
      final session = await AuthApi().register(
        username: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        profileImageUrl: null,
      );
      if (mounted) widget.onSuccess(session);
    } catch (error) {
      if (mounted) {
        _showAuthSnackBar(
          context,
          _authErrorMessage(error,
              'Could not create account. Check that the backend is running.'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Create account',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Join the pickleball community',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 24),

            // Google sign-up
            _GoogleButton(
              label: 'Sign up with Google',
              onTap: () => _showAuthSnackBar(
                context,
                'Google sign-up is not connected to the backend yet.',
              ),
            ),
            const SizedBox(height: 18),

            _OrDivider(),
            const SizedBox(height: 18),

            // Username
            _GlassField(
              controller: _nameCtrl,
              label: 'Username',
              hint: 'nam',
              icon: Icons.person_outline,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Username is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Email
            _GlassField(
              controller: _emailCtrl,
              label: 'Email address',
              hint: 'you@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!v.contains('@')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // City
            _GlassField(
              controller: _cityCtrl,
              label: 'City',
              hint: 'Ho Chi Minh',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 12),

            // Password
            _GlassField(
              controller: _pwCtrl,
              label: 'Password',
              hint: '••••••••',
              icon: Icons.lock_outline,
              obscureText: _obscurePw,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePw
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePw = !_obscurePw),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Password is required';
                }
                if (v.length < 6) {
                  return 'At least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Confirm password
            _GlassField(
              controller: _confirmCtrl,
              label: 'Confirm password',
              hint: '••••••••',
              icon: Icons.lock_outline,
              obscureText: _obscureConfirm,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please confirm password';
                }
                if (v != _pwCtrl.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            _PrimaryButton(
              label: 'Create Account',
              loading: _loading,
              onTap: _submit,
            ),
            const SizedBox(height: 20),

            Center(
              child: GestureDetector(
                onTap: widget.onSwitchToLogin,
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13),
                    children: [
                      TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const TextSpan(
                        text: 'Sign in',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _GlassField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: Colors.white70, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.12),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
            ),
            errorStyle: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: loading ? null : onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GoogleButton({
    this.label = 'Continue with Google',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Google "G" logo painted manually
                const _GoogleLogo(size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

/// Simple Google "G" logo painted with CustomPaint.
class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw circle segments (simplified Google colors)
    const colors = [
      Color(0xFF4285F4), // Blue
      Color(0xFF34A853), // Green
      Color(0xFFFBBC05), // Yellow
      Color(0xFFEA4335), // Red
    ];

    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      paint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi / 2 + i * math.pi / 2,
        math.pi / 2,
        true,
        paint,
      );
    }

    // White circle cutout (donut)
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.60, paint);

    // "G" bar — white fill then blue bar
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTRB(center.dx, center.dy - radius * 0.15, center.dx + radius,
          center.dy + radius * 0.15),
      paint,
    );

    // Inner white circle to complete the donut ring illusion
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.58, paint);

    // Repaint the blue right-side arc text area
    paint.color = const Color(0xFF4285F4);
    // Simpler: just draw the colored ring segments again smaller
    for (int i = 0; i < 4; i++) {
      paint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.80),
        math.pi / 2 + i * math.pi / 2,
        math.pi / 2,
        true,
        paint,
      );
    }
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.55, paint);

    // Blue horizontal bar for the "G" cross
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx - radius * 0.02,
        center.dy - radius * 0.13,
        center.dx + radius * 0.78,
        center.dy + radius * 0.13,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter _) => false;
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
      ],
    );
  }
}

// ─── Skip Button ──────────────────────────────────────────────────────────────

class _SkipButton extends StatelessWidget {
  final VoidCallback onSkip;
  const _SkipButton({required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSkip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1,
          ),
          color: Colors.white.withValues(alpha: 0.08),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Skip for now',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.80),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ],
        ),
      ),
    );
  }
}
