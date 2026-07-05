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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
        children: [
          const SizedBox(height: 24),
          const EyeOnHeader(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Riwayat Perjalanan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return CategoryFilter(
                selectedCategory: _controller.selectedCategory,
                onCategorySelected: _controller.setSelectedCategory,
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
                    color: Colors.black,
                    backgroundColor: Colors.white,
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
                  color: Colors.black,
                  backgroundColor: Colors.white,
                  child: Skeletonizer(
                    enabled: isLoading,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      itemCount: filteredLogs.length,
                      itemBuilder: (context, index) {
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
