import 'package:flutter/material.dart';

import '../services/auth_api.dart';
import '../services/avatar_picker.dart';

class ProfileScreen extends StatefulWidget {
  final bool isDarkMode;
  final AuthUser? user;
  final String? token;
  final ValueChanged<bool> onDarkModeChanged;

  const ProfileScreen({
    super.key,
    required this.isDarkMode,
    required this.user,
    required this.token,
    required this.onDarkModeChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authApi = AuthApi();
  late Future<UserProfile> _profileFuture;
  bool _avatarUploading = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token || oldWidget.user != widget.user) {
      _profileFuture = _loadProfile();
    }
  }

  Future<UserProfile> _loadProfile() {
    final token = widget.token;
    if (token == null || token.trim().isEmpty) {
      return Future.value(UserProfile.fromAuthUser(widget.user));
    }

    return _authApi.profile(token);
  }

  void _retry() {
    setState(() {
      _profileFuture = _loadProfile();
    });
  }

  Future<void> _showEditProfile(UserProfile profile) async {
    final token = widget.token;
    if (token == null || token.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để sửa hồ sơ.')),
      );
      return;
    }

    final updatedProfile = await showDialog<UserProfile>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EditProfileDialog(
        dark: widget.isDarkMode,
        profile: profile,
        onSave: (request) => _authApi.updateProfile(
          token: token,
          request: request,
        ),
      ),
    );

    if (!mounted || updatedProfile == null) return;

    setState(() {
      _profileFuture = Future.value(updatedProfile);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã cập nhật hồ sơ.')),
    );
  }

  Future<void> _chooseAvatar() async {
    final token = widget.token;
    if (token == null || token.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để đổi ảnh.')),
      );
      return;
    }

    try {
      final avatar = await pickAvatarFile();
      if (avatar == null) return;

      setState(() => _avatarUploading = true);
      final updatedProfile = await _authApi.uploadAvatar(
        token: token,
        avatar: avatar,
      );

      if (!mounted) return;
      setState(() {
        _profileFuture = Future.value(updatedProfile);
        _avatarUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật ảnh đại diện.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _avatarUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallbackProfile = UserProfile.fromAuthUser(widget.user);

    return FutureBuilder<UserProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data ?? fallbackProfile;
        final loading = snapshot.connectionState == ConnectionState.waiting &&
            widget.token != null;
        final error = snapshot.hasError ? snapshot.error.toString() : null;

        return _ProfileContent(
          dark: widget.isDarkMode,
          profile: profile,
          loading: loading,
          error: error,
          onRetry: _retry,
          onEdit: _showEditProfile,
          onAvatarPick: _chooseAvatar,
          avatarUploading: _avatarUploading,
          onDarkModeChanged: widget.onDarkModeChanged,
        );
      },
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final bool dark;
  final UserProfile profile;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<UserProfile> onEdit;
  final VoidCallback onAvatarPick;
  final bool avatarUploading;
  final ValueChanged<bool> onDarkModeChanged;

  const _ProfileContent({
    required this.dark,
    required this.profile,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onEdit,
    required this.onAvatarPick,
    required this.avatarUploading,
    required this.onDarkModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      physics: const ClampingScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileHeader(
                profile: profile,
                dark: dark,
                loading: loading,
                onEdit: () => onEdit(profile),
                onAvatarPick: onAvatarPick,
                avatarUploading: avatarUploading,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                _ErrorNotice(message: error!, dark: dark, onRetry: onRetry),
              ],
              const SizedBox(height: 16),
              _PlayingInfoGrid(profile: profile, dark: dark),
              const SizedBox(height: 16),
              _BioCard(profile: profile, dark: dark),
              const SizedBox(height: 16),
              _MatchHistorySection(
                matches: profile.matchHistory,
                matchesPlayed: profile.matchesPlayed,
                loading: loading,
                dark: dark,
              ),
              const SizedBox(height: 16),
              _DarkModeTile(
                dark: dark,
                onChanged: onDarkModeChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;
  final bool dark;
  final bool loading;
  final VoidCallback onEdit;
  final VoidCallback onAvatarPick;
  final bool avatarUploading;

  const _ProfileHeader({
    required this.profile,
    required this.dark,
    required this.loading,
    required this.onEdit,
    required this.onAvatarPick,
    required this.avatarUploading,
  });

  @override
  Widget build(BuildContext context) {
    final surface = dark ? const Color(0xFF1F2937) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final primary = dark ? Colors.white : const Color(0xFF111827);
    final secondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                _AvatarPickerButton(
                  dark: dark,
                  uploading: avatarUploading,
                  onTap: onAvatarPick,
                ),
                _EditProfileButton(dark: dark, onTap: onEdit),
              ],
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final details = _HeaderDetails(
                profile: profile,
                dark: dark,
                primary: primary,
                secondary: secondary,
                centered: compact,
              );

              if (compact) {
                return Column(
                  children: [
                    _ProfileAvatar(profile: profile),
                    const SizedBox(height: 14),
                    details,
                  ],
                );
              }

              return Row(
                children: [
                  _ProfileAvatar(profile: profile),
                  const SizedBox(width: 16),
                  Expanded(child: details),
                ],
              );
            },
          ),
          if (loading) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: const LinearProgressIndicator(
                minHeight: 4,
                color: Color(0xFF22C55E),
                backgroundColor: Color(0xFFE5E7EB),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _MetricCard(
                value: '${profile.matchesPlayed}',
                label: 'Trận đã tham gia',
                icon: Icons.sports_tennis,
                dark: dark,
              ),
              const SizedBox(width: 10),
              _MetricCard(
                value: _skillValue(profile.skillLevel),
                label: 'Trình độ',
                icon: Icons.trending_up,
                dark: dark,
              ),
              const SizedBox(width: 10),
              _MetricCard(
                value: '${profile.prestige ?? 0}',
                label: 'Prestige',
                icon: Icons.workspace_premium_outlined,
                dark: dark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditProfileButton extends StatelessWidget {
  final bool dark;
  final VoidCallback onTap;

  const _EditProfileButton({
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.edit_outlined, size: 16),
      label: const Text('Sửa hồ sơ'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF22C55E),
        side: BorderSide(
          color: const Color(0xFF22C55E).withValues(alpha: 0.45),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: dark
            ? const Color(0xFF22C55E).withValues(alpha: 0.08)
            : const Color(0xFFF0FDF4),
      ),
    );
  }
}

class _AvatarPickerButton extends StatelessWidget {
  final bool dark;
  final bool uploading;
  final VoidCallback onTap;

  const _AvatarPickerButton({
    required this.dark,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: uploading ? null : onTap,
      icon: uploading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF22C55E),
              ),
            )
          : const Icon(Icons.photo_camera_outlined, size: 16),
      label: Text(uploading ? 'Đang tải' : 'Đổi ảnh'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF22C55E),
        disabledForegroundColor:
            const Color(0xFF22C55E).withValues(alpha: 0.55),
        side: BorderSide(
          color: const Color(0xFF22C55E).withValues(alpha: 0.45),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: dark
            ? const Color(0xFF22C55E).withValues(alpha: 0.08)
            : const Color(0xFFF0FDF4),
      ),
    );
  }
}

class _HeaderDetails extends StatelessWidget {
  final UserProfile profile;
  final bool dark;
  final Color primary;
  final Color secondary;
  final bool centered;

  const _HeaderDetails({
    required this.profile,
    required this.dark,
    required this.primary,
    required this.secondary,
    required this.centered,
  });

  @override
  Widget build(BuildContext context) {
    final city = _valueOrFallback(profile.city, 'Chưa cập nhật thành phố');
    final skill = _skillLabel(profile.skillLevel);

    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          profile.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: primary,
          ),
        ),
        const SizedBox(height: 5),
        Wrap(
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            _InlineMeta(
              icon: Icons.location_on_outlined,
              label: city,
              color: secondary,
            ),
            _SoftPill(
              label: skill,
              icon: Icons.bolt_outlined,
              color: const Color(0xFF22C55E),
              dark: dark,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          profile.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: TextStyle(fontSize: 12, color: secondary),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final UserProfile profile;

  const _ProfileAvatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _clean(profile.profileImageUrl);
    final initials = _initials(profile.username);

    return Container(
      width: 88,
      height: 88,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: imageUrl == null
          ? _InitialsText(initials: initials)
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _InitialsText(initials: initials),
            ),
    );
  }
}

class _InitialsText extends StatelessWidget {
  final String initials;

  const _InitialsText({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool dark;

  const _MetricCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF374151) : const Color(0xFFF9FAFB);
    final border = dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB);
    final primary = dark ? Colors.white : const Color(0xFF111827);
    final secondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF22C55E), size: 19),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: primary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayingInfoGrid extends StatelessWidget {
  final UserProfile profile;
  final bool dark;

  const _PlayingInfoGrid({
    required this.profile,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      dark: dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Thông tin chơi',
            icon: Icons.person_search_outlined,
            dark: dark,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 560 ? 2 : 1;
              final spacing = columns == 2 ? 10.0 : 0.0;
              final itemWidth = (constraints.maxWidth - spacing) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _InfoTile(
                      icon: Icons.location_city_outlined,
                      label: 'Thành phố',
                      value: _valueOrFallback(profile.city, 'Chưa cập nhật'),
                      dark: dark,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _InfoTile(
                      icon: Icons.trending_up,
                      label: 'Trình độ chơi',
                      value: _skillDescription(profile.skillLevel),
                      dark: dark,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _InfoTile(
                      icon: Icons.back_hand_outlined,
                      label: 'Tay thuận',
                      value: _valueOrFallback(
                        profile.dominantHand,
                        'Chưa cập nhật',
                      ),
                      dark: dark,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _InfoTile(
                      icon: Icons.sports_outlined,
                      label: 'Vị trí hay chơi',
                      value: _valueOrFallback(
                        profile.preferredPosition ?? profile.playerSubType,
                        'Linh hoạt',
                      ),
                      dark: dark,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BioCard extends StatelessWidget {
  final UserProfile profile;
  final bool dark;

  const _BioCard({
    required this.profile,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final text = _valueOrFallback(
      profile.bio,
      'Người chơi PickleMatch đang xây dựng hồ sơ thi đấu.',
    );
    final secondary = dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);

    return _SectionCard(
      dark: dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Mô tả ngắn',
            icon: Icons.notes_outlined,
            dark: dark,
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchHistorySection extends StatelessWidget {
  final List<ProfileMatch> matches;
  final int matchesPlayed;
  final bool loading;
  final bool dark;

  const _MatchHistorySection({
    required this.matches,
    required this.matchesPlayed,
    required this.loading,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      dark: dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionTitle(
                  title: 'Lịch sử trận đã tham gia',
                  icon: Icons.history,
                  dark: dark,
                ),
              ),
              _CountPill(count: matchesPlayed, dark: dark),
            ],
          ),
          const SizedBox(height: 12),
          if (loading && matches.isEmpty)
            _LoadingHistory(dark: dark)
          else if (matches.isEmpty)
            _EmptyHistory(dark: dark)
          else
            Column(
              children: [
                for (var i = 0; i < matches.length; i++) ...[
                  _MatchTile(match: matches[i], dark: dark),
                  if (i != matches.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final ProfileMatch match;
  final bool dark;

  const _MatchTile({
    required this.match,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final primary = dark ? Colors.white : const Color(0xFF111827);
    final secondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sports_tennis,
              color: Color(0xFF22C55E),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '#${match.matchId} - ${match.matchType}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: primary,
                      ),
                    ),
                    _StatusPill(status: match.status, dark: dark),
                  ],
                ),
                const SizedBox(height: 5),
                _InlineMeta(
                  icon: Icons.schedule_outlined,
                  label: _formatDateTime(match.matchTime),
                  color: secondary,
                ),
                const SizedBox(height: 5),
                _InlineMeta(
                  icon: Icons.place_outlined,
                  label: _venueLabel(match),
                  color: secondary,
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MiniTag(
                      label: 'Cấp ${match.matchSkillLevel}',
                      dark: dark,
                    ),
                    if (_clean(match.participantClass) != null)
                      _MiniTag(label: match.participantClass!, dark: dark),
                    if (_clean(match.scoreInfo) != null)
                      _MiniTag(label: 'Điểm ${match.scoreInfo}', dark: dark),
                    if (_clean(match.checkInStatus) != null)
                      _MiniTag(
                        label: 'Check-in ${match.checkInStatus}',
                        dark: dark,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool dark;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final primary = dark ? Colors.white : const Color(0xFF111827);
    final secondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF22C55E), size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: secondary),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primary,
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

class _SectionCard extends StatelessWidget {
  final bool dark;
  final Widget child;

  const _SectionCard({
    required this.dark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final surface = dark ? const Color(0xFF1F2937) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool dark;

  const _SectionTitle({
    required this.title,
    required this.icon,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: const Color(0xFF22C55E)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: dark ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  final String message;
  final bool dark;
  final VoidCallback onRetry;

  const _ErrorNotice({
    required this.message,
    required this.dark,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: dark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: dark ? const Color(0xFFFECACA) : const Color(0xFF991B1B),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Thử lại'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingHistory extends StatelessWidget {
  final bool dark;

  const _LoadingHistory({required this.dark});

  @override
  Widget build(BuildContext context) {
    final secondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      height: 92,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Color(0xFF22C55E),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Đang tải lịch sử trận...',
            style: TextStyle(fontSize: 12, color: secondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final bool dark;

  const _EmptyHistory({required this.dark});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final primary = dark ? Colors.white : const Color(0xFF111827);
    final secondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_available_outlined,
              color: Color(0xFF22C55E), size: 28),
          const SizedBox(height: 8),
          Text(
            'Chưa có trận đã tham gia',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Khi bạn tham gia trận đấu, lịch sử sẽ xuất hiện tại đây.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: secondary),
          ),
        ],
      ),
    );
  }
}

class _DarkModeTile extends StatelessWidget {
  final bool dark;
  final ValueChanged<bool> onChanged;

  const _DarkModeTile({
    required this.dark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1F2937) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final primary = dark ? Colors.white : const Color(0xFF111827);
    final secondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            size: 22,
            color: dark ? const Color(0xFF60A5FA) : const Color(0xFF22C55E),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Giao diện tối',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dark ? 'Đang bật' : 'Đang tắt',
                  style: TextStyle(fontSize: 11, color: secondary),
                ),
              ],
            ),
          ),
          Switch(
            value: dark,
            activeThumbColor: const Color(0xFF22C55E),
            activeTrackColor: const Color(0xFFBBF7D0),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final bool dark;
  final UserProfile profile;
  final Future<UserProfile> Function(UpdateProfileRequest request) onSave;

  const _EditProfileDialog({
    required this.dark,
    required this.profile,
    required this.onSave,
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _usernameController;
  late final TextEditingController _cityController;
  late final TextEditingController _avatarController;
  late final TextEditingController _playerSubTypeController;
  late final TextEditingController _dominantHandController;
  late final TextEditingController _preferredPositionController;
  late final TextEditingController _bioController;
  late double _skillLevel;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _usernameController = TextEditingController(text: profile.username);
    _cityController = TextEditingController(text: profile.city ?? '');
    _avatarController =
        TextEditingController(text: profile.profileImageUrl ?? '');
    _playerSubTypeController =
        TextEditingController(text: profile.playerSubType ?? '');
    _dominantHandController =
        TextEditingController(text: profile.dominantHand ?? '');
    _preferredPositionController =
        TextEditingController(text: profile.preferredPosition ?? '');
    _bioController = TextEditingController(text: profile.bio ?? '');
    _skillLevel = (profile.skillLevel ?? 0).clamp(0, 5).toDouble();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _cityController.dispose();
    _avatarController.dispose();
    _playerSubTypeController.dispose();
    _dominantHandController.dispose();
    _preferredPositionController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    if (username.length < 3) {
      setState(() {
        _error = 'Tên người dùng phải có ít nhất 3 ký tự.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updatedProfile = await widget.onSave(
        UpdateProfileRequest(
          username: username,
          city: _clean(_cityController.text),
          profileImageUrl: _clean(_avatarController.text),
          skillLevel: _skillLevel,
          playerSubType: _clean(_playerSubTypeController.text),
          dominantHand: _clean(_dominantHandController.text),
          preferredPosition: _clean(_preferredPositionController.text),
          bio: _clean(_bioController.text),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(updatedProfile);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final bg = dark ? const Color(0xFF1F2937) : Colors.white;
    final fieldBg = dark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final primary = dark ? Colors.white : const Color(0xFF111827);
    final secondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_outlined,
                            color: Color(0xFF22C55E), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Sửa hồ sơ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: primary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close, color: secondary),
                          tooltip: 'Đóng',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_error != null) ...[
                      _EditError(message: _error!, dark: dark),
                      const SizedBox(height: 12),
                    ],
                    _EditTextField(
                      controller: _usernameController,
                      label: 'Tên hiển thị',
                      icon: Icons.person_outline,
                      dark: dark,
                      fieldBg: fieldBg,
                      maxLength: 100,
                    ),
                    const SizedBox(height: 10),
                    _EditTextField(
                      controller: _cityController,
                      label: 'Thành phố',
                      icon: Icons.location_city_outlined,
                      dark: dark,
                      fieldBg: fieldBg,
                      maxLength: 100,
                    ),
                    const SizedBox(height: 10),
                    _EditTextField(
                      controller: _avatarController,
                      label: 'URL ảnh đại diện',
                      icon: Icons.image_outlined,
                      dark: dark,
                      fieldBg: fieldBg,
                      maxLength: 500,
                    ),
                    const SizedBox(height: 12),
                    _SkillEditor(
                      value: _skillLevel,
                      dark: dark,
                      onChanged: (value) => setState(() => _skillLevel = value),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumns = constraints.maxWidth >= 500;
                        final width = twoColumns
                            ? (constraints.maxWidth - 10) / 2
                            : constraints.maxWidth;

                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: width,
                              child: _EditTextField(
                                controller: _dominantHandController,
                                label: 'Tay thuận',
                                icon: Icons.back_hand_outlined,
                                dark: dark,
                                fieldBg: fieldBg,
                                maxLength: 50,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _EditTextField(
                                controller: _preferredPositionController,
                                label: 'Vị trí hay chơi',
                                icon: Icons.sports_outlined,
                                dark: dark,
                                fieldBg: fieldBg,
                                maxLength: 100,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _EditTextField(
                      controller: _playerSubTypeController,
                      label: 'Phong cách chơi',
                      icon: Icons.bolt_outlined,
                      dark: dark,
                      fieldBg: fieldBg,
                      maxLength: 50,
                    ),
                    const SizedBox(height: 10),
                    _EditTextField(
                      controller: _bioController,
                      label: 'Mô tả ngắn',
                      icon: Icons.notes_outlined,
                      dark: dark,
                      fieldBg: fieldBg,
                      maxLength: 500,
                      minLines: 3,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: secondary,
                              side: BorderSide(color: border),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _submit,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined, size: 17),
                            label: Text(_saving ? 'Đang lưu' : 'Lưu'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF22C55E)
                                  .withValues(alpha: 0.5),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool dark;
  final Color fieldBg;
  final int maxLength;
  final int minLines;
  final int maxLines;

  const _EditTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.dark,
    required this.fieldBg,
    required this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final primary = dark ? Colors.white : const Color(0xFF111827);
    final secondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      style: TextStyle(fontSize: 13, color: primary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: secondary),
        prefixIcon: Icon(icon, size: 19, color: const Color(0xFF22C55E)),
        filled: true,
        fillColor: fieldBg,
        counterText: '',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF22C55E), width: 1.4),
        ),
      ),
    );
  }
}

class _SkillEditor extends StatelessWidget {
  final double value;
  final bool dark;
  final ValueChanged<double> onChanged;

  const _SkillEditor({
    required this.value,
    required this.dark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final primary = dark ? Colors.white : const Color(0xFF111827);
    final secondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, size: 19, color: Color(0xFF22C55E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Trình độ chơi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: secondary,
                  ),
                ),
              ),
              Text(
                value <= 0 ? 'Mới bắt đầu' : value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: primary,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF22C55E),
              inactiveTrackColor:
                  dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
              thumbColor: const Color(0xFF22C55E),
              overlayColor: const Color(0xFF22C55E).withValues(alpha: 0.14),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 5,
              divisions: 10,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditError extends StatelessWidget {
  final String message;
  final bool dark;

  const _EditError({
    required this.message,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: dark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.28)),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          color: dark ? const Color(0xFFFECACA) : const Color(0xFF991B1B),
        ),
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InlineMeta({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ),
      ],
    );
  }
}

class _SoftPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool dark;

  const _SoftPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;
  final bool dark;

  const _CountPill({
    required this.count,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return _SoftPill(
      label: '$count trận',
      icon: Icons.format_list_numbered,
      color: const Color(0xFF22C55E),
      dark: dark,
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final bool dark;

  const _StatusPill({
    required this.status,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return _SoftPill(
      label: _statusLabel(status),
      icon: Icons.circle,
      color: color,
      dark: dark,
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final bool dark;

  const _MiniTag({
    required this.label,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
        ),
      ),
    );
  }
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) return 'U';
  if (parts.length == 1) {
    final name = parts.first;
    return (name.length <= 2 ? name : name.substring(0, 2)).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String _valueOrFallback(String? value, String fallback) {
  return _clean(value) ?? fallback;
}

String _skillValue(double? skillLevel) {
  if (skillLevel == null || skillLevel <= 0) return 'Mới';
  return skillLevel.toStringAsFixed(1);
}

String _skillLabel(double? skillLevel) {
  if (skillLevel == null || skillLevel <= 0) return 'Mới bắt đầu';
  if (skillLevel < 2) return 'Cơ bản';
  if (skillLevel < 3.5) return 'Trung bình';
  if (skillLevel < 4.5) return 'Khá';
  return 'Nâng cao';
}

String _skillDescription(double? skillLevel) {
  if (skillLevel == null || skillLevel <= 0) return 'Mới bắt đầu';
  return '${skillLevel.toStringAsFixed(1)} - ${_skillLabel(skillLevel)}';
}

String _formatDateTime(DateTime? value) {
  if (value == null) return 'Chưa có thời gian';
  final local = value.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year} - ${_two(local.hour)}:${_two(local.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');

String _venueLabel(ProfileMatch match) {
  final venueName = _clean(match.venueName);
  final court = match.courtNumber == null ? null : 'Sân ${match.courtNumber}';
  final parts = [if (venueName != null) venueName, if (court != null) court];
  if (parts.isEmpty) return 'Chưa có sân';
  return parts.join(' - ');
}

String _statusLabel(String status) {
  final normalized = status.toLowerCase();
  if (normalized.contains('complete') || normalized.contains('finish')) {
    return 'Đã xong';
  }
  if (normalized.contains('cancel')) return 'Đã hủy';
  if (normalized.contains('progress')) return 'Đang chơi';
  if (normalized.contains('scheduled')) return 'Sắp diễn ra';
  return status;
}

Color _statusColor(String status) {
  final normalized = status.toLowerCase();
  if (normalized.contains('complete') || normalized.contains('finish')) {
    return const Color(0xFF22C55E);
  }
  if (normalized.contains('cancel')) return const Color(0xFFEF4444);
  if (normalized.contains('progress')) return const Color(0xFF3B82F6);
  if (normalized.contains('scheduled')) return const Color(0xFFF59E0B);
  return const Color(0xFF6B7280);
}
