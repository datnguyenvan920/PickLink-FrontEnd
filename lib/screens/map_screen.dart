import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class _Venue {
  final String id;
  final String name;
  final String type;
  final String address;
  final LatLng latLng;

  const _Venue({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.latLng,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Map Screen
// ─────────────────────────────────────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  final bool isDarkMode;
  const MapScreen({super.key, required this.isDarkMode});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // ── Location state ─────────────────────────────────────────────────────────
  // Default: Hanoi, Vietnam
  LatLng _center = const LatLng(21.0285, 105.8542);
  bool _locating = false;
  String _locLabel = 'Hà Nội, Việt Nam';

  // ── Radius state ───────────────────────────────────────────────────────────
  double _radiusKm = 2.0; // km

  // ── Venues ─────────────────────────────────────────────────────────────────
  List<_Venue> _venues = [];
  bool _loadingVenues = false;
  Timer? _debounce;

  // ── Map controller ─────────────────────────────────────────────────────────
  final MapController _mapController = MapController();

  // ── Circle animation ───────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // ── Selected venue ─────────────────────────────────────────────────────────
  _Venue? _selectedVenue;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.25, end: 0.45).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    // Initial venue fetch
    _fetchVenues();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── GPS location ───────────────────────────────────────────────────────────
  Future<void> _findMyLocation() async {
    setState(() => _locating = true);
    // Since location plugins aren't added, we simulate a location lookup
    // by using Nominatim reverse-geocode on the current center.
    // In production, replace this with geolocator package.
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    // For now keep the default Hanoi coords — replace with real GPS data.
    final newCenter = _center;
    _mapController.move(newCenter, 14);
    await _reverseGeocode(newCenter);
    setState(() => _locating = false);
    _fetchVenues();
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${pos.latitude}&lon=${pos.longitude}'
        '&format=json&accept-language=vi',
      );
      final res = await http.get(uri, headers: {'User-Agent': 'PickleMatch/1.0'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final display = data['display_name'] as String? ?? '';
        final parts = display.split(',');
        final label = parts.take(3).join(',').trim();
        if (mounted) setState(() => _locLabel = label);
      }
    } catch (_) {}
  }

  // ── Overpass API for sports venues ────────────────────────────────────────
  void _onRadiusChanged(double v) {
    setState(() => _radiusKm = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _fetchVenues);
  }

  Future<void> _fetchVenues() async {
    if (!mounted) return;
    setState(() => _loadingVenues = true);

    final lat = _center.latitude;
    final lon = _center.longitude;
    final radiusM = (_radiusKm * 1000).round();

    // Overpass QL — sports venues / leisure pitches within radius
    final query = '''
[out:json][timeout:25];
(
  node["sport"~"tennis|badminton|basketball|volleyball|soccer|football|pickleball"](around:$radiusM,$lat,$lon);
  way["sport"~"tennis|badminton|basketball|volleyball|soccer|football|pickleball"](around:$radiusM,$lat,$lon);
  node["leisure"="sports_centre"](around:$radiusM,$lat,$lon);
  node["leisure"="pitch"](around:$radiusM,$lat,$lon);
);
out center 40;
''';

    try {
      final uri = Uri.parse('https://overpass-api.de/api/interpreter');
      final res = await http.post(
        uri,
        body: query,
        headers: {'User-Agent': 'PickleMatch/1.0'},
      );
      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final elements = (data['elements'] as List<dynamic>? ?? []);

        final venues = <_Venue>[];
        for (final el in elements) {
          final tags = el['tags'] as Map<String, dynamic>? ?? {};
          final name = (tags['name'] as String?)?.trim() ?? '';
          if (name.isEmpty) continue;

          double? elLat, elLon;
          if (el['type'] == 'node') {
            elLat = (el['lat'] as num?)?.toDouble();
            elLon = (el['lon'] as num?)?.toDouble();
          } else if (el['center'] != null) {
            elLat = (el['center']['lat'] as num?)?.toDouble();
            elLon = (el['center']['lon'] as num?)?.toDouble();
          }
          if (elLat == null || elLon == null) continue;

          final sport = (tags['sport'] as String? ?? tags['leisure'] as String? ?? 'Sports').trim();
          final addr = [
            tags['addr:street'],
            tags['addr:housenumber'],
            tags['addr:city'],
          ].whereType<String>().join(', ');

          venues.add(_Venue(
            id: '${el['id']}',
            name: name,
            type: _capitalise(sport.split(';').first.trim()),
            address: addr.isEmpty ? 'Xem trên bản đồ' : addr,
            latLng: LatLng(elLat, elLon),
          ));
        }
        setState(() {
          _venues = venues;
          _loadingVenues = false;
        });
        return;
      }
    } catch (_) {}

    // Fallback: mock venues scattered around center
    if (mounted) {
      setState(() {
        _venues = _mockVenues(_center, _radiusKm);
        _loadingVenues = false;
      });
    }
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

  // ── Mock data fallback ────────────────────────────────────────────────────
  static List<_Venue> _mockVenues(LatLng center, double radiusKm) {
    final rng = math.Random(42);
    final names = [
      ('Central Pickleball Arena', 'Pickleball'),
      ('Victory Sports Complex', 'Badminton'),
      ('Riverside Park Court', 'Tennis'),
      ('Skyline Basketball Club', 'Basketball'),
      ('Elite Multi-Sport Center', 'Multi-Sport'),
      ('Green Zone Pitch', 'Football'),
      ('Urban Racket Club', 'Pickleball'),
      ('Metro Sports Hub', 'Badminton'),
    ];
    return List.generate(names.length, (i) {
      final angleDeg = rng.nextDouble() * 360;
      final dist = rng.nextDouble() * radiusKm * 0.9;
      final dLat = dist / 111.0 * math.cos(angleDeg * math.pi / 180);
      final dLon = dist / (111.0 * math.cos(center.latitude * math.pi / 180)) *
          math.sin(angleDeg * math.pi / 180);
      return _Venue(
        id: 'mock_$i',
        name: names[i].$1,
        type: names[i].$2,
        address: 'Gần trung tâm • ${dist.toStringAsFixed(1)} km',
        latLng: LatLng(center.latitude + dLat, center.longitude + dLon),
      );
    });
  }

  // ── Color helpers ─────────────────────────────────────────────────────────
  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'football':
      case 'soccer':
        return const Color(0xFF22C55E);
      case 'badminton':
        return const Color(0xFF3B82F6);
      case 'tennis':
        return const Color(0xFFF59E0B);
      case 'basketball':
        return const Color(0xFFEF4444);
      case 'pickleball':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF06B6D4);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDarkMode;
    final bg = dark ? const Color(0xFF111827) : Colors.white;
    final surface = dark ? const Color(0xFF1F2937) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final textPrimary = dark ? Colors.white : const Color(0xFF111827);
    final textSecondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // ── Full-screen map ─────────────────────────────────────────────
          Positioned.fill(
            child: _buildMap(),
          ),

          // ── Top overlay: location label + find-me button ───────────────
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: dark ? 0.4 : 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFF22C55E), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _locLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Find my location button
                  _GlassButton(
                    dark: dark,
                    surface: surface,
                    border: border,
                    loading: _locating,
                    icon: Icons.my_location,
                    color: const Color(0xFF22C55E),
                    onTap: _findMyLocation,
                    tooltip: 'Tìm vị trí của tôi',
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom panel: radius slider + venue list ───────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomPanel(
              dark: dark,
              surface: surface,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              radiusKm: _radiusKm,
              onRadiusChanged: _onRadiusChanged,
              venues: _venues,
              loading: _loadingVenues,
              selectedVenue: _selectedVenue,
              typeColor: _typeColor,
              onVenueTap: (v) {
                setState(() => _selectedVenue = v);
                _mapController.move(v.latLng, 16);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final dark = widget.isDarkMode;

    // Tile URL changes based on dark mode
    // Using CartoDB dark/light tiles (no key required)
    final tileUrl = dark
        ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
        : 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png';

    final radiusM = _radiusKm * 1000;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 14,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // Tile layer
        TileLayer(
          urlTemplate: tileUrl,
          userAgentPackageName: 'com.pickleball.match',
          maxNativeZoom: 19,
        ),

        // ── Animated radius circle ─────────────────────────────────────
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) {
            return CircleLayer(
              circles: [
                // Outer pulse glow
                CircleMarker(
                  point: _center,
                  radius: radiusM,
                  color: const Color(0xFF22C55E).withValues(alpha: _pulseAnim.value * 0.18),
                  borderColor: Colors.transparent,
                  borderStrokeWidth: 0,
                  useRadiusInMeter: true,
                ),
                // Main fill
                CircleMarker(
                  point: _center,
                  radius: radiusM,
                  color: const Color(0xFF22C55E).withValues(alpha: 0.08),
                  borderColor: const Color(0xFF22C55E).withValues(alpha: 0.7),
                  borderStrokeWidth: 2,
                  useRadiusInMeter: true,
                ),
              ],
            );
          },
        ),

        // ── Venue markers ──────────────────────────────────────────────
        MarkerLayer(
          markers: _venues.map((v) {
            final color = _typeColor(v.type);
            final isSelected = _selectedVenue?.id == v.id;
            return Marker(
              point: v.latLng,
              width: isSelected ? 44 : 32,
              height: isSelected ? 44 : 32,
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedVenue = v);
                  _mapController.move(v.latLng, 16);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: isSelected ? 16 : 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _venueIcon(v.type),
                      color: Colors.white,
                      size: isSelected ? 22 : 16,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // ── My location marker ─────────────────────────────────────────
        MarkerLayer(
          markers: [
            Marker(
              point: _center,
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x9922C55E),
                          blurRadius: 12,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.person_pin, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _venueIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pickleball':
        return Icons.sports_tennis;
      case 'badminton':
        return Icons.sports_tennis;
      case 'tennis':
        return Icons.sports_tennis;
      case 'basketball':
        return Icons.sports_basketball;
      case 'football':
      case 'soccer':
        return Icons.sports_soccer;
      default:
        return Icons.stadium;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass button
// ─────────────────────────────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  final bool dark;
  final Color surface;
  final Color border;
  final bool loading;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _GlassButton({
    required this.dark,
    required this.surface,
    required this.border,
    required this.loading,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.4 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: loading
              ? Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                )
              : Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Panel (radius slider + venue list)
// ─────────────────────────────────────────────────────────────────────────────

class _BottomPanel extends StatefulWidget {
  final bool dark;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final double radiusKm;
  final ValueChanged<double> onRadiusChanged;
  final List<_Venue> venues;
  final bool loading;
  final _Venue? selectedVenue;
  final Color Function(String) typeColor;
  final ValueChanged<_Venue> onVenueTap;

  const _BottomPanel({
    required this.dark,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.radiusKm,
    required this.onRadiusChanged,
    required this.venues,
    required this.loading,
    required this.selectedVenue,
    required this.typeColor,
    required this.onVenueTap,
  });

  @override
  State<_BottomPanel> createState() => _BottomPanelState();
}

class _BottomPanelState extends State<_BottomPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final surface = widget.surface;
    final border = widget.border;
    final textPrimary = widget.textPrimary;
    final textSecondary = widget.textSecondary;

    final panelRadius = const Radius.circular(24);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.only(topLeft: panelRadius, topRight: panelRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.5 : 0.1),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ─────────────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // ── Radius Slider ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.radar, color: Color(0xFF22C55E), size: 15),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Bán kính tìm trận',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    // Radius badge
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${widget.radiusKm.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF22C55E),
                    inactiveTrackColor: dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                    thumbColor: Colors.white,
                    overlayColor: const Color(0x3322C55E),
                    thumbShape: const _GreenThumbShape(),
                    trackHeight: 5,
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                  ),
                  child: Slider(
                    value: widget.radiusKm,
                    min: 0.5,
                    max: 20.0,
                    divisions: 39,
                    onChanged: widget.onRadiusChanged,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0.5 km', style: TextStyle(fontSize: 9, color: textSecondary)),
                    Text('20 km', style: TextStyle(fontSize: 9, color: textSecondary)),
                  ],
                ),
              ],
            ),
          ),

          // ── Venue count + expand toggle ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Sân gần đây',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (widget.loading)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: const AlwaysStoppedAnimation(Color(0xFF22C55E)),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${widget.venues.length}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                    ],
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 250),
                    turns: _expanded ? 0.5 : 0,
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      color: textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Venue list (collapsible) ────────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(height: 12),
            secondChild: widget.loading
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Color(0xFF22C55E)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Đang tìm sân…',
                            style: TextStyle(fontSize: 11, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : widget.venues.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off, size: 32, color: textSecondary),
                              const SizedBox(height: 6),
                              Text(
                                'Không tìm thấy sân trong bán kính này',
                                style: TextStyle(fontSize: 12, color: textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Thử tăng bán kính tìm kiếm',
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 220,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.venues.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, i) {
                            final v = widget.venues[i];
                            final isSelected = widget.selectedVenue?.id == v.id;
                            final color = widget.typeColor(v.type);
                            return GestureDetector(
                              onTap: () => widget.onVenueTap(v),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 180,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color.withValues(alpha: dark ? 0.25 : 0.08)
                                      : dark
                                          ? const Color(0xFF374151)
                                          : const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? color : border,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : null,
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Type badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        v.type,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      v.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? color
                                            : dark
                                                ? Colors.white
                                                : const Color(0xFF111827),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.place_outlined,
                                            size: 10,
                                            color: dark
                                                ? const Color(0xFF9CA3AF)
                                                : const Color(0xFF6B7280)),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            v.address,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: dark
                                                  ? const Color(0xFF9CA3AF)
                                                  : const Color(0xFF6B7280),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () {},
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: color,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 7),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: const Text(
                                          'Xem chi tiết',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),

          // Safe area spacing
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom slider thumb with green ring + white center
// ─────────────────────────────────────────────────────────────────────────────

class _GreenThumbShape extends SliderComponentShape {
  const _GreenThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(22, 22);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    // Shadow
    canvas.drawCircle(
      center + const Offset(0, 2),
      10,
      Paint()
        ..color = const Color(0x4422C55E)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Outer green ring
    canvas.drawCircle(center, 11, Paint()..color = const Color(0xFF22C55E));
    // White inner
    canvas.drawCircle(center, 7, Paint()..color = Colors.white);
  }
}
