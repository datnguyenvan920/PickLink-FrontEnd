import 'package:flutter/material.dart';

import '../services/auth_api.dart';
import '../services/avatar_picker.dart';
import '../services/vietnam_location_service.dart';

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
              _PersonalInfoGrid(profile: profile, dark: dark),
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
    final city =
        _valueOrFallback(_locationLabel(profile), 'Chưa cập nhật địa điểm');
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

class _PersonalInfoGrid extends StatelessWidget {
  final UserProfile profile;
  final bool dark;

  const _PersonalInfoGrid({
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
            title: 'Thông tin cá nhân',
            icon: Icons.badge_outlined,
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
                      icon: Icons.cake_outlined,
                      label: 'Ngày sinh',
                      value: _formatDate(profile.birthDate),
                      dark: dark,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _InfoTile(
                      icon: Icons.wc_outlined,
                      label: 'Giới tính',
                      value: _valueOrFallback(profile.gender, 'Chưa cập nhật'),
                      dark: dark,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _InfoTile(
                      icon: Icons.height_outlined,
                      label: 'Chiều cao',
                      value: _measurementLabel(
                        profile.heightCm,
                        'cm',
                        'Chưa cập nhật',
                      ),
                      dark: dark,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _InfoTile(
                      icon: Icons.monitor_weight_outlined,
                      label: 'Cân nặng',
                      value: _measurementLabel(
                        profile.weightKg,
                        'kg',
                        'Chưa cập nhật',
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
                      label: 'Tỉnh/Thành phố',
                      value: _valueOrFallback(profile.city, 'Chưa cập nhật'),
                      dark: dark,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _InfoTile(
                      icon: Icons.place_outlined,
                      label: 'Xã/Phường',
                      value: _valueOrFallback(
                        profile.commune,
                        'Chưa cập nhật',
                      ),
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
                      icon: Icons.event_repeat_outlined,
                      label: 'Tần suất chơi',
                      value: _choiceTitle(
                        profile.playFrequency,
                        _playFrequencyOptions,
                        'Chưa cập nhật',
                      ),
                      dark: dark,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _InfoTile(
                      icon: Icons.schedule_outlined,
                      label: 'Khung giờ yêu thích',
                      value: _choiceTitle(
                        profile.preferredTimeSlot,
                        _preferredTimeSlotOptions,
                        'Chưa cập nhật',
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
      'Người chơi Picklink đang xây dựng hồ sơ thi đấu.',
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

class _ProfileChoiceOption {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;

  const _ProfileChoiceOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

const _playFrequencyOptions = <_ProfileChoiceOption>[
  _ProfileChoiceOption(
    value: 'daily',
    title: 'Hằng ngày',
    subtitle: 'Chơi thể thao mỗi ngày',
    icon: Icons.local_fire_department_outlined,
  ),
  _ProfileChoiceOption(
    value: 'two_to_three_weekly',
    title: '2-3 lần/tuần',
    subtitle: 'Tập đều đặn trong tuần',
    icon: Icons.fitness_center_outlined,
  ),
  _ProfileChoiceOption(
    value: 'weekend',
    title: 'Cuối tuần',
    subtitle: 'Chỉ vào thứ 7 & Chủ Nhật',
    icon: Icons.flag_outlined,
  ),
  _ProfileChoiceOption(
    value: 'occasionally',
    title: 'Thỉnh thoảng',
    subtitle: 'Khi có thời gian rảnh',
    icon: Icons.auto_awesome_outlined,
  ),
];

const _preferredTimeSlotOptions = <_ProfileChoiceOption>[
  _ProfileChoiceOption(
    value: 'morning',
    title: 'Sáng',
    subtitle: '06:00 - 11:00',
    icon: Icons.wb_sunny_outlined,
  ),
  _ProfileChoiceOption(
    value: 'afternoon',
    title: 'Chiều',
    subtitle: '12:00 - 17:00',
    icon: Icons.wb_cloudy_outlined,
  ),
  _ProfileChoiceOption(
    value: 'evening',
    title: 'Tối',
    subtitle: '18:00 - 22:00',
    icon: Icons.nightlight_round,
  ),
];

class _PlayPreferenceEditor extends StatelessWidget {
  final String? playFrequency;
  final String? preferredTimeSlot;
  final bool dark;
  final ValueChanged<String?> onFrequencyChanged;
  final ValueChanged<String?> onTimeSlotChanged;

  const _PlayPreferenceEditor({
    required this.playFrequency,
    required this.preferredTimeSlot,
    required this.dark,
    required this.onFrequencyChanged,
    required this.onTimeSlotChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PreferenceGroupTitle(
          title: 'Tần suất chơi',
          subtitle: 'Bạn thường chơi thể thao bao nhiêu lần một tuần?',
          dark: dark,
        ),
        const SizedBox(height: 10),
        Column(
          children: [
            for (final option in _playFrequencyOptions) ...[
              _FrequencyOptionTile(
                option: option,
                selected: playFrequency == option.value,
                dark: dark,
                onTap: () => onFrequencyChanged(
                  playFrequency == option.value ? null : option.value,
                ),
              ),
              if (option != _playFrequencyOptions.last)
                const SizedBox(height: 10),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Divider(height: 1, color: border),
        const SizedBox(height: 14),
        _PreferenceGroupTitle(
          title: 'Khung giờ yêu thích',
          subtitle: 'Chọn khung giờ bạn thích chơi thể thao nhất',
          dark: dark,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in _preferredTimeSlotOptions)
              _TimeSlotChip(
                option: option,
                selected: preferredTimeSlot == option.value,
                dark: dark,
                onTap: () => onTimeSlotChanged(
                  preferredTimeSlot == option.value ? null : option.value,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PreferenceGroupTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool dark;

  const _PreferenceGroupTitle({
    required this.title,
    required this.subtitle,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final primary = dark ? Colors.white : const Color(0xFF111827);
    final secondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: secondary),
        ),
      ],
    );
  }
}

class _FrequencyOptionTile extends StatelessWidget {
  final _ProfileChoiceOption option;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  const _FrequencyOptionTile({
    required this.option,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF111827) : Colors.white;
    final border = selected
        ? const Color(0xFF22C55E)
        : dark
            ? const Color(0xFF374151)
            : const Color(0xFFE5E7EB);
    final primary = dark ? Colors.white : const Color(0xFF111827);
    final secondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF22C55E).withValues(alpha: dark ? 0.14 : 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: selected ? 1.4 : 1),
          ),
          child: Row(
            children: [
              Icon(option.icon, color: const Color(0xFF22C55E), size: 23),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: TextStyle(fontSize: 11, color: secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 22,
                color: selected ? const Color(0xFF22C55E) : secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeSlotChip extends StatelessWidget {
  final _ProfileChoiceOption option;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  const _TimeSlotChip({
    required this.option,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF111827) : Colors.white;
    final border = selected
        ? const Color(0xFF22C55E)
        : dark
            ? const Color(0xFF374151)
            : const Color(0xFFE5E7EB);
    final primary = dark ? Colors.white : const Color(0xFF111827);
    final secondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Material(
      color: selected
          ? const Color(0xFF22C55E).withValues(alpha: dark ? 0.14 : 0.08)
          : bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minWidth: 122),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: selected ? 1.4 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(option.icon, color: const Color(0xFF22C55E), size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      option.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
  final _locationService = VietnamLocationService();
  late final TextEditingController _usernameController;
  late final TextEditingController _avatarController;
  late final TextEditingController _playerSubTypeController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _bioController;
  late double _skillLevel;
  DateTime? _birthDate;
  String? _gender;
  String? _playFrequency;
  String? _preferredTimeSlot;
  List<AdministrativeProvince> _provinces =
      VietnamLocationService.fallbackProvinces;
  List<AdministrativeWard> _wards = const [];
  String? _provinceName;
  int? _provinceCode;
  String? _communeName;
  bool _loadingProvinces = false;
  bool _loadingWards = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _usernameController = TextEditingController(text: profile.username);
    _avatarController =
        TextEditingController(text: profile.profileImageUrl ?? '');
    _playerSubTypeController =
        TextEditingController(text: profile.playerSubType ?? '');
    _heightController = TextEditingController(
      text: _numberInputText(profile.heightCm),
    );
    _weightController = TextEditingController(
      text: _numberInputText(profile.weightKg),
    );
    _bioController = TextEditingController(text: profile.bio ?? '');
    _skillLevel = (profile.skillLevel ?? 0).clamp(0, 5).toDouble();
    _birthDate = profile.birthDate;
    _gender = _clean(profile.gender);
    _playFrequency = _normalizeChoiceValue(
      profile.playFrequency,
      _playFrequencyOptions,
    );
    _preferredTimeSlot = _normalizeChoiceValue(
      profile.preferredTimeSlot,
      _preferredTimeSlotOptions,
    );
    _provinceName = VietnamLocationService.normalizeProvinceName(profile.city);
    _provinceCode =
        VietnamLocationService.findProvinceByName(_provinceName)?.code;
    _communeName = _clean(profile.commune);
    _loadProvinces();
    if (_provinceCode != null) {
      _loadWards(_provinceCode!, keepCurrentCommune: true);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _avatarController.dispose();
    _playerSubTypeController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    setState(() => _loadingProvinces = true);
    final provinces = await _locationService.provinces();
    if (!mounted) return;

    final selected =
        VietnamLocationService.matchProvince(_provinceName, provinces);
    setState(() {
      _provinces = provinces;
      _provinceName = selected?.name ?? _provinceName;
      _provinceCode = selected?.code ?? _provinceCode;
      _loadingProvinces = false;
    });
  }

  Future<void> _loadWards(
    int provinceCode, {
    bool keepCurrentCommune = false,
  }) async {
    setState(() => _loadingWards = true);
    final wards = await _locationService.wards(provinceCode);
    if (!mounted || _provinceCode != provinceCode) return;

    final currentCommune = _clean(_communeName);
    final communeStillExists = currentCommune != null &&
        wards.any((ward) => ward.name == currentCommune);

    setState(() {
      _wards = wards;
      if (!keepCurrentCommune || !communeStillExists) {
        _communeName = null;
      }
      _loadingWards = false;
    });
  }

  void _selectProvince(String? provinceName) {
    final province = _provinces.firstWhere(
      (province) => province.name == provinceName,
      orElse: () => VietnamLocationService.fallbackProvinces.firstWhere(
        (province) => province.name == provinceName,
        orElse: () => const AdministrativeProvince(name: '', code: 0),
      ),
    );

    setState(() {
      _provinceName = _clean(provinceName);
      _provinceCode = province.code == 0 ? null : province.code;
      _communeName = null;
      _wards = const [];
      _loadingWards = false;
    });

    if (province.code != 0) {
      _loadWards(province.code);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final fallbackDate = DateTime(now.year - 18, now.month, now.day);
    final initialDate = _birthDate ?? fallbackDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? fallbackDate : initialDate,
      firstDate: DateTime(1940),
      lastDate: now,
      builder: (context, child) {
        if (!widget.dark) return child ?? const SizedBox.shrink();

        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF22C55E),
              surface: Color(0xFF1F2937),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (pickedDate == null) return;
    setState(() {
      _birthDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
    });
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    if (username.length < 3) {
      setState(() {
        _error = 'Tên người dùng phải có ít nhất 3 ký tự.';
      });
      return;
    }

    final double? heightCm;
    final double? weightKg;
    try {
      heightCm = _parseOptionalMeasurement(
        _heightController.text,
        'Chiều cao',
        50,
        250,
        'cm',
      );
      weightKg = _parseOptionalMeasurement(
        _weightController.text,
        'Cân nặng',
        20,
        250,
        'kg',
      );
    } on FormatException catch (error) {
      setState(() {
        _error = error.message;
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
          city: _provinceName,
          commune: _communeName,
          profileImageUrl: _clean(_avatarController.text),
          skillLevel: _skillLevel,
          playerSubType: _clean(_playerSubTypeController.text),
          playFrequency: _playFrequency,
          preferredTimeSlot: _preferredTimeSlot,
          bio: _clean(_bioController.text),
          birthDate: _birthDate,
          gender: _gender,
          heightCm: heightCm,
          weightKg: weightKg,
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
                              child: _ProvinceSelector(
                                value: _provinceName,
                                provinces: _provinces,
                                loading: _loadingProvinces,
                                dark: dark,
                                fieldBg: fieldBg,
                                onChanged: _selectProvince,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _WardSelector(
                                value: _communeName,
                                wards: _wards,
                                provinceSelected: _provinceCode != null,
                                loading: _loadingWards,
                                dark: dark,
                                fieldBg: fieldBg,
                                onChanged: (value) => setState(() {
                                  _communeName = _clean(value);
                                }),
                              ),
                            ),
                          ],
                        );
                      },
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
                              child: _DateSelector(
                                value: _birthDate,
                                dark: dark,
                                fieldBg: fieldBg,
                                onTap: _pickBirthDate,
                                onClear: () => setState(() {
                                  _birthDate = null;
                                }),
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _GenderSelector(
                                value: _gender,
                                dark: dark,
                                fieldBg: fieldBg,
                                onChanged: (value) => setState(() {
                                  _gender = _clean(value);
                                }),
                              ),
                            ),
                          ],
                        );
                      },
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
                                controller: _heightController,
                                label: 'Chiều cao',
                                icon: Icons.height_outlined,
                                dark: dark,
                                fieldBg: fieldBg,
                                maxLength: 6,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                suffixText: 'cm',
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _EditTextField(
                                controller: _weightController,
                                label: 'Cân nặng',
                                icon: Icons.monitor_weight_outlined,
                                dark: dark,
                                fieldBg: fieldBg,
                                maxLength: 6,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                suffixText: 'kg',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _SkillEditor(
                      value: _skillLevel,
                      dark: dark,
                      onChanged: (value) => setState(() => _skillLevel = value),
                    ),
                    const SizedBox(height: 10),
                    _PlayPreferenceEditor(
                      playFrequency: _playFrequency,
                      preferredTimeSlot: _preferredTimeSlot,
                      dark: dark,
                      onFrequencyChanged: (value) => setState(() {
                        _playFrequency = value;
                      }),
                      onTimeSlotChanged: (value) => setState(() {
                        _preferredTimeSlot = value;
                      }),
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
  final TextInputType? keyboardType;
  final String? suffixText;

  const _EditTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.dark,
    required this.fieldBg,
    required this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.suffixText,
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
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 13, color: primary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: secondary),
        prefixIcon: Icon(icon, size: 19, color: const Color(0xFF22C55E)),
        suffixText: suffixText,
        suffixStyle: TextStyle(fontSize: 12, color: secondary),
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

class _ProvinceSelector extends StatelessWidget {
  final String? value;
  final List<AdministrativeProvince> provinces;
  final bool loading;
  final bool dark;
  final Color fieldBg;
  final ValueChanged<String?> onChanged;

  const _ProvinceSelector({
    required this.value,
    required this.provinces,
    required this.loading,
    required this.dark,
    required this.fieldBg,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = <String>{
      if (_clean(value) != null) value!,
      for (final province in provinces) province.name,
    }.toList();

    return _LocationDropdown(
      key: ValueKey('province-${value ?? ''}-$loading'),
      value: _clean(value),
      label: 'Tỉnh/Thành phố',
      hint: loading ? 'Đang tải tỉnh/thành...' : 'Chọn tỉnh/thành',
      icon: Icons.location_city_outlined,
      options: options,
      loading: loading,
      dark: dark,
      fieldBg: fieldBg,
      onChanged: loading ? null : onChanged,
    );
  }
}

class _WardSelector extends StatelessWidget {
  final String? value;
  final List<AdministrativeWard> wards;
  final bool provinceSelected;
  final bool loading;
  final bool dark;
  final Color fieldBg;
  final ValueChanged<String?> onChanged;

  const _WardSelector({
    required this.value,
    required this.wards,
    required this.provinceSelected,
    required this.loading,
    required this.dark,
    required this.fieldBg,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = <String>{
      if (_clean(value) != null) value!,
      for (final ward in wards) ward.name,
    }.toList();
    final disabled = !provinceSelected || loading || options.isEmpty;

    return _LocationDropdown(
      key: ValueKey('ward-${value ?? ''}-$loading-${wards.length}'),
      value: _clean(value),
      label: 'Xã/Phường',
      hint: !provinceSelected
          ? 'Chọn tỉnh/thành trước'
          : loading
              ? 'Đang tải xã/phường...'
              : 'Chọn xã/phường',
      icon: Icons.place_outlined,
      options: options,
      loading: loading,
      dark: dark,
      fieldBg: fieldBg,
      onChanged: disabled ? null : onChanged,
    );
  }
}

class _LocationDropdown extends StatelessWidget {
  final String? value;
  final String label;
  final String hint;
  final IconData icon;
  final List<String> options;
  final bool loading;
  final bool dark;
  final Color fieldBg;
  final ValueChanged<String?>? onChanged;

  const _LocationDropdown({
    super.key,
    required this.value,
    required this.label,
    required this.hint,
    required this.icon,
    required this.options,
    required this.loading,
    required this.dark,
    required this.fieldBg,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = dark ? Colors.white : const Color(0xFF111827);
    final secondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final current = options.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      initialValue: current,
      isExpanded: true,
      dropdownColor: dark ? const Color(0xFF1F2937) : Colors.white,
      style: TextStyle(fontSize: 13, color: primary),
      iconEnabledColor: secondary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: secondary),
        prefixIcon: loading
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF22C55E),
                  ),
                ),
              )
            : Icon(icon, size: 19, color: const Color(0xFF22C55E)),
        filled: true,
        fillColor: fieldBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF22C55E), width: 1.4),
        ),
      ),
      hint: Text(
        hint,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: secondary),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: '',
          child: Text('Chưa cập nhật'),
        ),
        for (final option in options)
          DropdownMenuItem<String>(
            value: option,
            child: Text(
              option,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _DateSelector extends StatelessWidget {
  final DateTime? value;
  final bool dark;
  final Color fieldBg;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateSelector({
    required this.value,
    required this.dark,
    required this.fieldBg,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final primary = dark ? Colors.white : const Color(0xFF111827);
    final secondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final hasValue = value != null;

    return Material(
      color: fieldBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: EdgeInsets.fromLTRB(12, 8, hasValue ? 4 : 12, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.cake_outlined,
                size: 19,
                color: Color(0xFF22C55E),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ngày sinh',
                      style: TextStyle(fontSize: 12, color: secondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasValue ? _formatDate(value) : 'Chưa cập nhật',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: primary),
                    ),
                  ],
                ),
              ),
              if (hasValue)
                IconButton(
                  onPressed: onClear,
                  icon: Icon(Icons.close, size: 16, color: secondary),
                  tooltip: 'Xóa ngày sinh',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderSelector extends StatelessWidget {
  final String? value;
  final bool dark;
  final Color fieldBg;
  final ValueChanged<String?> onChanged;

  const _GenderSelector({
    required this.value,
    required this.dark,
    required this.fieldBg,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = dark ? Colors.white : const Color(0xFF111827);
    final secondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final current = _clean(value);
    final options = <String>{
      if (current != null) current,
      'Nam',
      'Nữ',
      'Khác',
    }.toList();

    return DropdownButtonFormField<String>(
      key: ValueKey(current ?? ''),
      initialValue: current,
      isExpanded: true,
      dropdownColor: dark ? const Color(0xFF1F2937) : Colors.white,
      style: TextStyle(fontSize: 13, color: primary),
      iconEnabledColor: secondary,
      decoration: InputDecoration(
        labelText: 'Giới tính',
        labelStyle: TextStyle(fontSize: 12, color: secondary),
        prefixIcon: const Icon(
          Icons.wc_outlined,
          size: 19,
          color: Color(0xFF22C55E),
        ),
        filled: true,
        fillColor: fieldBg,
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
      hint: Text(
        'Chưa cập nhật',
        style: TextStyle(fontSize: 13, color: secondary),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: '',
          child: Text('Chưa cập nhật'),
        ),
        for (final option in options)
          DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          ),
      ],
      onChanged: onChanged,
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

String? _locationLabel(UserProfile profile) {
  final commune = _clean(profile.commune);
  final city = _clean(profile.city);
  if (commune == null) return city;
  if (city == null) return commune;
  return '$commune, $city';
}

String _choiceTitle(
  String? value,
  List<_ProfileChoiceOption> options,
  String fallback,
) {
  final selected = _findChoice(value, options);
  return selected?.title ?? _clean(value) ?? fallback;
}

String? _normalizeChoiceValue(
  String? value,
  List<_ProfileChoiceOption> options,
) {
  final selected = _findChoice(value, options);
  return selected?.value ?? _clean(value);
}

_ProfileChoiceOption? _findChoice(
  String? value,
  List<_ProfileChoiceOption> options,
) {
  final cleaned = _clean(value);
  if (cleaned == null) return null;

  for (final option in options) {
    if (option.value == cleaned || option.title == cleaned) {
      return option;
    }
  }

  return null;
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

String _formatDate(DateTime? value) {
  if (value == null) return 'Chưa cập nhật';
  final local = value.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year}';
}

String _measurementLabel(double? value, String unit, String fallback) {
  if (value == null) return fallback;
  return '${_compactNumber(value)} $unit';
}

String _numberInputText(double? value) {
  if (value == null) return '';
  return _compactNumber(value);
}

double? _parseOptionalMeasurement(
  String value,
  String fieldName,
  double min,
  double max,
  String unit,
) {
  final cleaned = _clean(value);
  if (cleaned == null) return null;

  final parsed = double.tryParse(cleaned.replaceAll(',', '.'));
  if (parsed == null) {
    throw FormatException('$fieldName phải là số hợp lệ.');
  }

  if (parsed < min || parsed > max) {
    throw FormatException(
      '$fieldName phải nằm trong khoảng '
      '${_compactNumber(min)} đến ${_compactNumber(max)} $unit.',
    );
  }

  return parsed;
}

String _compactNumber(num value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(1);
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
