import 'package:flutter/material.dart';
import '../../theme/app_animations.dart';
import '../../theme/app_text_styles.dart';
import '../ai_tutor/ai_tutor_screen.dart';
import '../community/community_screen.dart';
import '../learn/learn_screen.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';

/// Bottom-nav shell. This is the only place the five main tabs are
/// wired together — feature screens themselves know nothing about
/// navigation, keeping each module independent and swappable.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  void _goToTab(int index) => setState(() => _currentIndex = index);

  late final List<Widget> _pages = [
    HomeScreen(onNavigateToTab: _goToTab),
    const LearnScreen(),
    const CommunityScreen(),
    const AiTutorScreen(),
    const ProfileScreen(),
  ];

  final List<_NavItem> _items = const [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded, label: 'Learn'),
    _NavItem(icon: Icons.groups_outlined, activeIcon: Icons.groups_rounded, label: 'Community'),
    _NavItem(icon: Icons.smart_toy_outlined, activeIcon: Icons.smart_toy_rounded, label: 'AI Tutor'),
    _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _AppBottomNavBar(
        currentIndex: _currentIndex,
        items: _items,
        onTap: _goToTab,
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Stage B3 — replaces the stock [BottomNavigationBar] with a custom
/// bar whose active tab gets a real indicator (a pill behind the
/// icon) instead of the previous "icon just changes color" treatment
/// the beautification audit flagged. Reads every color from
/// [BottomNavigationBarThemeData] (already fully defined for both
/// light and dark in `app_theme.dart`) rather than hardcoding
/// anything, so light/dark and any future theme tweak keep working
/// with zero changes here. `_currentIndex`/`_goToTab`/`_pages` logic
/// above is completely untouched — this is a presentation-only swap.
class _AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _AppBottomNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final navTheme = Theme.of(context).bottomNavigationBarTheme;
    final backgroundColor = navTheme.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
    final selectedColor = navTheme.selectedItemColor ?? Theme.of(context).colorScheme.primary;
    final unselectedColor = navTheme.unselectedItemColor ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: AppAnimations.fast,
                        curve: AppAnimations.standard,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? selectedColor.withOpacity(0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isSelected ? item.activeIcon : item.icon,
                          color: isSelected ? selectedColor : unselectedColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: AppAnimations.fast,
                        curve: AppAnimations.standard,
                        style: AppTextStyles.caption(isSelected ? selectedColor : unselectedColor)
                            .copyWith(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
                        child: Text(item.label),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
