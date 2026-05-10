import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_colors.dart';

// ─── Donut Painter ────────────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final double presentRatio; // 0.0 – 1.0
  final Color presentColor;
  final Color absentColor;
  final Color trackColor;

  const _DonutPainter({
    required this.presentRatio,
    required this.presentColor,
    required this.absentColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.18;
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track (full circle background)
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (presentRatio <= 0) return;

    // Absent arc (drawn first so present overlaps cleanly)
    if (presentRatio < 1.0) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + (2 * math.pi * presentRatio),
        2 * math.pi * (1 - presentRatio),
        false,
        Paint()
          ..color = absentColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt,
      );
    }

    // Present arc
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * presentRatio,
      false,
      Paint()
        ..color = presentColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.presentRatio != presentRatio;
}

// ─── Reports Screen ───────────────────────────────────────────────────────────

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? _registrationNumber;
  int _totalSessions = 0;     // all active sessions that included this student's units
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _registrationNumber = doc.data()?['registrationNumber'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonutCard(int present, int absent, double rate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ratio = (present + absent) > 0 ? present / (present + absent) : 0.0;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.donut_large_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Attendance Overview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              // Donut
              SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(130, 130),
                      painter: _DonutPainter(
                        presentRatio: ratio,
                        presentColor: AppColors.success,
                        absentColor: AppColors.danger,
                        trackColor: (isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight)
                            .withOpacity(0.3),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${rate.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        Text(
                          'Rate',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendRow(AppColors.success, 'Present', present),
                    const SizedBox(height: 16),
                    _legendRow(AppColors.danger, 'Absent', absent),
                    const SizedBox(height: 16),
                    _legendRow(AppColors.primary, 'Total Sessions', _totalSessions),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildLogItem(BuildContext context, Map<String, dynamic> log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timestamp = log['timestamp'] as Timestamp?;
    final timeStr = timestamp != null
        ? DateFormat('MMM d, hh:mm a').format(timestamp.toDate())
        : 'Unknown time';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${log['unitCode'] ?? ''}: ${log['unitName'] ?? ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    decoration: TextDecoration.none,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$timeStr • ${log['locationName'] ?? 'No location'}',
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontSize: 11,
                    decoration: TextDecoration.none,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Present',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AuroraBackground(
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_registrationNumber == null) {
      return const AuroraBackground(
        child: Center(child: Text('User profile not found')),
      );
    }

    return AuroraBackground(
      child: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          // 1. Fetch all sessions (to calculate total sessions for this student's units)
          stream: FirebaseFirestore.instance
              .collection('sessions')
              .snapshots(),
          builder: (context, sessionSnap) {
            return StreamBuilder<QuerySnapshot>(
              // 2. Fetch this student's attendance records
              stream: FirebaseFirestore.instance
                  .collection('attendance')
                  .where('registrationNumber', isEqualTo: _registrationNumber)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, attendanceSnap) {
                if (attendanceSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (attendanceSnap.hasError) {
                  return Center(child: Text('Error: ${attendanceSnap.error}'));
                }

                final attendanceDocs = attendanceSnap.data?.docs ?? [];
                final present = attendanceDocs.length;

                // Calculate total sessions that included units this student attends
                // (sessions whose unitCode matches any attendance record's unitCode)
                final attendedUnitCodes = attendanceDocs
                    .map((d) => (d.data() as Map<String, dynamic>)['unitCode'] as String? ?? '')
                    .toSet();

                final allSessions = sessionSnap.data?.docs ?? [];
                final relevantSessions = allSessions.where((s) {
                  final data = s.data() as Map<String, dynamic>;
                  return attendedUnitCodes.contains(data['unitCode'] as String? ?? '');
                }).length;

                // Total sessions = max(relevantSessions, present) — can't have attended more than total
                final total = math.max(relevantSessions, present);
                final absent = math.max(0, total - present);
                final rate = total > 0 ? (present / total) * 100 : 0.0;

                // Keep _totalSessions in sync without calling setState during build
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _totalSessions != total) {
                    setState(() => _totalSessions = total);
                  }
                });

                return CustomScrollView(
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Text(
                          'Your Analytics',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),

                    // Stat cards row
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Row(
                          children: [
                            _buildStatCard(
                              label: 'Present',
                              value: '$present',
                              color: AppColors.success,
                              icon: Icons.check_circle_rounded,
                            ),
                            const SizedBox(width: 10),
                            _buildStatCard(
                              label: 'Absent',
                              value: '$absent',
                              color: AppColors.danger,
                              icon: Icons.cancel_rounded,
                            ),
                            const SizedBox(width: 10),
                            _buildStatCard(
                              label: 'Rate',
                              value: '${rate.toStringAsFixed(0)}%',
                              color: AppColors.primary,
                              icon: Icons.trending_up_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Donut chart
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: _buildDonutCard(present, absent, rate),
                      ),
                    ),

                    // Recent logs header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.history_rounded, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Recent Logs',
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Logs list
                    if (attendanceDocs.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'No attendance logs yet.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverToBoxAdapter(
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: attendanceDocs.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final data = attendanceDocs[i].data() as Map<String, dynamic>;
                                return _buildLogItem(ctx, data);
                              },
                            ),
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
