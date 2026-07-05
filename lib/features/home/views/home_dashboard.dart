import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/services/sos_service.dart';
import 'package:eyeon/features/home/widgets/safety_score_card.dart';

import 'package:eyeon/features/home/widgets/sos_button.dart';
import 'package:eyeon/core/widgets/eyeon_header.dart';
import 'package:eyeon/core/models/emergency_contact.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:eyeon/core/utils/mock_data.dart';

import 'package:eyeon/features/home/logic/home_controller.dart';

class HomeDashboard extends StatefulWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onHistoryTap;
  const HomeDashboard({super.key, this.onProfileTap, this.onHistoryTap});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final HomeController _controller = HomeController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              EyeOnHeader(),
              ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  return _buildGreetingHeader();
                }
              ),
              const SizedBox(height: 28),
              SafetyScoreCard(),
              const SizedBox(height: 24),
              _buildSectionHeader('Menu Cepat'),
              const SizedBox(height: 16),
              SOSButton(onTap: () => SOSService().showEmergencyContactSheet(context)),
              const SizedBox(height: 24),
              _buildSectionHeader('Kontak Darurat'),
              const SizedBox(height: 16),
              _buildEmergencyContacts(),
              const SizedBox(height: 24),
              _buildSectionHeader('Riwayat Perjalanan'),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo! 👋',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _controller.userName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: widget.onProfileTap,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              image: _controller.avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_controller.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: _controller.avatarUrl == null
                ? Icon(Icons.person_rounded, color: AppColors.textPrimary, size: 28)
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
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildEmergencyContacts() {
    return FutureBuilder<List<EmergencyContact>>(
      future: SupabaseService().getEmergencyContacts(),
      builder: (context, snapshot) {
        final bool isLoading = snapshot.connectionState == ConnectionState.waiting;
        final contacts = isLoading ? MockData.fakeContacts : (snapshot.data ?? []);
        
        if (!isLoading && contacts.isEmpty) {
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
                Icon(Icons.contact_phone_outlined, color: AppColors.textPrimary.withValues(alpha: 0.26), size: 32),
                SizedBox(height: 12),
                Text(
                  'Belum ada kontak darurat',
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary.withValues(alpha: 0.45), fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.setup),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Atur Kontak', style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary.withValues(alpha: 0.87), fontWeight: FontWeight.w700)),
                )
              ],
            ),
          );
        }

        return Skeletonizer(
          enabled: isLoading,
          child: ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: Offset(0, 4),
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
                      child: Icon(Icons.person, color: AppColors.textPrimary.withValues(alpha: 0.87)),
                    ),
                    SizedBox(width: 16),
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
                            style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDynamicRecentActivityCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService().streamRideHistory(),
      builder: (context, snapshot) {
        final bool isLoading = !snapshot.hasData;
        final rides = isLoading ? MockData.fakeRideLogs : snapshot.data!;
        
        if (!isLoading && rides.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200, width: 2),
            ),
            child: Center(
              child: Icon(Icons.history_rounded, color: AppColors.textPrimary.withValues(alpha: 0.26), size: 36),
            ),
          );
        }

        int totalRides = rides.length;
        int totalAlerts = 0;
        int safeRides = 0;

        for (final ride in rides) {
          final micro = (ride['microsleep_alerts'] ?? 0) as int;
          final accident = (ride['accident_alerts'] ?? 0) as int;
          totalAlerts += micro + accident;
          if (micro == 0 && accident == 0) safeRides++;
        }

        return Skeletonizer(
          enabled: isLoading,
          child: GestureDetector(
          onTap: widget.onHistoryTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: Offset(0, 4),
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
                  child: Icon(Icons.route_rounded, color: AppColors.textPrimary, size: 24),
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
                          color: AppColors.textPrimary.withValues(alpha: 0.87),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$safeRides Aman • $totalAlerts Peringatan',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary.withValues(alpha: 0.26)),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}