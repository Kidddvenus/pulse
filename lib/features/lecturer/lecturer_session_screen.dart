import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_colors.dart';

class LecturerSessionScreen extends StatefulWidget {
  final String lecturerName;
  const LecturerSessionScreen({Key? key, required this.lecturerName}) : super(key: key);

  @override
  State<LecturerSessionScreen> createState() => _LecturerSessionScreenState();
}

class _LecturerSessionScreenState extends State<LecturerSessionScreen>
    with SingleTickerProviderStateMixin {

  // Form state
  final _unitCodeCtrl = TextEditingController();
  final _unitNameCtrl = TextEditingController();

  // Location state
  bool _isFetchingLocation = false;
  Position? _pinnedPosition;
  String _locationName = '';
  GoogleMapController? _mapController;
  Set<Circle> _circles = {};
  Set<Marker> _markers = {};

  // Session state
  bool _isStarting = false;
  String? _activeSessionId;
  Map<String, dynamic>? _activeSession;
  StreamSubscription<DocumentSnapshot>? _sessionSub;
  Timer? _elapsedTimer;
  Timer? _autoEndTimer;          // fires after 2 hours
  Duration _elapsed = Duration.zero;
  static const _sessionDuration = Duration(hours: 2);

  @override
  void dispose() {
    _unitCodeCtrl.dispose();
    _unitNameCtrl.dispose();
    _mapController?.dispose();
    _sessionSub?.cancel();
    _elapsedTimer?.cancel();
    _autoEndTimer?.cancel();
    super.dispose();
  }

  // ─── Location ────────────────────────────────────────────────────────────────

  Future<void> _pinLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) { _snack('Location services are disabled.'); return; }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _snack('Location permission denied.'); return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      String addr = 'Lat: ${pos.latitude.toStringAsFixed(5)}, Lng: ${pos.longitude.toStringAsFixed(5)}';
      try {
        final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (marks.isNotEmpty) {
          final p = marks.first;
          addr = [p.name, p.street, p.subLocality, p.locality]
              .where((s) => s != null && s.isNotEmpty)
              .cast<String>()
              .join(', ');
        }
      } catch (_) {}

      final latlng = LatLng(pos.latitude, pos.longitude);

      if (mounted) {
        setState(() {
          _pinnedPosition = pos;
          _locationName = addr;
          _markers = {
            Marker(
              markerId: const MarkerId('pin'),
              position: latlng,
              infoWindow: InfoWindow(title: 'Session Location', snippet: addr),
            ),
          };
          _circles = {
            Circle(
              circleId: const CircleId('radius'),
              center: latlng,
              radius: 50,
              fillColor: AppColors.primary.withOpacity(0.15),
              strokeColor: AppColors.primary.withOpacity(0.6),
              strokeWidth: 2,
            ),
          };
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latlng, 18),
        );
      }
    } catch (e) {
      _snack('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  // ─── Session ─────────────────────────────────────────────────────────────────

  Future<void> _startSession() async {
    final unitCode = _unitCodeCtrl.text.trim().toUpperCase();
    final unitName = _unitNameCtrl.text.trim();

    if (unitCode.isEmpty || unitName.isEmpty) {
      _snack('Please enter the unit code and name.');
      return;
    }
    if (_pinnedPosition == null) {
      _snack('Please pin a location first.');
      return;
    }

    setState(() => _isStarting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final expiresAt = DateTime.now().add(_sessionDuration);
      final ref = await FirebaseFirestore.instance.collection('sessions').add({
        'lecturerId': uid,
        'lecturerName': widget.lecturerName,
        'unitCode': unitCode,
        'unitName': unitName,
        'latitude': _pinnedPosition!.latitude,
        'longitude': _pinnedPosition!.longitude,
        'locationName': _locationName,
        'radiusMetres': 50,
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'durationMinutes': _sessionDuration.inMinutes,
        'endedAt': null,
      });

      // Listen to live session doc
      _sessionSub = ref.snapshots().listen((snap) {
        if (snap.exists && mounted) {
          setState(() => _activeSession = snap.data() as Map<String, dynamic>);
        }
      });

      // Start elapsed timer (ticks every second)
      _elapsed = Duration.zero;
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });

      // Auto-end after 2 hours
      _autoEndTimer = Timer(_sessionDuration, () {
        if (mounted && _activeSessionId != null) {
          _autoEndSession();
        }
      });

      if (mounted) setState(() { _activeSessionId = ref.id; _isStarting = false; });
    } catch (e) {
      _snack('Failed to start session: $e');
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Session?', style: TextStyle(color: Colors.white)),
        content: const Text('Students will no longer be able to sign attendance.',
            style: TextStyle(color: AppColors.textSecondaryDark)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Session', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await FirebaseFirestore.instance.collection('sessions').doc(_activeSessionId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
    _sessionSub?.cancel();
    _elapsedTimer?.cancel();
    _autoEndTimer?.cancel();
    if (mounted) {
      setState(() {
        _activeSessionId = null;
        _activeSession = null;
        _elapsed = Duration.zero;
        _unitCodeCtrl.clear();
        _unitNameCtrl.clear();
        _pinnedPosition = null;
        _locationName = '';
        _markers = {};
        _circles = {};
      });
      _snack('Session ended successfully.');
    }
  }

  /// Called automatically after 2 hours — no confirmation dialog.
  Future<void> _autoEndSession() async {
    if (_activeSessionId == null) return;
    await FirebaseFirestore.instance.collection('sessions').doc(_activeSessionId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
      'autoEnded': true,
    });
    _sessionSub?.cancel();
    _elapsedTimer?.cancel();
    if (mounted) {
      setState(() {
        _activeSessionId = null;
        _activeSession = null;
        _elapsed = Duration.zero;
        _unitCodeCtrl.clear();
        _unitNameCtrl.clear();
        _pinnedPosition = null;
        _locationName = '';
        _markers = {};
        _circles = {};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.timer_off_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Session ended automatically after 2 hours.'),
            ],
          ),
          backgroundColor: AppColors.warning.withOpacity(0.9),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ─── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: _activeSessionId != null
              ? _buildLiveSession()
              : _buildSetupForm(),
        ),
      ),
    );
  }

  // Setup form
  Widget _buildSetupForm() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(
          child: GlassCard(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle(Icons.menu_book_rounded, 'Unit Details'),
                const SizedBox(height: 16),
                TextField(
                  controller: _unitCodeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.code_rounded),
                    hintText: 'Unit Code (e.g. SMA 2418)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _unitNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.menu_book_outlined),
                    hintText: 'Unit Name (e.g. Mobile Computing)',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(
          child: GlassCard(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle(Icons.location_pin, 'Session Location'),
                const SizedBox(height: 16),
                // Map preview
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 200,
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(-1.286389, 36.817223),
                        zoom: 15,
                      ),
                      onMapCreated: (c) => _mapController = c,
                      markers: _markers,
                      circles: _circles,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_pinnedPosition != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Location Pinned', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(_locationName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed: _isFetchingLocation ? null : _pinLocation,
                  icon: _isFetchingLocation
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location_rounded),
                  label: Text(_pinnedPosition == null ? 'Get My Location' : 'Re-pin Location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.radar_rounded, color: AppColors.primary, size: 16),
                      SizedBox(width: 8),
                      Text('50-metre radius will be enforced', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildStartButton(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildStartButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C853), AppColors.primary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.success.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isStarting ? null : _startSession,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: _isStarting
                ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text('Start Session', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // Live session view
  Widget _buildLiveSession() {
    final session = _activeSession;
    final unitCode = session?['unitCode'] ?? _unitCodeCtrl.text;
    final unitName = session?['unitName'] ?? _unitNameCtrl.text;
    final loc = session?['locationName'] ?? _locationName;
    final startedAt = session?['startedAt'] as Timestamp?;

    return Column(
      children: [
        _buildHeader(isLive: true),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Live badge
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.success.withOpacity(0.2), AppColors.primary.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.success.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          const Text('SESSION LIVE', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.5)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatElapsed(_elapsed),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                      if (startedAt != null)
                        Text(
                          'Started ${DateFormat('hh:mm a').format(startedAt.toDate())}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                        ),
                      const SizedBox(height: 10),
                      // Countdown to auto-expiry
                      Builder(builder: (_) {
                        final remaining = _sessionDuration - _elapsed;
                        final clamped = remaining <= Duration.zero ? Duration.zero : remaining;
                        final isUrgent = remaining.inMinutes <= 10;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isUrgent
                                ? AppColors.danger.withOpacity(0.15)
                                : AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isUrgent
                                  ? AppColors.danger.withOpacity(0.4)
                                  : AppColors.primary.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_outlined, size: 14,
                                  color: isUrgent ? AppColors.danger : AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Ends in ${_formatElapsed(clamped)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isUrgent ? AppColors.danger : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Session info card
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(Icons.menu_book_rounded, 'Unit', '$unitCode — $unitName'),
                      const Divider(height: 24),
                      _infoRow(Icons.location_on_rounded, 'Location', loc),
                      const Divider(height: 24),
                      _infoRow(Icons.radar_rounded, 'Geofence Radius', '50 metres'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Live student count
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('attendance')
                      .where('sessionId', isEqualTo: _activeSessionId)
                      .snapshots(),
                  builder: (ctx, snap) {
                    final count = snap.data?.docs.length ?? 0;
                    return GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.people_rounded, color: AppColors.primary, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$count', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primary, height: 1)),
                              const Text('Students Signed In', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryDark)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // End session button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _endSession,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('End Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({bool isLive = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.glassBgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorderDark),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLive ? 'Live Session' : 'Start Session',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.lecturerName,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                ),
              ],
            ),
          ),
          if (isLive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.success.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, color: AppColors.success, size: 8),
                  SizedBox(width: 6),
                  Text('LIVE', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}
