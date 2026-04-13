import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_colors.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? _registrationNumber;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRegistration();
  }

  Future<void> _loadUserRegistration() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;//Loads the current user according to sign in details
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();//After loading the current
      //user that has logged in, the id is used in the users collection to load the registration number
      if (doc.exists && mounted) {
        setState(() {
          _registrationNumber = doc.data()?['registrationNumber'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading registration number: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStatBox(BuildContext context, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorderLight),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: Theme.of(context).colorScheme.surfaceContainerHighest, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(BuildContext context, Map<String, dynamic> log) {
    final timestamp = log['timestamp'] as Timestamp?;
    final timeStr = timestamp != null 
        ? DateFormat('MMM d, hh:mm a').format(timestamp.toDate())
        : 'Unknown time';
        
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${log['unitCode']}: ${log['unitName']}', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$timeStr • ${log['locationName'] ?? 'No location name'}', 
                  style: TextStyle(color: Theme.of(context).colorScheme.surfaceContainerHighest, fontSize: 12),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AuroraBackground(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_registrationNumber == null) {
      return const AuroraBackground(
        child: Center(child: Text('User Profile not found')),
      );
    }

    return AuroraBackground(
      child: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('attendance')
              .where('registrationNumber', isEqualTo: _registrationNumber)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];
            final attendanceCount = docs.length;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Your Analytics',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    
                    _buildStatBox(context, 'Classes Attended', attendanceCount.toString()),
                    
                    const SizedBox(height: 32),
                    Text(
                      'Recent Logs',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    if (docs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: Text('No attendance logs found.', style: TextStyle(color: Colors.grey))),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          return _buildLogItem(context, data);
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
