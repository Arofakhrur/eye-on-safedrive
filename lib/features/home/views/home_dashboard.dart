import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/services/sos_service.dart';
import 'package:eyeon/features/home/widgets/safety_score_card.dart';
import 'package:eyeon/features/home/widgets/stat_card.dart';
import 'package:eyeon/features/home/widgets/sos_button.dart';
import 'package:eyeon/core/widgets/eyeon_header.dart';
import 'package:eyeon/core/models/emergency_contact.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/theme/app_theme.dart';

class HomeDashboard extends StatefulWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onHistoryTap;
  const HomeDashboard({super.key, this.onProfileTap, this.onHistoryTap});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  String _userName = 'Rider';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
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
              const EyeOnHeader(),
              _buildGreetingHeader(),
              const SizedBox(height: 28),
              const SafetyScoreCard(),
              const SizedBox(height: 24),
              _buildSectionHeader('Quick Tiles'),
              const SizedBox(height: 16),
              SOSButton(onTap: () => SOSService().showEmergencyContactSheet(context)),
              const SizedBox(height: 24),
              _buildSectionHeader('Emergency Contact'),
              const SizedBox(height: 16),
              _buildEmergencyContacts(),
              const SizedBox(height: 24),
              _buildSectionHeader('Recent Activity'),
              const SizedBox(height: 16),
              _buildDynamicRecentActivityCard(),
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
              color: AppColors.primary,
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.black54,
      ),
    );
  }

  Widget _buildEmergencyContacts() {
    return FutureBuilder<List<EmergencyContact>>(
      future: SupabaseService().getEmergencyContacts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        
        final contacts = snapshot.data ?? [];
        
        if (contacts.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                const Icon(Icons.contact_phone_outlined, color: Colors.black26, size: 32),
                const SizedBox(height: 12),
                Text(
                  'Belum ada kontak darurat',
                  style: GoogleFonts.plusJakartaSans(color: Colors.black45, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.setup),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Atur Kontak', style: GoogleFonts.plusJakartaSans(color: Colors.black87, fontWeight: FontWeight.w700)),
                )
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: contacts.length,
          itemBuilder: (context, index) {
            final contact = contacts[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: Colors.black87),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        Text(
                          contact.phone,
                          style: GoogleFonts.plusJakartaSans(color: Colors.black54, fontSize: 13),
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

  Widget _buildDynamicRecentActivityCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService().streamRideHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200, width: 2),
            ),
            child: const Center(
              child: Icon(Icons.check_box_outline_blank_rounded, color: Colors.black26, size: 36),
            ),
          );
        }

        final rides = snapshot.data!;
        int totalRides = rides.length;
        int totalAlerts = 0;
        int safeRides = 0;

        for (final ride in rides) {
          final micro = (ride['microsleep_alerts'] ?? 0) as int;
          final accident = (ride['accident_alerts'] ?? 0) as int;
          totalAlerts += micro + accident;
          if (micro == 0 && accident == 0) safeRides++;
        }

        return GestureDetector(
          onTap: widget.onHistoryTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: AppColors.primary, // Neon green badge
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.route_rounded, color: Colors.black, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalRides Perjalanan Tercatat',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$safeRides aman • $totalAlerts Peringatan',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.black26),
              ],
            ),
          ),
        );
      },
    );
  }
}
