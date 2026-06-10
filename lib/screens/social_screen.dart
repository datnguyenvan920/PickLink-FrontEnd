import 'package:flutter/material.dart';
import '../widgets/chat_bottom_sheet.dart';
import '../widgets/comment_bottom_sheet.dart';
import '../widgets/share_bottom_sheet.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

class _ChatUser {
  final int id;
  final String name;
  final String avatar;
  final bool online;
  const _ChatUser({required this.id, required this.name, required this.avatar, required this.online});
}

class _Post {
  final int id;
  final String author;
  final String avatar;
  final String time;
  final String content;
  final String? imageUrl;
  final int likes;
  final int comments;
  final int shares;
  const _Post({required this.id, required this.author, required this.avatar, required this.time, required this.content, this.imageUrl, required this.likes, required this.comments, required this.shares});
}

class _Product {
  final int id;
  final String name;
  final double price;
  final String emoji;
  final String seller;
  final double rating;
  const _Product({required this.id, required this.name, required this.price, required this.emoji, required this.seller, required this.rating});
}

// ─── Social Screen ────────────────────────────────────────────────────────────

class SocialScreen extends StatefulWidget {
  final bool isDarkMode;
  const SocialScreen({super.key, required this.isDarkMode});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  bool _isCommunity = true;
  final Set<int> _likedPosts = {};
  final _postController = TextEditingController();
  final _searchController = TextEditingController();

  static const _chatUsers = [
    _ChatUser(id: 1, name: 'Sarah J.', avatar: 'SJ', online: true),
    _ChatUser(id: 2, name: 'Mike C.',  avatar: 'MC', online: true),
    _ChatUser(id: 3, name: 'Alex R.',  avatar: 'AR', online: false),
    _ChatUser(id: 4, name: 'Emma W.',  avatar: 'EW', online: true),
    _ChatUser(id: 5, name: 'David L.', avatar: 'DL', online: false),
    _ChatUser(id: 6, name: 'Lisa M.',  avatar: 'LM', online: true),
    _ChatUser(id: 7, name: 'Tom B.',   avatar: 'TB', online: false),
    _ChatUser(id: 8, name: 'Nina P.',  avatar: 'NP', online: true),
  ];

  static const _posts = [
    _Post(id: 1, author: 'Sarah Johnson', avatar: 'SJ', time: '2 hours ago',
      content: 'Just finished an amazing badminton match at Victory Sports Complex! Looking for more players. Who\'s in? 🏸',
      likes: 24, comments: 8, shares: 3),
    _Post(id: 2, author: 'Mike Chen', avatar: 'MC', time: '5 hours ago',
      content: 'Finally broke into Gold tier! The grind was real but totally worth it. Big shoutout to everyone! 💪⚽',
      likes: 45, comments: 12, shares: 5),
    _Post(id: 3, author: 'Alex Rodriguez', avatar: 'AR', time: '8 hours ago',
      content: 'Incredible sunset game at the beach volleyball court today! Nothing beats playing sports with this view. 🏐🌅',
      imageUrl: 'https://images.unsplash.com/photo-1612872087720-bb876e2e67d1?w=800&h=400&fit=crop',
      likes: 67, comments: 15, shares: 8),
  ];

  static const _products = [
    _Product(id: 1, name: 'Professional Badminton Racket', price: 45.99, emoji: '🏸', seller: 'SportGear Pro',    rating: 4.8),
    _Product(id: 2, name: 'Premium Football Size 5',       price: 32.50, emoji: '⚽', seller: 'Athletic Zone',    rating: 4.9),
    _Product(id: 3, name: 'Tennis Balls Set (6 pack)',     price: 18.99, emoji: '🎾', seller: 'Court Masters',    rating: 4.6),
    _Product(id: 4, name: 'Pickleball Paddle Pro',         price: 65.00, emoji: '🏓', seller: 'Pickle Paradise',  rating: 4.7),
  ];

  @override
  void dispose() {
    _postController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openChat(_ChatUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatBottomSheet(isDarkMode: widget.isDarkMode, otherUserName: user.name, otherUserAvatar: user.avatar, online: user.online),
    );
  }

  void _openComments(_Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentBottomSheet(isDarkMode: widget.isDarkMode, postAuthor: post.author),
    );
  }

  void _openShare() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareBottomSheet(isDarkMode: widget.isDarkMode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDarkMode;
    final bg = dark ? const Color(0xFF1F2937) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return Column(
      children: [
        // Tab Switcher
        Container(
          decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: border))),
          child: Row(
            children: [
              _TabBtn(label: 'Community',   isActive: _isCommunity,  onTap: () => setState(() => _isCommunity = true),  dark: dark),
              _TabBtn(label: 'Marketplace', isActive: !_isCommunity, onTap: () => setState(() => _isCommunity = false), dark: dark),
            ],
          ),
        ),
        Expanded(
          child: _isCommunity
              ? _CommunityTab(dark: dark, chatUsers: _chatUsers, posts: _posts, likedPosts: _likedPosts, controller: _postController,
                  onChatTap: _openChat, onLike: (id) => setState(() {
                    if (_likedPosts.contains(id)) { _likedPosts.remove(id); } else { _likedPosts.add(id); }
                  }),
                  onComment: _openComments, onShare: _openShare)
              : _MarketplaceTab(dark: dark, products: _products, searchController: _searchController,
                  onChat: (seller) => _openChat(_ChatUser(id: 99, name: seller, avatar: seller.substring(0, 2).toUpperCase(), online: true))),
        ),
      ],
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool dark;
  const _TabBtn({required this.label, required this.isActive, required this.onTap, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isActive ? const Color(0xFF22C55E) : Colors.transparent, width: 2)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: isActive ? const Color(0xFF22C55E) : dark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Community Tab ────────────────────────────────────────────────────────────

class _CommunityTab extends StatelessWidget {
  final bool dark;
  final List<_ChatUser> chatUsers;
  final List<_Post> posts;
  final Set<int> likedPosts;
  final TextEditingController controller;
  final ValueChanged<_ChatUser> onChatTap;
  final ValueChanged<int> onLike;
  final ValueChanged<_Post> onComment;
  final VoidCallback onShare;

  const _CommunityTab({
    required this.dark, required this.chatUsers, required this.posts,
    required this.likedPosts, required this.controller,
    required this.onChatTap, required this.onLike, required this.onComment, required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1F2937) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return ListView(
      physics: const ClampingScrollPhysics(),
      children: [
        // ── Chat Bubbles Row ──
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: border))),
          child: SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chatUsers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final user = chatUsers[i];
                return GestureDetector(
                  onTap: () => onChatTap(user),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF4ADE80), Color(0xFF059669)]),
                              shape: BoxShape.circle,
                              border: user.online ? Border.all(color: const Color(0xFF86EFAC), width: 2) : null,
                            ),
                            child: Center(child: Text(user.avatar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 12, height: 12,
                              decoration: BoxDecoration(
                                color: user.online ? const Color(0xFF22C55E) : const Color(0xFF9CA3AF),
                                shape: BoxShape.circle,
                                border: Border.all(color: bg, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      SizedBox(
                        width: 48,
                        child: Text(user.name, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 9, color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151))),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // ── Post Composer ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: border))),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4ADE80), Color(0xFF22C55E)]), shape: BoxShape.circle),
                    child: const Center(child: Text('YO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: TextStyle(fontSize: 13, color: dark ? Colors.white : const Color(0xFF111827)),
                      decoration: InputDecoration(
                        hintText: 'What\'s on your mind?',
                        hintStyle: TextStyle(fontSize: 13, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF9CA3AF)),
                        filled: true,
                        fillColor: dark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.image_outlined, size: 17),
                    label: const Text('Photo', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF22C55E), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.sentiment_satisfied_outlined, size: 17),
                    label: const Text('Feeling', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF22C55E), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Posts Feed ──
        ...posts.map((post) => _PostCard(post: post, dark: dark, isLiked: likedPosts.contains(post.id), onLike: () => onLike(post.id), onComment: () => onComment(post), onShare: onShare)),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final _Post post;
  final bool dark;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const _PostCard({required this.post, required this.dark, required this.isLiked, required this.onLike, required this.onComment, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1F2937) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final textPrimary = dark ? Colors.white : const Color(0xFF111827);
    final textSecondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF60A5FA), Color(0xFF2563EB)]), shape: BoxShape.circle),
                child: Center(child: Text(post.avatar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.author, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textPrimary)),
                  Text(post.time, style: TextStyle(fontSize: 11, color: textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(post.content, style: TextStyle(fontSize: 13, height: 1.5, color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151))),
          if (post.imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(post.imageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(height: 120, color: const Color(0xFF22C55E).withValues(alpha: 0.1), child: const Icon(Icons.image_outlined, color: Color(0xFF22C55E), size: 40))),
            ),
          ],
          const SizedBox(height: 10),
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: border))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${post.likes} likes', style: TextStyle(fontSize: 11, color: textSecondary)),
                Text('${post.comments} comments · ${post.shares} shares', style: TextStyle(fontSize: 11, color: textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _PostActionBtn(icon: isLiked ? Icons.favorite : Icons.favorite_outline, label: 'Like', color: isLiked ? const Color(0xFFEF4444) : textSecondary, onTap: onLike, dark: dark),
              _PostActionBtn(icon: Icons.chat_bubble_outline, label: 'Comment', color: textSecondary, onTap: onComment, dark: dark),
              _PostActionBtn(icon: Icons.share_outlined, label: 'Share', color: textSecondary, onTap: onShare, dark: dark),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool dark;
  const _PostActionBtn({required this.icon, required this.label, required this.color, required this.onTap, required this.dark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}

// ─── Marketplace Tab ──────────────────────────────────────────────────────────

class _MarketplaceTab extends StatelessWidget {
  final bool dark;
  final List<_Product> products;
  final TextEditingController searchController;
  final ValueChanged<String> onChat;

  const _MarketplaceTab({required this.dark, required this.products, required this.searchController, required this.onChat});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1F2937) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: border))),
          child: Container(
            decoration: BoxDecoration(color: dark ? const Color(0xFF374151) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
            child: TextField(
              controller: searchController,
              style: TextStyle(fontSize: 13, color: dark ? Colors.white : const Color(0xFF111827)),
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: TextStyle(fontSize: 13, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF9CA3AF)),
                prefixIcon: Icon(Icons.search, size: 18, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        // Product grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.62,
            ),
            itemCount: products.length,
            itemBuilder: (_, i) => _ProductCard(product: products[i], dark: dark, onChat: onChat),
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final _Product product;
  final bool dark;
  final ValueChanged<String> onChat;
  const _ProductCard({required this.product, required this.dark, required this.onChat});

  @override
  Widget build(BuildContext context) {
    final cardBg = dark ? const Color(0xFF374151) : Colors.white;
    final borderColor = dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB);
    final textPrimary = dark ? Colors.white : const Color(0xFF111827);
    final textSecondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 110, width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFDCFCE7), Color(0xFFBBF7D0)]),
            ),
            child: Center(child: Text(product.emoji, style: const TextStyle(fontSize: 48))),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(product.seller, style: TextStyle(fontSize: 10, color: textSecondary)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('\$${product.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF22C55E))),
                    Row(children: [
                      const Icon(Icons.star, size: 12, color: Color(0xFFFACC15)),
                      const SizedBox(width: 2),
                      Text('${product.rating}', style: TextStyle(fontSize: 10, color: textSecondary)),
                    ]),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => onChat(product.seller),
                    icon: const Icon(Icons.message_outlined, size: 14),
                    label: const Text('Request', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
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
