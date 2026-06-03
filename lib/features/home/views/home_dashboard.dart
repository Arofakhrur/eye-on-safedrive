import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/services/sos_service.dart';
import 'package:eyeon/features/home/widgets/safety_score_card.dart';
import 'package:eyeon/features/home/widgets/stat_card.dart';
import 'package:eyeon/features/home/widgets/sos_button.dart';

class HomeDashboard extends StatefulWidget {
  final VoidCallback? onProfileTap;
  const HomeDashboard({super.key, this.onProfileTap});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  String _userName = 'Rider';
  String? _avatarUrl;

  // Dynamic stats
  int _totalRides = 0;
  int _totalAlerts = 0;
  int _safeRides = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadStats();
  }

  void _loadUserProfile() {
    final user = SupabaseService().currentUser;
    if (user != null && user.userMetadata != null) {
      final name = user.userMetadata!['full_name'] ?? user.userMetadata!['name'];
      final avatar = user.userMetadata!['avatar_url'] ?? user.userMetadata!['picture'];
      setState(() {
        if (name != null) _userName = name;
        _avatarUrl = avatar;
      });
    }
  }

  Future<void> _loadStats() async {
    try {
      final rides = await SupabaseService().getRideHistory();
      int alerts = 0;
      int safe = 0;
      for (final ride in rides) {
        final micro = (ride['microsleep_alerts'] ?? 0) as int;
        final accident = (ride['accident_alerts'] ?? 0) as int;
        alerts += micro + accident;
        if (micro == 0 && accident == 0) safe++;
      }
      if (mounted) {
        setState(() {
          _totalRides = rides.length;
          _totalAlerts = alerts;
          _safeRides = safe;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildGreetingHeader(),
              const SizedBox(height: 28),
              const SafetyScoreCard(),
              const SizedBox(height: 24),
              _buildQuickStatsHeader(),
              const SizedBox(height: 16),
              _buildStatsRow(),
              const SizedBox(height: 32),
              SOSButton(onTap: () => SOSService().callNationalEmergency()),
              const SizedBox(height: 24),
              _buildRecentActivityHeader(),
              const SizedBox(height: 16),
              _totalRides == 0
                  ? _buildEmptyActivityPlaceholder()
                  : _buildRecentRidesSummary(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome Back 👋',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _userName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: widget.onProfileTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFD7F454),
              shape: BoxShape.circle,
              image: _avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _avatarUrl == null
                ? const Icon(Icons.person_rounded, color: Colors.black, size: 24)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatsHeader() {
    return Text(
      'Quick Stats',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.black,
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            icon: Icons.timer_outlined,
            label: 'Total Rides',
            value: '$_totalRides',
            color: const Color(0xFFD7F454),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            icon: Icons.warning_amber_rounded,
            label: 'Alerts',
            value: '$_totalAlerts',
            color: Colors.orange.shade100,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            icon: Icons.check_circle_outline,
            label: 'Safe Rides',
            value: '$_safeRides',
            color: Colors.green.shade100,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityHeader() {
    return Text(
      'Recent Activity',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.black,
      ),
    );
  }

  Widget _buildEmptyActivityPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'No recent activity',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black38,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start a ride to see logs here',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRidesSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFD7F454).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.route_rounded, color: Colors.black87, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_totalRides perjalanan tercatat',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '$_safeRides aman • $_totalAlerts peringatan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.black26),
        ],
      ),
    );
  }
}
