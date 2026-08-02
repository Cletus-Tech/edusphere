import 'package:flutter/material.dart';
import 'learning_materials/learning_library_screen.dart';

/// The Learn tab. Stage 3.5 replaces the "coming soon" placeholder with
/// the real Learning Materials Module — the central content library for
/// University coursework, JAMB, WAEC, and NECO prep. CBT practice and
/// video classes remain planned additions on top of this same tab.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LearningLibraryScreen();
  }
}
