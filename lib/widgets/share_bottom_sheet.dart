import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShareBottomSheet extends StatefulWidget {
  final bool isDarkMode;
  const ShareBottomSheet({super.key, required this.isDarkMode});

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  bool _copied = false;

  void _copyLink() {
    Clipboard.setData(const ClipboardData(text: 'https://sportmate.app/post/12345'));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDarkMode;
    final bg = dark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = dark ? Colors.white : const Color(0xFF111827);
    final divider = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Share Post', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textColor)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563)),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: divider),
            // Options
            ..._buildOptions(dark, textColor),
            // Copy link
            _buildCopyLink(dark, textColor),
            // Cancel
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                    foregroundColor: textColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOptions(bool dark, Color textColor) {
    final options = [
      (Icons.message_outlined, 'Send in Message', const Color(0xFF3B82F6)),
      (Icons.mail_outline, 'Share via Email', const Color(0xFFEF4444)),
      (Icons.auto_stories_outlined, 'Share to Story', const Color(0xFF8B5CF6)),
    ];
    return options.map((o) {
      final (icon, label, color) = o;
      return InkWell(
        onTap: () => Navigator.pop(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildCopyLink(bool dark, Color textColor) {
    return InkWell(
      onTap: _copyLink,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
              child: Icon(_copied ? Icons.check : Icons.link, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_copied ? 'Link Copied!' : 'Copy Link', style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
                  if (!_copied)
                    Text('sportmate.app/post/12345', style: TextStyle(fontSize: 12, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
