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
import '../reports/reports_screen.dart';
import '../units/units_screen.dart';
import '../profile/profile_screen.dart';
import '../../core/utils/biometric_helper.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isCheckingLocation = true;
  bool _isMarking = false;
  bool _isMarked = false;
  
  Position? _currentPosition;
  String _currentAddress = "Identifying location...";
  
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  
  List<Map<String, dynamic>> _units = [];
  Map<String, dynamic>? _selectedUnit;
  bool _isLoadingUnits = true;
  
  String? _registrationNumber;
  String? _firstName;
  String? _lastName;

  late AnimationController _pulseController;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _loadUserDataAndUnits();
    _checkLocation();
    
    // Update clock every second
    Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserDataAndUnits() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists && mounted) {
        final userData = userDoc.data()!;
        _registrationNumber = userData['registrationNumber'];
        _firstName = userData['firstName'];
        _lastName = userData['lastName'];

        final unitsSnapshot = await FirebaseFirestore.instance
            .collection('units')
            .where('registrationNumber', isEqualTo: _registrationNumber)
            .get();

        setState(() {
          _units = unitsSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
          if (_units.isNotEmpty) {
            _selectedUnit = _units.first;
          }
          _isLoadingUnits = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading units: $e");
      if (mounted) setState(() => _isLoadingUnits = false);
    }
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];
      if (mounted) {
        setState(() {
          _currentAddress = "${place.name}, ${place.street}, ${place.subLocality}, ${place.locality}";
        });
      }
    } catch (e) {
      debugPrint("Error getting address: $e");
      if (mounted) setState(() => _currentAddress = "Address unavailable");
    }
  }

  Future<void> _checkLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    setState(() {
      _isCheckingLocation = true;
      _currentAddress = "Identifying location...";
    });

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        setState(() => _isCheckingLocation = false);
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          setState(() => _isCheckingLocation = false);
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied.')),
        );
        setState(() => _isCheckingLocation = false);
      }
      return;
    }

    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      if (_currentPosition != null) {
        _getAddressFromLatLng(_currentPosition!);

        if (mounted) {
          setState(() {
            _isCheckingLocation = false;
            _markers = {
              Marker(
                markerId: const MarkerId('currentLocation'),
                position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                infoWindow: const InfoWindow(title: 'Your Exact Location'),
              ),
            };
          });
          
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              18,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
      if (mounted) setState(() => _isCheckingLocation = false);
    }
  }

  void _markAttendance() async {
    if (_selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a unit first.')),
      );
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Precise location required.')),
      );
      return;
    }

    final isAuthenticated = await BiometricHelper.authenticate('Please authenticate to verify it is you');
    if (!isAuthenticated) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Authentication required to mark attendance.')),
         );
       }
       return;
    }

    setState(() => _isMarking = true);
    
    try {
      await FirebaseFirestore.instance.collection('attendance').add({
        'registrationNumber': _registrationNumber,
        'firstName': _firstName,
        'lastName': _lastName,
        'unitCode': _selectedUnit!['unitCode'],
        'unitName': _selectedUnit!['unitName'],
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
        'locationName': _currentAddress,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isMarking = false;
          _isMarked = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance Logged Successfully!')),
        );
      }
    } catch (e) {
      debugPrint("Error logging attendance: $e");
      if (mounted) {
        setState(() => _isMarking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildStatusBanner() {
    if (_isCheckingLocation) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Identifying location...', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (_currentPosition != null ? AppColors.success : AppColors.danger).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_currentPosition != null ? Icons.location_on : Icons.location_off, 
                color: _currentPosition != null ? AppColors.success : AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Text(
                _currentPosition != null ? 'Location Found' : 'Location Not Found', 
                style: TextStyle(
                  color: _currentPosition != null ? AppColors.success : AppColors.danger, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _currentAddress,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          if (_currentPosition == null)
            TextButton(
              onPressed: _checkLocation,
              child: const Text('Retry GPS', style: TextStyle(color: AppColors.primary)),
            )
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(-1.286389, 36.817223), // Nairobi center as fallback
          zoom: 12,
        ),
        onMapCreated: (controller) => _mapController = controller,
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      ),
    );
  }

  Widget _buildBody() {
    if (_currentIndex == 1) return const ReportsScreen();
    if (_currentIndex == 2) return const UnitsScreen();
    if (_currentIndex == 3) return const ProfileScreen();

    return AuroraBackground(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: GlassCard(
            margin: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusBanner(),
                const SizedBox(height: 16),
                
                _buildMap(),
                const SizedBox(height: 24),

                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(_now),
                  style: TextStyle(color: Theme.of(context).colorScheme.surfaceContainerHighest, fontSize: 14),
                ),
                Text(
                  DateFormat('hh:mm:ss a').format(_now),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                if (_isLoadingUnits)
                  const CircularProgressIndicator()
                else if (_units.isEmpty)
                  const Text('No units registered. Go to "Units" tab.', style: TextStyle(color: AppColors.danger))
                else
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: _selectedUnit,
                    decoration: const InputDecoration(
                      labelText: 'Select Unit',
                      prefixIcon: Icon(Icons.menu_book),
                    ),
                    items: _units.map((unit) {
                      return DropdownMenuItem(
                        value: unit,
                        child: Text('${unit['unitCode']}: ${unit['unitName']}'),
                      );
                    }).toList(),
                    onChanged: _isMarked ? null : (value) => setState(() => _selectedUnit = value),
                  ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_currentPosition == null || _isMarked || _isMarking || _units.isEmpty) ? null : _markAttendance,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: _isMarked ? AppColors.success : AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    icon: _isMarking 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : Icon(_isMarked ? Icons.done_all : Icons.fingerprint),
                    label: Text(
                      _isMarked ? 'Attendance Logged' : 'Verify & Sign',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your exact coordinates and address will be logged.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
          border: Border(top: BorderSide(color: AppColors.glassBorderLight, width: 1)),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Attendance'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Units'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
