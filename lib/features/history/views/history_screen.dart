import 'package:eyeon/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/widgets/eyeon_header.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:eyeon/core/utils/mock_data.dart';

import 'package:eyeon/features/history/logic/history_controller.dart';
import 'package:eyeon/features/history/widgets/history_widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryController _controller = HistoryController();
  bool _showAll = false;

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
        child: Column(
        children: [
          const SizedBox(height: 16),
          EyeOnHeader(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Riwayat Perjalanan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return CategoryFilter(
                selectedCategory: _controller.selectedCategory,
                onCategorySelected: (cat) {
                  _controller.setSelectedCategory(cat);
                  setState(() { _showAll = false; });
                },
              );
            },
          ),
          
          Expanded(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final bool isLoading = _controller.isLoading;
                final logs = isLoading ? MockData.fakeRideLogs : _controller.rideLogs;
                
                final filteredLogs = isLoading 
                    ? logs
                    : _controller.filterLogs(logs);

                if (!isLoading && filteredLogs.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _controller.refreshHistory,
                    color: AppColors.textPrimary,
                    backgroundColor: AppColors.background,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.7,
                        alignment: Alignment.center,
                        child: const HistoryEmptyState(),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _controller.refreshHistory,
                  color: AppColors.textPrimary,
                  backgroundColor: AppColors.background,
                  child: Skeletonizer(
                    enabled: isLoading,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      itemCount: _showAll ? filteredLogs.length : (filteredLogs.length > 5 ? 6 : filteredLogs.length),
                      itemBuilder: (context, index) {
                        if (!_showAll && filteredLogs.length > 5 && index == 5) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _showAll = true;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text(
                                'Tampilkan Semua',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }
                        
                        return HistoryCard(
                          log: filteredLogs[index],
                          loadIncidents: _controller.loadIncidentsForRide,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}