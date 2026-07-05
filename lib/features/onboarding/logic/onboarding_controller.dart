import 'package:flutter/material.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/features/onboarding/widgets/onboarding_widgets.dart';

class OnboardingController extends ChangeNotifier {
  int _currentPage = 0;
  int get currentPage => _currentPage;

  final List<OnboardingData> pages = [
    OnboardingData(
      image: 'assets/images/onboarding-slide1.webp',
      title: 'Selamat Datang di\nEYE-ON!',
      subtitle:
          'Your Active Eye & Awareness Monitoring\nCompanion for a Safer Ride.',
      isFirstPage: true,
    ),
    OnboardingData(
      image: 'assets/images/onboarding-slide2.webp',
      title: 'Stay Awake While Riding‼',
      subtitle:
          'Many accidents happen due to drowsiness.\nEYE-ON helps you stay alert on the road.',
      isFirstPage: false,
    ),
    OnboardingData(
      image: 'assets/images/onboarding-slide3.webp',
      title: 'Instant Microsleep Warning',
      subtitle:
          'Warnings are sent directly to your screen\nto snap you back to alertness.',
      isFirstPage: false,
    ),
    OnboardingData(
      image: 'assets/images/onboarding-slide4.webp',
      title: 'Instant Emergency Response',
      subtitle: 'Quickly contact local emergency services with\nGPS location.',
      isFirstPage: false,
    ),
    OnboardingData(
      image: 'assets/images/onboarding-slide5.webp',
      title: 'Contact & Incident Log',
      subtitle:
          'Incidents are logged and emergency contacts\nare notified instantly.',
      isFirstPage: false,
    ),
  ];

  void setCurrentPage(int index) {
    _currentPage = index;
    notifyListeners();
  }

  void nextPage(BuildContext context, PageController pageController) {
    if (_currentPage < pages.length - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      PreferenceService().setFirstTime(false);
      Navigator.of(context).pushReplacementNamed(AppRoutes.permission);
    }
  }
}
