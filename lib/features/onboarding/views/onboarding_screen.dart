import 'package:flutter/material.dart';
import 'package:eyeon/features/onboarding/widgets/onboarding_widgets.dart';
import 'package:eyeon/features/onboarding/logic/onboarding_controller.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final OnboardingController _controller = OnboardingController();

  @override
  void dispose() {
    _pageController.dispose();
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
            const OnboardingTopBar(),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  return PageView.builder(
                    controller: _pageController,
                    itemCount: _controller.pages.length,
                    onPageChanged: _controller.setCurrentPage,
                    itemBuilder: (context, index) {
                      return OnboardingPageWidget(
                        data: _controller.pages[index],
                        index: index,
                        totalPages: _controller.pages.length,
                        onNext: () => _controller.nextPage(context, _pageController),
                      );
                    },
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }
}
