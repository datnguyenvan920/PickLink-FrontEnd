import 'package:flutter/material.dart';

import '../services/auth_api.dart';
import '../services/community_api.dart';
import '../widgets/share_bottom_sheet.dart';

class SocialScreen extends StatefulWidget {
  final bool isDarkMode;
  final AuthSession? authSession;

  const SocialScreen({
    super.key,
    required this.isDarkMode,
    required this.authSession,
  });

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _api = CommunityApi();
  final _postController = TextEditingController();
  final _searchController = TextEditingController();

  bool _isCommunity = true;
  bool _loadingGroups = false;
  bool _loadingPosts = false;
  bool _submitting = false;
  String? _error;
  List<CommunityGroup> _groups = const [];
  List<CommunityPost> _posts = const [];
  CommunityGroup? _selectedGroup;

  String? get _token => widget.authSession?.token;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void didUpdateWidget(covariant SocialScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authSession?.token != widget.authSession?.token) {
      _loadGroups();
    }
  }

  @override
  void dispose() {
    _postController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups({bool keepSelection = true}) async {
    final token = _token;
    if (token == null) {
      return;
    }

    setState(() {
      _loadingGroups = true;
      _error = null;
    });

    try {
      final groups = await _api.groups(
        token: token,
        query: _searchController.text,
      );
      if (!mounted) return;

      final selected = keepSelection
          ? _findGroup(groups, _selectedGroup?.groupId) ?? _firstOrNull(groups)
          : _firstOrNull(groups);

      setState(() {
        _groups = groups;
        _selectedGroup = selected;
        _loadingGroups = false;
        if (selected == null || !selected.canViewContent) {
          _posts = const [];
        }
      });

      if (selected != null && selected.canViewContent) {
        await _loadPosts(selected);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingGroups = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadPosts(CommunityGroup group) async {
    final token = _token;
    if (token == null || !group.canViewContent) {
      return;
    }

    setState(() {
      _loadingPosts = true;
    });

    try {
      final posts = await _api.posts(token: token, groupId: group.groupId);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loadingPosts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingPosts = false;
        _error = error.toString();
      });
    }
  }

  void _selectGroup(CommunityGroup group) {
    setState(() {
      _selectedGroup = group;
      _posts = const [];
    });

    if (group.canViewContent) {
      _loadPosts(group);
    }
  }

  Future<void> _showCreateGroupDialog() async {
    final token = _token;
    if (token == null) return;

    final result = await showDialog<_GroupFormResult>(
      context: context,
      builder: (_) => _GroupEditorDialog(dark: widget.isDarkMode),
    );
    if (result == null) return;

    setState(() => _submitting = true);
    try {
      final group = await _api.createGroup(
        token: token,
        groupName: result.name,
        description: result.description,
        groupType: result.groupType,
        coverImageUrl: result.coverImageUrl,
      );
      if (!mounted) return;
      _applyGroup(group, insertFirst: true);
      await _loadPosts(group);
    } catch (error) {
      _showSnack(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showEditGroupDialog(CommunityGroup group) async {
    final token = _token;
    if (token == null) return;

    final result = await showDialog<_GroupFormResult>(
      context: context,
      builder: (_) => _GroupEditorDialog(
        dark: widget.isDarkMode,
        initialGroup: group,
      ),
    );
    if (result == null) return;

    setState(() => _submitting = true);
    try {
      final updated = await _api.updateGroup(
        token: token,
        groupId: group.groupId,
        groupName: result.name,
        description: result.description,
        groupType: result.groupType,
        coverImageUrl: result.coverImageUrl,
      );
      if (!mounted) return;
      _applyGroup(updated);
    } catch (error) {
      _showSnack(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleJoinOrLeave(CommunityGroup group) async {
    final token = _token;
    if (token == null || group.isPending) return;

    setState(() => _submitting = true);
    try {
      final updated = group.isMember
          ? await _api.leaveGroup(token: token, groupId: group.groupId)
          : await _api.joinGroup(token: token, groupId: group.groupId);
      if (!mounted) return;
      _applyGroup(updated);
      if (updated.canViewContent) {
        await _loadPosts(updated);
      } else {
        setState(() => _posts = const []);
      }
    } catch (error) {
      _showSnack(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _createPost() async {
    final token = _token;
    final group = _selectedGroup;
    final content = _postController.text.trim();
    if (token == null || group == null || content.isEmpty || !group.isMember) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final post = await _api.createPost(
        token: token,
        groupId: group.groupId,
        content: content,
      );
      if (!mounted) return;
      _postController.clear();
      setState(() {
        _posts = [post, ..._posts];
      });
      _applyGroup(group.copyWith(postCount: group.postCount + 1));
    } catch (error) {
      _showSnack(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _toggleReaction(CommunityPost post) async {
    final token = _token;
    if (token == null) return;

    try {
      final updated = post.likedByMe
          ? await _api.removeReaction(token: token, postId: post.postId)
          : await _api.reactToPost(token: token, postId: post.postId);
      if (!mounted) return;
      _replacePost(updated);
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  Future<void> _openComments(CommunityPost post) async {
    final token = _token;
    if (token == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommunityCommentsSheet(
        api: _api,
        token: token,
        post: post,
        dark: widget.isDarkMode,
      ),
    );

    final group = _selectedGroup;
    if (mounted && group != null && group.canViewContent) {
      await _loadPosts(group);
    }
  }

  Future<void> _openChat(CommunityGroup group) async {
    final token = _token;
    if (token == null || !group.isMember) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommunityChatSheet(
        api: _api,
        token: token,
        group: group,
        dark: widget.isDarkMode,
      ),
    );

    if (mounted) {
      await _loadGroups();
    }
  }

  Future<void> _openMembers(CommunityGroup group) async {
    final token = _token;
    if (token == null || !group.canViewContent) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommunityMembersSheet(
        api: _api,
        token: token,
        group: group,
        currentUserId: widget.authSession?.user.userId,
        dark: widget.isDarkMode,
      ),
    );

    if (mounted) {
      await _loadGroups();
    }
  }

  void _openShare() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareBottomSheet(isDarkMode: widget.isDarkMode),
    );
  }

  void _replacePost(CommunityPost post) {
    setState(() {
      _posts = _posts
          .map((existing) => existing.postId == post.postId ? post : existing)
          .toList();
    });
  }

  void _applyGroup(CommunityGroup group, {bool insertFirst = false}) {
    final index = _groups.indexWhere((item) => item.groupId == group.groupId);
    final groups = [..._groups];
    if (index == -1) {
      if (insertFirst) {
        groups.insert(0, group);
      } else {
        groups.add(group);
      }
    } else {
      groups[index] = group;
    }

    setState(() {
      _groups = groups;
      _selectedGroup = group;
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDarkMode;
    final bg = dark ? const Color(0xFF1F2937) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: bg,
            border: Border(bottom: BorderSide(color: border)),
          ),
          child: Row(
            children: [
              _TabBtn(
                label: 'Community',
                isActive: _isCommunity,
                onTap: () => setState(() => _isCommunity = true),
                dark: dark,
              ),
              _TabBtn(
                label: 'Marketplace',
                isActive: !_isCommunity,
                onTap: () => setState(() => _isCommunity = false),
                dark: dark,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isCommunity
              ? _buildCommunity(dark)
              : _MarketplaceTab(dark: dark),
        ),
      ],
    );
  }

  Widget _buildCommunity(bool dark) {
    if (_token == null) {
      return _CenteredState(
        dark: dark,
        icon: Icons.lock_outline,
        title: 'Sign in required',
        message: 'Please sign in to join groups and community chats.',
      );
    }

    if (_loadingGroups && _groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _groups.isEmpty) {
      return _CenteredState(
        dark: dark,
        icon: Icons.wifi_off_outlined,
        title: 'Community unavailable',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _loadGroups,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;

        if (desktop) {
          return Row(
            children: [
              SizedBox(
                width: 330,
                child: _GroupRail(
                  dark: dark,
                  groups: _groups,
                  selectedGroup: _selectedGroup,
                  searchController: _searchController,
                  loading: _loadingGroups,
                  onSearch: () => _loadGroups(keepSelection: false),
                  onCreateGroup: _showCreateGroupDialog,
                  onGroupSelected: _selectGroup,
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
              ),
              Expanded(child: _buildGroupDetail(dark)),
            ],
          );
        }

        return Column(
          children: [
            SizedBox(
              height: 182,
              child: _GroupRail(
                dark: dark,
                compact: true,
                groups: _groups,
                selectedGroup: _selectedGroup,
                searchController: _searchController,
                loading: _loadingGroups,
                onSearch: () => _loadGroups(keepSelection: false),
                onCreateGroup: _showCreateGroupDialog,
                onGroupSelected: _selectGroup,
              ),
            ),
            Divider(
              height: 1,
              color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
            Expanded(child: _buildGroupDetail(dark)),
          ],
        );
      },
    );
  }

  Widget _buildGroupDetail(bool dark) {
    return _GroupDetail(
      dark: dark,
      group: _selectedGroup,
      posts: _posts,
      loadingPosts: _loadingPosts,
      submitting: _submitting,
      postController: _postController,
      onCreatePost: _createPost,
      onJoinOrLeave: _handleJoinOrLeave,
      onOpenChat: _openChat,
      onOpenMembers: _openMembers,
      onEditGroup: _showEditGroupDialog,
      onReact: _toggleReaction,
      onComment: _openComments,
      onShare: _openShare,
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool dark;

  const _TabBtn({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? const Color(0xFF22C55E) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isActive
                  ? const Color(0xFF22C55E)
                  : dark
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF4B5563),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupRail extends StatelessWidget {
  final bool dark;
  final bool compact;
  final bool loading;
  final List<CommunityGroup> groups;
  final CommunityGroup? selectedGroup;
  final TextEditingController searchController;
  final VoidCallback onSearch;
  final VoidCallback onCreateGroup;
  final ValueChanged<CommunityGroup> onGroupSelected;

  const _GroupRail({
    required this.dark,
    this.compact = false,
    required this.loading,
    required this.groups,
    required this.selectedGroup,
    required this.searchController,
    required this.onSearch,
    required this.onCreateGroup,
    required this.onGroupSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1F2937) : Colors.white;
    final inputBg = dark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    final text = dark ? Colors.white : const Color(0xFF111827);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              onSubmitted: (_) => onSearch(),
              style: TextStyle(fontSize: 13, color: text),
              decoration: InputDecoration(
                hintText: 'Search groups',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                ),
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onCreateGroup,
            icon: const Icon(Icons.add, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (compact) {
      return ColoredBox(
        color: bg,
        child: Column(
          children: [
            header,
            Expanded(
              child: loading
                  ? const Center(child: LinearProgressIndicator())
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      itemBuilder: (_, index) {
                        final group = groups[index];
                        return SizedBox(
                          width: 245,
                          child: _GroupTile(
                            dark: dark,
                            compact: true,
                            group: group,
                            selected: selectedGroup?.groupId == group.groupId,
                            onTap: () => onGroupSelected(group),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemCount: groups.length,
                    ),
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  'Groups',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: dark
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF374151),
                  ),
                ),
                const Spacer(),
                if (loading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Expanded(
            child: groups.isEmpty
                ? _MiniEmptyState(dark: dark, message: 'No groups yet.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                    itemBuilder: (_, index) {
                      final group = groups[index];
                      return _GroupTile(
                        dark: dark,
                        group: group,
                        selected: selectedGroup?.groupId == group.groupId,
                        onTap: () => onGroupSelected(group),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: groups.length,
                  ),
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final bool dark;
  final bool compact;
  final CommunityGroup group;
  final bool selected;
  final VoidCallback onTap;

  const _GroupTile({
    required this.dark,
    this.compact = false,
    required this.group,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? const Color(0xFF22C55E)
        : dark
            ? const Color(0xFF374151)
            : const Color(0xFFE5E7EB);
    final bg = selected
        ? const Color(0xFF22C55E).withValues(alpha: dark ? 0.16 : 0.10)
        : dark
            ? const Color(0xFF111827)
            : Colors.white;
    final text = dark ? Colors.white : const Color(0xFF111827);
    final muted = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              _GroupAvatar(group: group, size: compact ? 42 : 46),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.groupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _SmallPill(
                          label: group.groupType,
                          color: group.isPrivate
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF22C55E),
                        ),
                        if (group.isPending)
                          const _SmallPill(
                            label: 'Pending',
                            color: Color(0xFFF97316),
                          ),
                        if (group.isMember)
                          const _SmallPill(
                            label: 'Joined',
                            color: Color(0xFF3B82F6),
                          ),
                      ],
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${group.memberCount} members · ${group.postCount} posts',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
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

class _GroupDetail extends StatelessWidget {
  final bool dark;
  final CommunityGroup? group;
  final List<CommunityPost> posts;
  final bool loadingPosts;
  final bool submitting;
  final TextEditingController postController;
  final VoidCallback onCreatePost;
  final ValueChanged<CommunityGroup> onJoinOrLeave;
  final ValueChanged<CommunityGroup> onOpenChat;
  final ValueChanged<CommunityGroup> onOpenMembers;
  final ValueChanged<CommunityGroup> onEditGroup;
  final ValueChanged<CommunityPost> onReact;
  final ValueChanged<CommunityPost> onComment;
  final VoidCallback onShare;

  const _GroupDetail({
    required this.dark,
    required this.group,
    required this.posts,
    required this.loadingPosts,
    required this.submitting,
    required this.postController,
    required this.onCreatePost,
    required this.onJoinOrLeave,
    required this.onOpenChat,
    required this.onOpenMembers,
    required this.onEditGroup,
    required this.onReact,
    required this.onComment,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final selected = group;
    if (selected == null) {
      return _CenteredState(
        dark: dark,
        icon: Icons.groups_2_outlined,
        title: 'No group selected',
        message: 'Create or choose a group to start posting.',
      );
    }

    final bg = dark ? const Color(0xFF1F2937) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return ColoredBox(
      color: bg,
      child: Column(
        children: [
          _GroupHeader(
            dark: dark,
            group: selected,
            submitting: submitting,
            onJoinOrLeave: () => onJoinOrLeave(selected),
            onOpenChat: selected.isMember ? () => onOpenChat(selected) : null,
            onOpenMembers:
                selected.canViewContent ? () => onOpenMembers(selected) : null,
            onEditGroup:
                selected.canManage ? () => onEditGroup(selected) : null,
          ),
          Divider(height: 1, color: border),
          if (selected.isMember)
            _PostComposer(
              dark: dark,
              controller: postController,
              submitting: submitting,
              onSubmit: onCreatePost,
            )
          else
            _AccessPanel(dark: dark, group: selected),
          Expanded(
            child: _PostList(
              dark: dark,
              group: selected,
              posts: posts,
              loading: loadingPosts,
              onReact: onReact,
              onComment: onComment,
              onShare: onShare,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final bool dark;
  final CommunityGroup group;
  final bool submitting;
  final VoidCallback onJoinOrLeave;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenMembers;
  final VoidCallback? onEditGroup;

  const _GroupHeader({
    required this.dark,
    required this.group,
    required this.submitting,
    required this.onJoinOrLeave,
    required this.onOpenChat,
    required this.onOpenMembers,
    required this.onEditGroup,
  });

  @override
  Widget build(BuildContext context) {
    final text = dark ? Colors.white : const Color(0xFF111827);
    final muted = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GroupAvatar(group: group, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.groupName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      group.description?.trim().isNotEmpty == true
                          ? group.description!
                          : 'A place for players to post, chat, and organize.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12, height: 1.35, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _InfoChip(
                icon: group.isPrivate ? Icons.lock_outline : Icons.public,
                label: group.groupType,
                dark: dark,
              ),
              _InfoChip(
                icon: Icons.people_outline,
                label: '${group.memberCount} members',
                dark: dark,
              ),
              _InfoChip(
                icon: Icons.article_outlined,
                label: '${group.postCount} posts',
                dark: dark,
              ),
              _InfoChip(
                icon: Icons.chat_bubble_outline,
                label: '${group.messageCount} messages',
                dark: dark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!group.isMember)
                ElevatedButton.icon(
                  onPressed:
                      group.isPending || submitting ? null : onJoinOrLeave,
                  icon: Icon(
                    group.isPending
                        ? Icons.hourglass_top
                        : Icons.group_add_outlined,
                    size: 17,
                  ),
                  label: Text(group.isPending ? 'Pending' : 'Join'),
                  style: _primaryButtonStyle(),
                )
              else ...[
                ElevatedButton.icon(
                  onPressed: onOpenChat,
                  icon: const Icon(Icons.forum_outlined, size: 17),
                  label: const Text('Chat'),
                  style: _primaryButtonStyle(),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenMembers,
                  icon: const Icon(Icons.people_outline, size: 17),
                  label: const Text('Members'),
                ),
                if (onEditGroup != null)
                  IconButton.outlined(
                    onPressed: onEditGroup,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    tooltip: 'Group settings',
                  ),
                OutlinedButton.icon(
                  onPressed: submitting ? null : onJoinOrLeave,
                  icon: const Icon(Icons.logout, size: 17),
                  label: const Text('Leave'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PostComposer extends StatelessWidget {
  final bool dark;
  final bool submitting;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const _PostComposer({
    required this.dark,
    required this.submitting,
    required this.controller,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final inputBg = dark ? const Color(0xFF374151) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final text = dark ? Colors.white : const Color(0xFF111827);

    return Container(
      padding: const EdgeInsets.all(14),
      color: bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _InitialAvatar(name: 'You', size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              style: TextStyle(fontSize: 13, color: text),
              decoration: InputDecoration(
                hintText: 'Share an update with this group',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                ),
                filled: true,
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: border),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: submitting ? null : onSubmit,
            icon: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessPanel extends StatelessWidget {
  final bool dark;
  final CommunityGroup group;

  const _AccessPanel({required this.dark, required this.group});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final text = dark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563);
    final message = group.isPending
        ? 'Your request is waiting for approval.'
        : group.isPrivate
            ? 'Join this private group to see posts and chat.'
            : 'Join this group to post and chat with members.';

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          Icon(
            group.isPending ? Icons.hourglass_top : Icons.lock_open_outlined,
            color: const Color(0xFF22C55E),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: text),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostList extends StatelessWidget {
  final bool dark;
  final CommunityGroup group;
  final List<CommunityPost> posts;
  final bool loading;
  final ValueChanged<CommunityPost> onReact;
  final ValueChanged<CommunityPost> onComment;
  final VoidCallback onShare;

  const _PostList({
    required this.dark,
    required this.group,
    required this.posts,
    required this.loading,
    required this.onReact,
    required this.onComment,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    if (!group.canViewContent) {
      return const SizedBox.shrink();
    }

    if (loading && posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty) {
      return _CenteredState(
        dark: dark,
        icon: Icons.article_outlined,
        title: 'No posts yet',
        message: group.isMember
            ? 'Start the first conversation in this group.'
            : 'Join the group to start posting.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final post = posts[index];
        return _PostCard(
          dark: dark,
          post: post,
          onReact: () => onReact(post),
          onComment: () => onComment(post),
          onShare: onShare,
        );
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  final bool dark;
  final CommunityPost post;
  final VoidCallback onReact;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const _PostCard({
    required this.dark,
    required this.post,
    required this.onReact,
    required this.onComment,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final card = dark ? const Color(0xFF111827) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final text = dark ? Colors.white : const Color(0xFF111827);
    final body = dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    final muted = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                _InitialAvatar(
                  name: post.authorName,
                  imageUrl: post.authorAvatarUrl,
                  size: 40,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: text,
                        ),
                      ),
                      Text(
                        _relativeTime(post.createdAt),
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (post.content?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                post.content!,
                style: TextStyle(fontSize: 13, height: 1.45, color: body),
              ),
            ),
          if (post.mediaUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.mediaUrls.first,
                  height: 210,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: const Color(0xFF22C55E).withValues(alpha: 0.10),
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: border),
                  bottom: BorderSide(color: border),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${post.likeCount} likes',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                  const Spacer(),
                  Text(
                    '${post.commentCount} comments',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _PostActionButton(
                    icon:
                        post.likedByMe ? Icons.favorite : Icons.favorite_border,
                    label: 'Like',
                    color: post.likedByMe ? const Color(0xFFEF4444) : muted,
                    onTap: onReact,
                  ),
                ),
                Expanded(
                  child: _PostActionButton(
                    icon: Icons.chat_bubble_outline,
                    label: 'Comment',
                    color: muted,
                    onTap: onComment,
                  ),
                ),
                Expanded(
                  child: _PostActionButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    color: muted,
                    onTap: onShare,
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

class _PostActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PostActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      ),
    );
  }
}

class _CommunityCommentsSheet extends StatefulWidget {
  final CommunityApi api;
  final String token;
  final CommunityPost post;
  final bool dark;

  const _CommunityCommentsSheet({
    required this.api,
    required this.token,
    required this.post,
    required this.dark,
  });

  @override
  State<_CommunityCommentsSheet> createState() =>
      _CommunityCommentsSheetState();
}

class _CommunityCommentsSheetState extends State<_CommunityCommentsSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<CommunityComment> _comments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final comments = await widget.api.comments(
        token: widget.token,
        postId: widget.post.postId,
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final comment = await widget.api.createComment(
        token: widget.token,
        postId: widget.post.postId,
        content: content,
      );
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _comments = [..._comments, comment];
      });
      Future.delayed(const Duration(milliseconds: 80), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final bg = dark ? const Color(0xFF1F2937) : Colors.white;
    final header = dark ? const Color(0xFF111827) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final text = dark ? Colors.white : const Color(0xFF111827);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              decoration: BoxDecoration(
                color: header,
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: text,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _CenteredState(
                          dark: dark,
                          icon: Icons.error_outline,
                          title: 'Could not load comments',
                          message: _error!,
                          actionLabel: 'Retry',
                          onAction: _load,
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (_, index) => _CommentTile(
                            dark: dark,
                            comment: _comments[index],
                          ),
                        ),
            ),
            _SheetInput(
              dark: dark,
              controller: _controller,
              hintText: 'Write a comment',
              sending: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityChatSheet extends StatefulWidget {
  final CommunityApi api;
  final String token;
  final CommunityGroup group;
  final bool dark;

  const _CommunityChatSheet({
    required this.api,
    required this.token,
    required this.group,
    required this.dark,
  });

  @override
  State<_CommunityChatSheet> createState() => _CommunityChatSheetState();
}

class _CommunityChatSheetState extends State<_CommunityChatSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<CommunityMessage> _messages = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final messages = await widget.api.messages(
        token: widget.token,
        groupId: widget.group.groupId,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final message = await widget.api.sendMessage(
        token: widget.token,
        groupId: widget.group.groupId,
        content: content,
      );
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _messages = [..._messages, message];
      });
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final bg = dark ? const Color(0xFF1F2937) : Colors.white;
    final header = dark ? const Color(0xFF111827) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final text = dark ? Colors.white : const Color(0xFF111827);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.84,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              decoration: BoxDecoration(
                color: header,
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  _GroupAvatar(group: widget.group, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: text,
                          ),
                        ),
                        Text(
                          '${widget.group.memberCount} members',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _CenteredState(
                          dark: dark,
                          icon: Icons.error_outline,
                          title: 'Could not load chat',
                          message: _error!,
                          actionLabel: 'Retry',
                          onAction: _load,
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (_, index) => _MessageBubble(
                            dark: dark,
                            message: _messages[index],
                          ),
                        ),
            ),
            _SheetInput(
              dark: dark,
              controller: _controller,
              hintText: 'Message this group',
              sending: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityMembersSheet extends StatefulWidget {
  final CommunityApi api;
  final String token;
  final CommunityGroup group;
  final int? currentUserId;
  final bool dark;

  const _CommunityMembersSheet({
    required this.api,
    required this.token,
    required this.group,
    required this.currentUserId,
    required this.dark,
  });

  @override
  State<_CommunityMembersSheet> createState() => _CommunityMembersSheetState();
}

class _CommunityMembersSheetState extends State<_CommunityMembersSheet> {
  bool _loading = true;
  bool _working = false;
  String? _error;
  List<CommunityMember> _members = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final members = await widget.api.members(
        token: widget.token,
        groupId: widget.group.groupId,
      );
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _approve(CommunityMember member) async {
    setState(() => _working = true);
    try {
      await widget.api.approveMember(
        token: widget.token,
        groupId: widget.group.groupId,
        memberUserId: member.userId,
      );
      await _load();
    } catch (error) {
      _showSnack(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _remove(CommunityMember member) async {
    setState(() => _working = true);
    try {
      await widget.api.removeMember(
        token: widget.token,
        groupId: widget.group.groupId,
        memberUserId: member.userId,
      );
      if (member.userId == widget.currentUserId && mounted) {
        Navigator.pop(context);
        return;
      }
      await _load();
    } catch (error) {
      _showSnack(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final bg = dark ? const Color(0xFF1F2937) : Colors.white;
    final header = dark ? const Color(0xFF111827) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final text = dark ? Colors.white : const Color(0xFF111827);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              decoration: BoxDecoration(
                color: header,
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Members',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: text,
                      ),
                    ),
                  ),
                  if (_working)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _CenteredState(
                          dark: dark,
                          icon: Icons.error_outline,
                          title: 'Could not load members',
                          message: _error!,
                          actionLabel: 'Retry',
                          onAction: _load,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _members.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final member = _members[index];
                            return _MemberTile(
                              dark: dark,
                              member: member,
                              canManage: widget.group.canManage,
                              isCurrentUser:
                                  member.userId == widget.currentUserId,
                              working: _working,
                              onApprove: () => _approve(member),
                              onRemove: () => _remove(member),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final bool dark;
  final CommunityMember member;
  final bool canManage;
  final bool isCurrentUser;
  final bool working;
  final VoidCallback onApprove;
  final VoidCallback onRemove;

  const _MemberTile({
    required this.dark,
    required this.member,
    required this.canManage,
    required this.isCurrentUser,
    required this.working,
    required this.onApprove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final card = dark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final text = dark ? Colors.white : const Color(0xFF111827);
    final muted = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _InitialAvatar(
            name: member.username,
            imageUrl: member.profileImageUrl,
            size: 42,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? '${member.username} (You)' : member.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${member.role} · ${member.status}',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          if (canManage && member.isPending)
            IconButton.filledTonal(
              onPressed: working ? null : onApprove,
              icon: const Icon(Icons.check, size: 18),
              tooltip: 'Approve',
            ),
          if (canManage && !member.isOwner)
            IconButton(
              onPressed: working ? null : onRemove,
              icon: const Icon(Icons.person_remove_outlined, size: 18),
              tooltip: 'Remove',
            ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final bool dark;
  final CommunityComment comment;

  const _CommentTile({required this.dark, required this.comment});

  @override
  Widget build(BuildContext context) {
    final bubble = dark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    final text = dark ? Colors.white : const Color(0xFF111827);
    final body = dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    final muted = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InitialAvatar(
          name: comment.username,
          imageUrl: comment.userAvatarUrl,
          size: 34,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: bubble,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.username,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      comment.content,
                      style: TextStyle(fontSize: 13, height: 1.35, color: body),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _relativeTime(comment.createdAt),
                style: TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final bool dark;
  final CommunityMessage message;

  const _MessageBubble({required this.dark, required this.message});

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final bubble = mine
        ? const Color(0xFF22C55E)
        : dark
            ? const Color(0xFF374151)
            : const Color(0xFFE5E7EB);
    final text = mine || dark ? Colors.white : const Color(0xFF111827);
    final muted = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!mine)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 3),
                  child: Text(
                    message.senderName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: bubble,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(mine ? 16 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 16),
                  ),
                ),
                child: Text(
                  message.content ?? '',
                  style: TextStyle(fontSize: 13, height: 1.35, color: text),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _timeOnly(message.sentAt),
                style: TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetInput extends StatelessWidget {
  final bool dark;
  final TextEditingController controller;
  final String hintText;
  final bool sending;
  final VoidCallback onSend;

  const _SheetInput({
    required this.dark,
    required this.controller,
    required this.hintText,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF111827) : Colors.white;
    final inputBg = dark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final text = dark ? Colors.white : const Color(0xFF111827);

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              minLines: 1,
              maxLines: 4,
              style: TextStyle(fontSize: 13, color: text),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                ),
                filled: true,
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupEditorDialog extends StatefulWidget {
  final bool dark;
  final CommunityGroup? initialGroup;

  const _GroupEditorDialog({
    required this.dark,
    this.initialGroup,
  });

  @override
  State<_GroupEditorDialog> createState() => _GroupEditorDialogState();
}

class _GroupEditorDialogState extends State<_GroupEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _coverController;
  late String _type;

  @override
  void initState() {
    super.initState();
    final group = widget.initialGroup;
    _nameController = TextEditingController(text: group?.groupName ?? '');
    _descriptionController =
        TextEditingController(text: group?.description ?? '');
    _coverController = TextEditingController(text: group?.coverImageUrl ?? '');
    _type = group?.groupType == 'Private' ? 'Private' : 'Public';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _coverController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    Navigator.pop(
      context,
      _GroupFormResult(
        name: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        groupType: _type,
        coverImageUrl: _coverController.text.trim().isEmpty
            ? null
            : _coverController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final text = dark ? Colors.white : const Color(0xFF111827);

    return AlertDialog(
      title: Text(
        widget.initialGroup == null ? 'Create group' : 'Edit group',
        style: TextStyle(color: text, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Group name'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              minLines: 2,
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _coverController,
              decoration: const InputDecoration(labelText: 'Cover image URL'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'Public',
                  label: Text('Public'),
                  icon: Icon(Icons.public),
                ),
                ButtonSegment(
                  value: 'Private',
                  label: Text('Private'),
                  icon: Icon(Icons.lock_outline),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() => _type = selection.first);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: _primaryButtonStyle(),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _GroupFormResult {
  final String name;
  final String? description;
  final String groupType;
  final String? coverImageUrl;

  const _GroupFormResult({
    required this.name,
    required this.description,
    required this.groupType,
    required this.coverImageUrl,
  });
}

class _MarketplaceTab extends StatelessWidget {
  final bool dark;

  const _MarketplaceTab({required this.dark});

  static const _products = [
    _Product(
      name: 'Pickleball paddle',
      seller: 'Court Masters',
      price: 65,
      icon: Icons.sports_tennis,
    ),
    _Product(
      name: 'Training balls',
      seller: 'SportGear Pro',
      price: 18,
      icon: Icons.sports_baseball,
    ),
    _Product(
      name: 'Court shoes',
      seller: 'Athletic Zone',
      price: 79,
      icon: Icons.directions_run,
    ),
    _Product(
      name: 'Grip tape pack',
      seller: 'Pickle Shop',
      price: 12,
      icon: Icons.inventory_2_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1F2937) : Colors.white;

    return ColoredBox(
      color: bg,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: _products.length,
        itemBuilder: (_, index) => _ProductCard(
          dark: dark,
          product: _products[index],
        ),
      ),
    );
  }
}

class _Product {
  final String name;
  final String seller;
  final double price;
  final IconData icon;

  const _Product({
    required this.name,
    required this.seller,
    required this.price,
    required this.icon,
  });
}

class _ProductCard extends StatelessWidget {
  final bool dark;
  final _Product product;

  const _ProductCard({required this.dark, required this.product});

  @override
  Widget build(BuildContext context) {
    final card = dark ? const Color(0xFF111827) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final text = dark ? Colors.white : const Color(0xFF111827);
    final muted = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFF22C55E).withValues(alpha: 0.12),
              child:
                  Icon(product.icon, size: 54, color: const Color(0xFF22C55E)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  product.seller,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${product.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF22C55E),
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

class _GroupAvatar extends StatelessWidget {
  final CommunityGroup group;
  final double size;

  const _GroupAvatar({required this.group, required this.size});

  @override
  Widget build(BuildContext context) {
    final imageUrl = group.coverImageUrl;
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.26),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.26),
        gradient: const LinearGradient(
          colors: [Color(0xFF4ADE80), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _initials(group.groupName),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;

  const _InitialAvatar({
    required this.name,
    this.imageUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
        ),
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.28,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool dark;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF22C55E)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CenteredState({
    required this.dark,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final text = dark ? Colors.white : const Color(0xFF111827);
    final muted = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: const Color(0xFF22C55E)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.35, color: muted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: onAction,
                style: _primaryButtonStyle(),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniEmptyState extends StatelessWidget {
  final bool dark;
  final String message;

  const _MiniEmptyState({required this.dark, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

ButtonStyle _primaryButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF22C55E),
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}

CommunityGroup? _findGroup(List<CommunityGroup> groups, int? groupId) {
  if (groupId == null) return null;
  for (final group in groups) {
    if (group.groupId == groupId) return group;
  }
  return null;
}

CommunityGroup? _firstOrNull(List<CommunityGroup> groups) {
  return groups.isEmpty ? null : groups.first;
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

String _relativeTime(DateTime? value) {
  if (value == null) return 'Just now';
  final diff = DateTime.now().difference(value.toLocal());
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${value.month}/${value.day}/${value.year}';
}

String _timeOnly(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}
