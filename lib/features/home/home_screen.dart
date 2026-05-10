import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart'; // For themeNotifier
import '../units/units_screen.dart'; // To navigate to units

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const HomeScreen({Key? key, this.onNavigate}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _firstName = '';
  String? _registrationNumber;
  List<Map<String, dynamic>> _units = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _firstName = userDoc.data()!['firstName'] ?? '';
          _registrationNumber = userDoc.data()!['registrationNumber'];
        });

        final regNumber = userDoc.data()!['registrationNumber'];
        final unitsSnapshot = await FirebaseFirestore.instance
            .collection('units')
            .where('registrationNumber', isEqualTo: regNumber)
            .get();

        setState(() {
          _units = unitsSnapshot.docs.map((doc) => doc.data()).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good Morning, ${_firstName.isNotEmpty ? _firstName : 'User'} 👋',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentMode, child) {
            final isDark = currentMode == ThemeMode.dark ||
                (currentMode == ThemeMode.system && Theme.of(context).brightness == Brightness.dark);
            return GestureDetector(
              onTap: () {
                themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
              },
              child: Container(
                width: 60,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isDark ? AppColors.primary.withOpacity(0.2) : Colors.grey.shade300,
                  border: Border.all(color: AppColors.glassBorderLight),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      left: isDark ? 30 : 2,
                      right: isDark ? 2 : 30,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: Icon(
                          isDark ? Icons.nightlight_round : Icons.wb_sunny,
                          size: 16,
                          color: isDark ? AppColors.primary : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAttendanceCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _registrationNumber != null
          ? FirebaseFirestore.instance
              .collection('attendance')
              .where('registrationNumber', isEqualTo: _registrationNumber)
              .snapshots()
          : const Stream.empty(),
      builder: (context, snap) {
        final present = snap.data?.docs.length ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('sessions').snapshots(),
          builder: (context, sessionSnap) {
            final attendedCodes = (snap.data?.docs ?? [])
                .map((d) => (d.data() as Map<String, dynamic>)['unitCode'] as String? ?? '')
                .toSet();
            final relevant = (sessionSnap.data?.docs ?? []).where((s) {
              return attendedCodes.contains(
                  (s.data() as Map<String, dynamic>)['unitCode'] as String? ?? '');
            }).length;
            final total = relevant > present ? relevant : present;
            final absent = (total - present).clamp(0, total);
            final rate = total > 0 ? (present / total * 100) : 0.0;

            return GlassCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Donut ring
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: total > 0 ? present / total : 0,
                          strokeWidth: 6,
                          backgroundColor: AppColors.danger.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                          strokeCap: StrokeCap.round,
                        ),
                        Text(
                          '${rate.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overall Attendance',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success)),
                            const SizedBox(width: 6),
                            Text('Present: $present', style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(width: 14),
                            Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.danger)),
                            const SizedBox(width: 6),
                            Text('Absent: $absent', style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildQuickAction(String title, IconData icon, Gradient gradient, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.last.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem(Map<String, dynamic> unit) {
    final unitName = unit['unitName'] ?? 'Unknown Unit';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(unitName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(unit['unitCode'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Upcoming', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: AuroraBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopHeader(),
                      const SizedBox(height: 32),
                      _buildAttendanceCard(),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const UnitsScreen()));
                            },
                            child: const Text('My Units', style: TextStyle(color: AppColors.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildQuickAction('Mark\nAttendance', Icons.location_on, AppColors.blueGradient, () {
                            if (widget.onNavigate != null) widget.onNavigate!(1);
                          }),
                          _buildQuickAction('View\nAnalytics', Icons.bar_chart, AppColors.pinkGradient, () {
                            if (widget.onNavigate != null) widget.onNavigate!(2);
                          }),
                          _buildQuickAction('My\nProfile', Icons.person, AppColors.greenGradient, () {
                            if (widget.onNavigate != null) widget.onNavigate!(3);
                          }),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Text('Registered Units', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      if (_units.isEmpty)
                        const Center(child: Text('No units registered yet.', style: TextStyle(color: Colors.grey)))
                      else
                        ..._units.map((u) => _buildStatusItem(u)).toList(),
                      const SizedBox(height: 80), // padding for bottom nav
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
