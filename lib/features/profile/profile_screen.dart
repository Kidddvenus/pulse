import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_colors.dart';
import '../auth/login_screen.dart';
import '../../main.dart'; // For themeNotifier

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  Future<Map<String, dynamic>?> _getUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data();
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.glassBgDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, IconData icon, String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.surfaceContainerHighest)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (trailing != null) trailing,
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
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, currentMode, child) {
              final isDark = currentMode == ThemeMode.dark ||
                  (currentMode == ThemeMode.system && Theme.of(context).brightness == Brightness.dark);
              return Padding(
                padding: const EdgeInsets.only(right: 24),
                child: GestureDetector(
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
                ),
              );
            },
          ),
        ],
      ),
      body: AuroraBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _getUserData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: CircularProgressIndicator(),
                  ));
                }

                final data = snapshot.data;
                final firstName = data?['firstName'] ?? '';
                final lastName = data?['lastName'] ?? '';
                final email = data?['email'] ?? '';
                final regNumber = data?['registrationNumber'] ?? '';

                final isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.blueGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '$firstName $lastName',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                            ),
                            child: Text(
                              regNumber,
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            email,
                            style: TextStyle(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Attendance stats (live from Firestore) ──────────────
                    StreamBuilder<QuerySnapshot>(
                      stream: regNumber.isNotEmpty
                          ? FirebaseFirestore.instance
                              .collection('attendance')
                              .where('registrationNumber', isEqualTo: regNumber)
                              .snapshots()
                          : const Stream.empty(),
                      builder: (context, attSnap) {
                        final present = attSnap.data?.docs.length ?? 0;

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('sessions')
                              .snapshots(),
                          builder: (context, sessSnap) {
                            // Count sessions whose unitCode this student has attended
                            final attendedCodes = (attSnap.data?.docs ?? [])
                                .map((d) =>
                                    (d.data() as Map<String, dynamic>)['unitCode']
                                        as String? ??
                                        '')
                                .toSet();
                            final relevant = (sessSnap.data?.docs ?? []).where((s) {
                              return attendedCodes.contains(
                                  (s.data() as Map<String, dynamic>)['unitCode']
                                      as String? ??
                                      '');
                            }).length;
                            final total = math.max(relevant, present);
                            final absent = math.max(0, total - present);
                            final rate = total > 0
                                ? (present / total * 100)
                                : 0.0;

                            return Row(
                              children: [
                                _buildStatCard('$present', 'Present', AppColors.success),
                                _buildStatCard('$absent', 'Absent', AppColors.danger),
                                _buildStatCard(
                                  '${rate.toStringAsFixed(0)}%',
                                  'Rate',
                                  const Color(0xFF6366F1),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildInfoTile(context, Icons.person, 'Full Name', '$firstName $lastName'),
                          const Divider(height: 1, color: AppColors.glassBorderDark),
                          _buildInfoTile(context, Icons.email, 'Email', email),
                          const Divider(height: 1, color: AppColors.glassBorderDark),
                          _buildInfoTile(context, Icons.badge, 'Reg. Number', regNumber),
                          const Divider(height: 1, color: AppColors.glassBorderDark),
                          _buildInfoTile(
                            context,
                            Icons.verified,
                            'Email Verified',
                            isEmailVerified ? 'Verified' : 'Unverified',
                            trailing: isEmailVerified
                                ? Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.check, color: AppColors.success, size: 16),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    TextButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.logout, color: AppColors.danger),
                      label: const Text('Log Out', style: TextStyle(color: AppColors.danger, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 80), // bottom nav padding
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
