import 'package:flutter/material.dart';

class MapScreen extends StatefulWidget {
  final bool isDarkMode;
  const MapScreen({super.key, required this.isDarkMode});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _Venue {
  final int id;
  final String name;
  final String type;
  final String address;
  final double rating;
  final bool openNow;
  const _Venue({required this.id, required this.name, required this.type, required this.address, required this.rating, required this.openNow});
}

class _MapScreenState extends State<MapScreen> {
  String _searchQuery = '';
  int? _selectedVenue;

  static const _venues = [
    _Venue(id: 1, name: 'Central Stadium',       type: 'Football',    address: '123 Hoang Hoa Tham St, Ba Dinh',       rating: 4.5, openNow: true),
    _Venue(id: 2, name: 'Victory Sports Complex', type: 'Badminton',   address: '456 Nguyen Trai St, Thanh Xuan',        rating: 4.8, openNow: true),
    _Venue(id: 3, name: 'Riverside Park',         type: 'Football',    address: '789 Tran Duy Hung St, Cau Giay',        rating: 4.2, openNow: true),
    _Venue(id: 4, name: 'Elite Tennis Club',      type: 'Tennis',      address: '321 Lang Ha St, Dong Da',               rating: 4.9, openNow: false),
    _Venue(id: 5, name: 'Skyline Fitness Arena',  type: 'Basketball',  address: '654 Giang Vo St, Ba Dinh',              rating: 4.6, openNow: true),
    _Venue(id: 6, name: 'Lakeside Sports Center', type: 'Multi-Sport', address: '987 Xa Dan St, Dong Da',                rating: 4.4, openNow: true),
  ];

  List<_Venue> get _filtered {
    if (_searchQuery.isEmpty) return _venues;
    final q = _searchQuery.toLowerCase();
    return _venues.where((v) =>
      v.name.toLowerCase().contains(q) ||
      v.type.toLowerCase().contains(q) ||
      v.address.toLowerCase().contains(q)
    ).toList();
  }

  Color _typeColor(_Venue v) {
    switch (v.type) {
      case 'Football':    return const Color(0xFF22C55E);
      case 'Badminton':   return const Color(0xFF3B82F6);
      case 'Tennis':      return const Color(0xFFF59E0B);
      case 'Basketball':  return const Color(0xFFEF4444);
      default:            return const Color(0xFF8B5CF6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDarkMode;
    final bg = dark ? const Color(0xFF1F2937) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: border))),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(fontSize: 13, color: dark ? Colors.white : const Color(0xFF111827)),
                    decoration: InputDecoration(
                      hintText: 'Search venues...',
                      hintStyle: TextStyle(fontSize: 13, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF9CA3AF)),
                      prefixIcon: Icon(Icons.search, size: 18, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Mock Map Preview
        Container(
          height: 300,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF065F46), Color(0xFF0F766E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              CustomPaint(painter: _GridPainter(), size: Size.infinite),
              // Fake road lines
              CustomPaint(painter: _RoadPainter(), size: Size.infinite),
              // Venue dot markers
              ..._buildMapDots(context),
              // Centre label
              Positioned(
                top: 16, left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Hanoi, Vietnam', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
              // No-key notice
              Positioned(
                bottom: 12, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Add Google Maps API key for full interactivity', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Venue List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: _filtered.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Nearby Venues (${_filtered.length})',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: dark ? Colors.white : const Color(0xFF111827)),
                  ),
                );
              }
              final venue = _filtered[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _VenueCard(
                  venue: venue,
                  dark: dark,
                  isSelected: _selectedVenue == venue.id,
                  typeColor: _typeColor(venue),
                  onTap: () => setState(() => _selectedVenue = venue.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMapDots(BuildContext context) {
    final positions = [
      const Alignment(-0.65, -0.40),
      const Alignment(0.40,  -0.15),
      const Alignment(-0.55,  0.35),
      const Alignment(0.55,   0.45),
      const Alignment(0.15,  -0.65),
      const Alignment(-0.10,  0.60),
    ];
    final colors = [
      const Color(0xFF22C55E), const Color(0xFF3B82F6),
      const Color(0xFF22C55E), const Color(0xFFEF4444),
      const Color(0xFFF59E0B), const Color(0xFF8B5CF6),
    ];
    return List.generate(positions.length, (i) => Align(
      alignment: positions[i],
      child: GestureDetector(
        onTap: () => setState(() => _selectedVenue = _venues[i % _venues.length].id),
        child: Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: colors[i],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: colors[i].withValues(alpha: 0.5), blurRadius: 6)],
          ),
        ),
      ),
    ));
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.06)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 40) { canvas.drawLine(Offset(x, 0), Offset(x, size.height), p); }
    for (double y = 0; y < size.height; y += 40) { canvas.drawLine(Offset(0, y), Offset(size.width, y), p); }
  }
  @override bool shouldRepaint(_GridPainter _) => false;
}

class _RoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.15)..strokeWidth = 3;
    canvas.drawLine(Offset(0, size.height * 0.45), Offset(size.width, size.height * 0.48), p);
    p.strokeWidth = 2;
    canvas.drawLine(Offset(size.width * 0.30, 0), Offset(size.width * 0.33, size.height), p);
    canvas.drawLine(Offset(size.width * 0.60, 0), Offset(size.width * 0.65, size.height), p);
    canvas.drawLine(Offset(0, size.height * 0.70), Offset(size.width, size.height * 0.73), p);
  }
  @override bool shouldRepaint(_RoadPainter _) => false;
}

class _VenueCard extends StatelessWidget {
  final _Venue venue;
  final bool dark;
  final bool isSelected;
  final Color typeColor;
  final VoidCallback onTap;

  const _VenueCard({required this.venue, required this.dark, required this.isSelected, required this.typeColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? const Color(0xFFDCFCE7)
        : dark ? const Color(0xFF374151) : Colors.white;
    final borderColor = isSelected ? const Color(0xFF22C55E) : dark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          boxShadow: dark ? null : [const BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.name,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isSelected ? const Color(0xFF15803D) : dark ? Colors.white : const Color(0xFF111827)),
                      ),
                      const SizedBox(height: 2),
                      Text(venue.address, style: TextStyle(fontSize: 11, color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 13, color: Color(0xFFFACC15)),
                          const SizedBox(width: 3),
                          Text('${venue.rating}', style: TextStyle(fontSize: 12, color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151))),
                          const SizedBox(width: 10),
                          Icon(Icons.access_time, size: 13, color: venue.openNow ? const Color(0xFF22C55E) : const Color(0xFFEF4444)),
                          const SizedBox(width: 3),
                          Text(venue.openNow ? 'Open' : 'Closed', style: TextStyle(fontSize: 12, color: venue.openNow ? const Color(0xFF22C55E) : const Color(0xFFEF4444))),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(venue.type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: typeColor)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('View Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
