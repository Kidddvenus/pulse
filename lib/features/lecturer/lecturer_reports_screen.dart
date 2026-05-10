import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_colors.dart';
import '../auth/login_screen.dart';
import 'lecturer_session_screen.dart';

class LecturerReportsScreen extends StatefulWidget {
  final String lecturerName;
  const LecturerReportsScreen({Key? key, required this.lecturerName}) : super(key: key);

  @override
  State<LecturerReportsScreen> createState() => _LecturerReportsScreenState();
}

class _LecturerReportsScreenState extends State<LecturerReportsScreen>
    with TickerProviderStateMixin {
  String? _selectedUnit;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _headerController;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerFade = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildSignOutDialog(ctx),
    );
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  Widget _buildSignOutDialog(BuildContext ctx) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.danger, size: 22),
            SizedBox(width: 10),
            Text('Sign Out', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out of the lecturer portal?',
          style: TextStyle(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondaryDark)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LecturerSessionScreen(lecturerName: widget.lecturerName),
          ),
        ),
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.play_circle_fill_rounded),
        label: const Text('Start Session', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 4,
      ),
      body: AuroraBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('attendance')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              final allDocs = snapshot.data?.docs ?? [];

              // Derive unique units for filter
              final unitSet = <String>{};
              for (var doc in allDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final code = data['unitCode'] as String?;
                if (code != null && code.isNotEmpty) unitSet.add(code);
              }
              final units = unitSet.toList()..sort();

              // Filter docs
              List<QueryDocumentSnapshot> filtered = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final unitCode = data['unitCode'] as String? ?? '';
                final unitName = data['unitName'] as String? ?? '';
                final regNum = data['registrationNumber'] as String? ?? '';
                final studentName = data['studentName'] as String? ?? '';

                final matchesUnit = _selectedUnit == null || unitCode == _selectedUnit;
                final matchesSearch = _searchQuery.isEmpty ||
                    regNum.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    studentName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    unitName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    unitCode.toLowerCase().contains(_searchQuery.toLowerCase());

                return matchesUnit && matchesSearch;
              }).toList();

              // Stats
              final totalSessions = filtered.length;
              final uniqueStudents = <String>{};
              final unitAttendanceMap = <String, int>{};
              for (var doc in filtered) {
                final data = doc.data() as Map<String, dynamic>;
                final reg = data['registrationNumber'] as String? ?? '';
                final code = data['unitCode'] as String? ?? 'Unknown';
                if (reg.isNotEmpty) uniqueStudents.add(reg);
                unitAttendanceMap[code] = (unitAttendanceMap[code] ?? 0) + 1;
              }

              return CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _headerFade,
                      child: _buildHeader(context, totalSessions, uniqueStudents.length, units),
                    ),
                  ),

                  // Stats Row
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _headerFade,
                      child: _buildStatsRow(context, totalSessions, uniqueStudents.length, units.length),
                    ),
                  ),

                  // Unit Breakdown
                  if (unitAttendanceMap.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildUnitBreakdown(context, unitAttendanceMap),
                    ),

                  // Filter bar
                  SliverToBoxAdapter(
                    child: _buildFilterBar(context, units),
                  ),

                  // Records header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.list_alt_rounded, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Attendance Records',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${filtered.length} records',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Loading / Empty / List
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  else if (snapshot.hasError)
                    SliverFillRemaining(
                      child: Center(
                        child: Text('Error: ${snapshot.error}',
                            style: const TextStyle(color: AppColors.danger)),
                      ),
                    )
                  else if (filtered.isEmpty)
                    SliverFillRemaining(
                      child: _buildEmptyState(),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final data = filtered[i].data() as Map<String, dynamic>;
                          return _buildRecordCard(ctx, data, i);
                        },
                        childCount: filtered.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int total, int students, List<String> units) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), AppColors.primary],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryDark.withOpacity(0.8),
                  ),
                ),
                Text(
                  widget.lecturerName.isNotEmpty ? widget.lecturerName : 'Lecturer',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Sign Out
          GestureDetector(
            onTap: _signOut,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger.withOpacity(0.3)),
              ),
              child: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, int sessions, int students, int units) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _buildStatCard(context, 'Total\nSessions', sessions.toString(), Icons.event_available_rounded, AppColors.primary, const [Color(0xFF6366F1), AppColors.primary])),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(context, 'Unique\nStudents', students.toString(), Icons.people_rounded, AppColors.success, const [Color(0xFF00E676), Color(0xFF00B8D4)])),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(context, 'Active\nUnits', units.toString(), Icons.book_rounded, AppColors.warning, const [Color(0xFFFFD740), Color(0xFFFF8A00)])),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color, List<Color> gradientColors) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                gradientColors[0].withOpacity(0.15),
                gradientColors[1].withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondaryDark,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitBreakdown(BuildContext context, Map<String, int> unitMap) {
    final sorted = unitMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.first.value.toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Attendance by Unit',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sorted.take(5).map((entry) => _buildUnitBar(context, entry.key, entry.value, maxVal)),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitBar(BuildContext context, String unit, int count, double max) {
    final ratio = count / max;
    final colors = [
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      const Color(0xFFC084FC),
      AppColors.danger,
    ];
    final colorIndex = unit.hashCode.abs() % colors.length;
    final barColor = colors[colorIndex];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(unit, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('$count', style: TextStyle(fontSize: 13, color: barColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: barColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, List<String> units) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        children: [
          // Search
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              hintText: 'Search by student, reg no, or unit...',
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
          const SizedBox(height: 12),
          // Unit filter chips
          if (units.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFilterChip('All Units', null),
                  ...units.map((u) => _buildFilterChip(u, u)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value) {
    final isSelected = _selectedUnit == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedUnit = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF6366F1), AppColors.primary],
                  )
                : null,
            color: isSelected ? null : AppColors.glassBgDark.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.transparent : AppColors.glassBorderDark,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : AppColors.textSecondaryDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, Map<String, dynamic> data, int index) {
    final timestamp = data['timestamp'] as Timestamp?;
    final date = timestamp?.toDate();
    final dateStr = date != null ? DateFormat('MMM d, yyyy').format(date) : '—';
    final timeStr = date != null ? DateFormat('hh:mm a').format(date) : '—';
    final unitCode = data['unitCode'] as String? ?? 'N/A';
    final unitName = data['unitName'] as String? ?? '';
    final regNum = data['registrationNumber'] as String? ?? 'Unknown';
    final studentName = data['studentName'] as String? ?? '';
    final location = data['locationName'] as String? ?? data['location'] as String? ?? 'No location';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassBgDark.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorderDark),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Index indicator
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: const Center(
                      child: Icon(Icons.check_circle_outline_rounded,
                          color: AppColors.success, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Unit
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                unitCode,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                unitName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Student
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded,
                                size: 14, color: AppColors.textSecondaryDark),
                            const SizedBox(width: 5),
                            Text(
                              studentName.isNotEmpty ? studentName : regNum,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            if (studentName.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• $regNum',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondaryDark),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Location & Time
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 13, color: AppColors.textSecondaryDark),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondaryDark),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Date/Time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(dateStr,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondaryDark)),
                      const SizedBox(height: 2),
                      Text(timeStr,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondaryDark)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inbox_outlined, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'No records found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedUnit != null
                ? 'Try adjusting your search or filter'
                : 'No attendance has been recorded yet',
            style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty || _selectedUnit != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedUnit = null;
                });
              },
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Clear Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
