import 'package:flutter/material.dart';
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: _items
            .map((item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  activeIcon: Icon(item.activeIcon),
                  label: item.label,
                ))
            .toList(),
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
