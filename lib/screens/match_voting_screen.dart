import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_api.dart' show AuthSession;
import '../services/match_api.dart';

class MatchVotingScreen extends StatefulWidget {
  final int matchId;
  final AuthSession authSession;
  final bool isDarkMode;

  const MatchVotingScreen({
    super.key,
    required this.matchId,
    required this.authSession,
    required this.isDarkMode,
  });

  @override
  State<MatchVotingScreen> createState() => _MatchVotingScreenState();
}

class _MatchVotingScreenState extends State<MatchVotingScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _errorMessage;
  MatchVotingStatusResponse? _status;
  Timer? _pollTimer;

  // Selected choices
  int? _selectedVenueId;
  String? _selectedStartTime;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    // Poll status every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchStatus(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      
      // Let's resolve the host: on Android emulator, use 10.0.2.2.
      // We can inspect the host from dynamic environments or just resolve it dynamically:
      final host = RegExp(r'10\.0\.2\.2').hasMatch(widget.authSession.token) ? '10.0.2.2' : 'localhost';
      final resolvedUrl = 'http://$host:5209';

      final status = await MatchApi(baseUrl: resolvedUrl).getVotingStatus(
        widget.authSession.token,
        widget.matchId,
      );

      if (!mounted) return;

      setState(() {
        _status = status;
        _loading = false;
        
        // If match is scheduled, stop polling and show success dialog
        if (status.status.toLowerCase() == 'scheduled') {
          _pollTimer?.cancel();
          _showMatchFinalizedDialog();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) {
          _errorMessage = e.toString();
        }
      });
    }
  }

  Future<void> _submitVote() async {
    if (_selectedVenueId == null || _selectedStartTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn đầy đủ Sân và Giờ chơi.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final host = RegExp(r'10\.0\.2\.2').hasMatch(widget.authSession.token) ? '10.0.2.2' : 'localhost';
      final resolvedUrl = 'http://$host:5209';

      final status = await MatchApi(baseUrl: resolvedUrl).castVote(
        token: widget.authSession.token,
        matchId: widget.matchId,
        venueId: _selectedVenueId!,
        startTime: _selectedStartTime!,
      );

      if (!mounted) return;

      setState(() {
        _status = status;
        _submitting = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi bầu chọn thành công! 🎉')),
        );

        if (status.status.toLowerCase() == 'scheduled') {
          _pollTimer?.cancel();
          _showMatchFinalizedDialog();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showMatchFinalizedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Text('🎉 ', style: TextStyle(fontSize: 24)),
              Expanded(child: Text('Trận đấu đã chốt!', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          content: const Text(
            'Tất cả người chơi đã thống nhất! Trận đấu đã được xếp lịch và đặt sân thành công. Đang tải chi tiết...',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // dismiss dialog
                Navigator.of(this.context).pop(); // return to home
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Quay lại Trang chủ'),
            )
          ],
        ),
      ),
    );
  }

  String _formatTime(String time) {
    if (time.length >= 5) {
      return time.substring(0, 5);
    }
    return time;
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDarkMode;
    final bg = dark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Bầu chọn trận đấu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: dark ? const Color(0xFF1F2937) : Colors.white,
        foregroundColor: dark ? Colors.white : Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchStatus(),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF22C55E))))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('❌', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => _fetchStatus(),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : _status == null
                  ? const Center(child: Text('Không tải được thông tin phòng bầu chọn.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Status banner
                          _buildHeaderBanner(dark),
                          const SizedBox(height: 20),

                          // ── Player Votes list
                          Text('Trạng thái bầu chọn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: dark ? Colors.white : Colors.black)),
                          const SizedBox(height: 8),
                          _buildVotesList(dark),
                          const SizedBox(height: 24),

                          // ── Venue selection list
                          Text('1. Chọn Sân đấu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: dark ? Colors.white : Colors.black)),
                          const SizedBox(height: 8),
                          _buildVenueOptions(dark),
                          const SizedBox(height: 24),

                          // ── Time slots selection list
                          Text('2. Chọn Giờ bắt đầu (Trận 1h30)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: dark ? Colors.white : Colors.black)),
                          const SizedBox(height: 8),
                          _buildTimeSlotOptions(dark),
                          const SizedBox(height: 32),

                          // ── Vote Submit button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _submitting ? null : _submitVote,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF22C55E),
                                disabledBackgroundColor: Colors.grey,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 2,
                              ),
                              child: _submitting
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      'Gửi Bầu Chọn',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildHeaderBanner(bool dark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Text('⏳', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đang thống nhất lịch thi đấu',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Khung giờ chung: ${_formatTime(_status!.preferredTimeStart)} - ${_formatTime(_status!.preferredTimeEnd)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildVotesList(bool dark) {
    return Column(
      children: _status!.votes.map((v) {
        final hasVoted = v.votedVenueId != null && v.votedStartTime != null;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                child: Text(
                  v.playerName.isNotEmpty ? v.playerName.substring(0, 1).toUpperCase() : 'P',
                  style: TextStyle(color: dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.playerName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    hasVoted
                        ? Text(
                            'Sân ${v.votedVenueId} • ${_formatTime(v.votedStartTime!)}',
                            style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500),
                          )
                        : const Text(
                            'Chưa bầu chọn',
                            style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.w500),
                          ),
                  ],
                ),
              ),
              Icon(
                hasVoted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: hasVoted ? const Color(0xFF22C55E) : Colors.grey,
                size: 20,
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVenueOptions(bool dark) {
    if (_status!.candidateVenues.isEmpty) {
      return const Text('Không có sân chung nào khả dụng.', style: TextStyle(color: Colors.red));
    }

    return Column(
      children: _status!.candidateVenues.map((venue) {
        final isSelected = _selectedVenueId == venue.venueId;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedVenueId = venue.venueId;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF22C55E).withValues(alpha: 0.08)
                  : dark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFF22C55E) : dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(child: Text(' Stadium ', style: TextStyle(fontSize: 12))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.venueName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        venue.address,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Radio<int>(
                  value: venue.venueId,
                  groupValue: _selectedVenueId,
                  activeColor: const Color(0xFF22C55E),
                  onChanged: (val) {
                    setState(() {
                      _selectedVenueId = val;
                    });
                  },
                )
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeSlotOptions(bool dark) {
    if (_status!.candidateSlots.isEmpty) {
      return const Text('Không có khung giờ chơi 1.5h nào khả dụng trong thời gian này.', style: TextStyle(color: Colors.red));
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _status!.candidateSlots.map((slot) {
        final isSelected = _selectedStartTime == slot.start;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedStartTime = slot.start;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF22C55E)
                  : dark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? const Color(0xFF22C55E) : dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                width: 1.5,
              ),
            ),
            child: Text(
              '${_formatTime(slot.start)} - ${_formatTime(slot.end)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: isSelected ? Colors.white : dark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
