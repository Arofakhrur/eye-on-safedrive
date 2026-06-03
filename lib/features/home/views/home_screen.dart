import 'package:flutter/material.dart';
import 'package:eyeon/features/home/views/home_dashboard.dart';
import 'package:eyeon/features/activity/views/activity_screen.dart';
import 'package:eyeon/features/history/views/history_screen.dart';
import 'package:eyeon/features/profile/views/profile_screen.dart';
import 'package:eyeon/features/monitoring/views/monitoring_screen.dart';
import 'package:eyeon/features/home/widgets/eyeon_bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeDashboard(onProfileTap: () => _onTabTapped(4)),
      const ActivityScreen(),
      const SizedBox.shrink(), // placeholder for the center "Start Ride" button
      const HistoryScreen(),
      const ProfileScreen(),
    ];
  }

  void _onTabTapped(int index) {
    if (index == 2) return; // center button handled separately
    setState(() => _currentIndex = index);
  }

  void _onStartRide() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MonitoringScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      extendBody: true,
      bottomNavigationBar: EyeonBottomNavBar(
        currentIndex: _currentIndex,
        onTabTapped: _onTabTapped,
        onStartRide: _onStartRide,
      ),
    );
  }
}
