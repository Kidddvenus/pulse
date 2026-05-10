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
import '../../core/utils/biometric_helper.dart';
import '../../services/device_credential_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {

  // User info
  String? _registrationNumber;
  String? _firstName;
  String? _lastName;
  bool _isLoadingUser = true;

  // Location
  Position? _currentPosition;
  String _currentAddress = 'Identifying location…';
  bool _isCheckingLocation = true;

  // Session selection
  QueryDocumentSnapshot? _selectedSession;

  // Attendance state
  bool _isMarking = false;
  bool _isMarked = false;
  String? _markedSessionId;

  // Map
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  // Clock
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  // Pulse animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _loadUserData();
    _fetchLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _clockTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ─── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final d = doc.data()!;
        setState(() {
          _registrationNumber = d['registrationNumber'];
          _firstName = d['firstName'];
          _lastName = d['lastName'];
          _isLoadingUser = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _isCheckingLocation = true;
      _currentAddress = 'Identifying location…';
    });

    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _snack('Location services are disabled.');
        if (mounted) setState(() => _isCheckingLocation = false);
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _snack('Location permission denied.');
        if (mounted) setState(() => _isCheckingLocation = false);
        return;
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

      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _currentAddress = addr;
          _isCheckingLocation = false;
          _markers = {
            Marker(
              markerId: const MarkerId('me'),
              position: LatLng(pos.latitude, pos.longitude),
              infoWindow: const InfoWindow(title: 'Your Location'),
            ),
          };
        });
        _updateMapOverlays();
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 17),
        );
      }
    } catch (e) {
      if (mounted) {
        _snack('Location error: $e');
        setState(() => _isCheckingLocation = false);
      }
    }
  }

  void _updateMapOverlays() {
    if (_currentPosition == null) return;
    final session = _selectedSession;
    if (session == null) {
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('me'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            infoWindow: const InfoWindow(title: 'Your Location'),
          ),
        };
        _circles = {};
      });
      return;
    }

    final data = session.data() as Map<String, dynamic>;
    final sLat = (data['latitude'] as num).toDouble();
    final sLng = (data['longitude'] as num).toDouble();

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('me'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
        Marker(
          markerId: const MarkerId('session'),
          position: LatLng(sLat, sLng),
          infoWindow: InfoWindow(title: '${data['unitCode']} — Session Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        ),
      };
      _circles = {
        Circle(
          circleId: const CircleId('geofence'),
          center: LatLng(sLat, sLng),
          radius: 50,
          fillColor: AppColors.primary.withOpacity(0.12),
          strokeColor: AppColors.primary.withOpacity(0.5),
          strokeWidth: 2,
        ),
      };
    });

    // Fit both markers in view
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            [_currentPosition!.latitude, sLat].reduce((a, b) => a < b ? a : b) - 0.0005,
            [_currentPosition!.longitude, sLng].reduce((a, b) => a < b ? a : b) - 0.0005,
          ),
          northeast: LatLng(
            [_currentPosition!.latitude, sLat].reduce((a, b) => a > b ? a : b) + 0.0005,
            [_currentPosition!.longitude, sLng].reduce((a, b) => a > b ? a : b) + 0.0005,
          ),
        ),
        60,
      ),
    );
  }

  // ─── Attendance marking ───────────────────────────────────────────────────

  Future<void> _markAttendance() async {
    if (_selectedSession == null || _currentPosition == null || _registrationNumber == null) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      _snack('You are not signed in. Please log in again.');
      return;
    }

    // Device binding check — block proxy sign-ins
    final isAuthorized = await DeviceCredentialService.isAuthorized(currentUid);
    if (!isAuthorized) {
      final boundEmail = await DeviceCredentialService.getBoundEmail();
      if (mounted) {
        _showProxyBlockDialog(boundEmail);
      }
      return;
    }

    final data = _selectedSession!.data() as Map<String, dynamic>;
    final sLat = (data['latitude'] as num).toDouble();
    final sLng = (data['longitude'] as num).toDouble();
    final sessionId = _selectedSession!.id;

    // 1. Check geofence
    final dist = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      sLat,
      sLng,
    );

    if (dist > 50) {
      _snack('You are ${dist.toStringAsFixed(0)}m away. Must be within 50m to sign in.');
      return;
    }

    // 2. Check duplicate
    final existing = await FirebaseFirestore.instance
        .collection('attendance')
        .where('sessionId', isEqualTo: sessionId)
        .where('registrationNumber', isEqualTo: _registrationNumber)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      _snack('You have already signed attendance for this session.');
      return;
    }

    // 3. Biometric
    final auth = await BiometricHelper.authenticate('Verify your identity to sign attendance');
    if (!auth) {
      _snack('Biometric authentication failed or was cancelled.');
      return;
    }

    // 4. Write to Firestore
    setState(() => _isMarking = true);
    try {
      await FirebaseFirestore.instance.collection('attendance').add({
        'sessionId': sessionId,
        'registrationNumber': _registrationNumber,
        'studentName': '${_firstName ?? ''} ${_lastName ?? ''}'.trim(),
        'firstName': _firstName,
        'lastName': _lastName,
        'unitCode': data['unitCode'],
        'unitName': data['unitName'],
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'locationName': _currentAddress,
        'distanceFromSession': dist,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isMarking = false;
          _isMarked = true;
          _markedSessionId = sessionId;
        });
        _snack('✅ Attendance signed successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isMarking = false);
        _snack('Error: ${e.toString()}');
      }
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

  void _showProxyBlockDialog(String? boundEmail) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.gpp_bad_rounded, color: AppColors.danger, size: 24),
            SizedBox(width: 10),
            Text('Proxy Detected', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This device is registered to a different student account. You cannot sign attendance from this device.',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
            if (boundEmail != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Device owner: $boundEmail',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  // ─── Distance helper ──────────────────────────────────────────────────────

  double? _distanceToSession() {
    if (_currentPosition == null || _selectedSession == null) return null;
    final data = _selectedSession!.data() as Map<String, dynamic>;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      (data['latitude'] as num).toDouble(),
      (data['longitude'] as num).toDouble(),
    );
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: AuroraBackground(
        child: _isLoadingUser
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
      child: Column(
        children: [
          // Clock
          Text(
            DateFormat('EEEE, MMMM d').format(_now),
            style: TextStyle(color: Theme.of(context).colorScheme.surfaceContainerHighest, fontSize: 13),
          ),
          Text(
            DateFormat('hh:mm:ss a').format(_now),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Location status
          _buildLocationStatus(),
          const SizedBox(height: 16),

          // Map
          _buildMap(),
          const SizedBox(height: 20),

          // Active sessions
          _buildSessionsList(),
          const SizedBox(height: 20),

          // Sign button area
          if (_selectedSession != null) _buildSignArea(),
        ],
      ),
    );
  }

  Widget _buildLocationStatus() {
    if (_isCheckingLocation) {
      return _statusContainer(
        color: AppColors.primary,
        icon: Icons.gps_not_fixed_rounded,
        title: 'Identifying location…',
        subtitle: null,
        trailing: const SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        ),
      );
    }
    if (_currentPosition == null) {
      return _statusContainer(
        color: AppColors.danger,
        icon: Icons.location_off_rounded,
        title: 'Location unavailable',
        subtitle: 'Tap to retry',
        onTap: _fetchLocation,
      );
    }
    return _statusContainer(
      color: AppColors.success,
      icon: Icons.location_on_rounded,
      title: 'Location found',
      subtitle: _currentAddress,
    );
  }

  Widget _statusContainer({
    required Color color,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                  if (subtitle != null)
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorderDark),
        ),
        child: GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(-1.286389, 36.817223),
            zoom: 14,
          ),
          onMapCreated: (c) {
            _mapController = c;
            if (_currentPosition != null) {
              c.animateCamera(CameraUpdate.newLatLngZoom(
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 17,
              ));
            }
          },
          markers: _markers,
          circles: _circles,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }

  Widget _buildSessionsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final allDocs = snapshot.data?.docs ?? [];
        final now = DateTime.now();

        // Only show sessions that are active AND not past their expiresAt
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final expiresAt = data['expiresAt'] as Timestamp?;
          if (expiresAt == null) return true; // legacy docs without expiry — allow
          return expiresAt.toDate().isAfter(now);
        }).toList();

        if (docs.isEmpty) {
          return GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.hourglass_empty_rounded, size: 40, color: AppColors.textSecondaryDark.withOpacity(0.5)),
                const SizedBox(height: 12),
                const Text('No active sessions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                const Text(
                  'Your lecturer has not started a session yet. Check back soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondaryDark),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('${docs.length} Active Session${docs.length > 1 ? 's' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            ...docs.map((doc) => _buildSessionCard(doc)),
          ],
        );
      },
    );
  }

  Widget _buildSessionCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isSelected = _selectedSession?.id == doc.id;
    final alreadyMarked = _isMarked && _markedSessionId == doc.id;

    return GestureDetector(
      onTap: alreadyMarked ? null : () {
        setState(() {
          _selectedSession = isSelected ? null : doc;
          _isMarked = false;
        });
        _updateMapOverlays();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [AppColors.primary.withOpacity(0.15), const Color(0xFF6366F1).withOpacity(0.1)])
              : null,
          color: isSelected ? null : AppColors.glassBgDark.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary.withOpacity(0.5) : AppColors.glassBorderDark,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: alreadyMarked
                    ? AppColors.success.withOpacity(0.15)
                    : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                alreadyMarked ? Icons.check_circle_rounded : Icons.menu_book_rounded,
                color: alreadyMarked ? AppColors.success : AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data['unitCode']} — ${data['unitName']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'By ${data['lecturerName'] ?? 'Lecturer'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                  ),
                  Text(
                    data['locationName'] ?? '',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (alreadyMarked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Signed', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
              )
            else if (isSelected)
              const Icon(Icons.radio_button_checked_rounded, color: AppColors.primary, size: 20)
            else
              const Icon(Icons.radio_button_off_rounded, color: AppColors.textSecondaryDark, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSignArea() {
    final dist = _distanceToSession();
    final withinRange = dist != null && dist <= 50;
    final alreadyMarked = _isMarked && _markedSessionId == _selectedSession?.id;

    return Column(
      children: [
        // Distance indicator
        if (dist != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: withinRange
                  ? AppColors.success.withOpacity(0.08)
                  : AppColors.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: withinRange
                    ? AppColors.success.withOpacity(0.35)
                    : AppColors.danger.withOpacity(0.35),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  withinRange ? Icons.where_to_vote_rounded : Icons.wrong_location_rounded,
                  color: withinRange ? AppColors.success : AppColors.danger,
                  size: 20,
                ),
                const SizedBox(width: 10),
                RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14),
                    children: [
                      TextSpan(
                        text: '${dist.toStringAsFixed(0)}m away',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: withinRange ? AppColors.success : AppColors.danger,
                        ),
                      ),
                      TextSpan(
                        text: withinRange ? '  ✓ Within 50m range' : '  — Must be within 50m',
                        style: TextStyle(
                          color: withinRange ? AppColors.success : AppColors.danger,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Mark attendance button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (!withinRange || _isMarking || alreadyMarked || _isCheckingLocation)
                ? null
                : _markAttendance,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: alreadyMarked ? AppColors.success : AppColors.primary,
              disabledBackgroundColor: AppColors.glassBgDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            icon: _isMarking
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Icon(alreadyMarked ? Icons.done_all_rounded : Icons.fingerprint_rounded),
            label: Text(
              alreadyMarked
                  ? 'Attendance Signed'
                  : !withinRange && dist != null
                      ? 'Too Far Away (${dist.toStringAsFixed(0)}m)'
                      : 'Verify & Sign Attendance',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your exact coordinates & distance from session will be recorded.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondaryDark),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
