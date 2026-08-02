import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../shared/widgets/primary_button.dart';
import 'widgets/onboarding_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = const [
    OnboardingPageData(
      icon: Icons.menu_book_rounded,
      title: 'Learn',
      description:
          'Access courses, past questions, and study resources built for every level — from university to JAMB, WAEC, and NECO.',
      accent: AppColors.primaryBlue,
    ),
    OnboardingPageData(
      icon: Icons.groups_rounded,
      title: 'Connect',
      description:
          'Join a community of learners. Share notes, ask questions, and grow together with students across schools.',
      accent: AppColors.secondaryIndigo,
    ),
    OnboardingPageData(
      icon: Icons.trending_up_rounded,
      title: 'Grow',
      description:
          'Track your progress, get AI-powered tutoring, and build the skills that take you from where you are to where you\'re going.',
      accent: AppColors.accentGreen,
    ),
  ];

  void _goToAuth() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 20, top: 8),
                child: TextButton(
                  onPressed: _goToAuth,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) =>
                    OnboardingPage(data: _pages[index]),
              ),
            ),
            SmoothPageIndicator(
              controller: _pageController,
              count: _pages.length,
              effect: const ExpandingDotsEffect(
                activeDotColor: AppColors.primaryBlue,
                dotColor: Color(0xFFE2E8F0),
                dotHeight: 8,
                dotWidth: 8,
                expansionFactor: 3,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: PrimaryButton(
                label: isLastPage ? 'Get Started' : 'Next',
                onPressed: () {
                  if (isLastPage) {
                    _goToAuth();
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
