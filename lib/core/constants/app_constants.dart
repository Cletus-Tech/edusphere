class AppConstants {
  AppConstants._();

  static const String appName = 'EduSphere';
  static const String appTagline = 'Learn. Connect. Succeed.';
  static const String welcomeTagline = 'Learn. Without Limits.';
  static const String welcomeSubtitle = 'Your all-in-one educational ecosystem';

  // Firestore collection names — centralized here so every service and
  // future feature (CBT, Community, Marketplace, Scholarships, etc.)
  // references the same source of truth instead of hardcoding strings.
  // Stage 1 (kept for backward compatibility — do not rename, several
  // Stage 1 screens/services already reference these):
  static const String usersCollection = 'users';
  static const String coursesCollection = 'courses';
  static const String categoriesCollection = 'categories';
  static const String postsCollection = 'posts'; // Community
  static const String progressCollection = 'progress';
  static const String schoolsCollection = 'schools'; // Universities/Polys/Colleges
  static const String examBoardsCollection = 'exam_boards'; // JAMB/WAEC/NECO
  // Unused anywhere in the codebase. Stage 4.8A's CBT Engine uses the
  // existing `questionsCollection` ('questions') for every exam type —
  // this constant is NOT the CBT question bank and is kept only so
  // nothing that already referenced this literal string breaks;
  // do not wire new code to it (would create the exact duplicate
  // question-collection situation the CBT spec says to avoid).
  static const String cbtQuestionsCollection = 'cbt_questions'; // future
  static const String aiConversationsCollection = 'ai_conversations';
  static const String marketplaceCollection = 'marketplace'; // future
  static const String scholarshipsCollection = 'scholarships'; // future

  // ---------------------------------------------------------------------
  // Stage 1.2 — Backend Architecture & Database Design
  //
  // Every collection EduSphere will ever need across every planned module
  // (Universities, Polytechnics, Colleges of Education, Secondary Schools,
  // JAMB/WAEC/NECO/Post-UTME, Professional Certifications, AI Tutor,
  // Community, Marketplace, Scholarships) is declared here up front so
  // no future stage has to restructure the database. Screens/repositories
  // must always reference these constants — never a raw string literal.
  // ---------------------------------------------------------------------

  // Identity & structure
  static const String institutionsCollection = 'institutions';
  static const String facultiesCollection = 'faculties';
  static const String departmentsCollection = 'departments';
  static const String levelsCollection = 'levels';
  static const String semestersCollection = 'semesters';
  static const String subjectsCollection = 'subjects';

  // Learning
  static const String learningContentCollection = 'learning_content';
  static const String examsCollection = 'exams';
  static const String questionsCollection = 'questions';
  // Stage 4.8A — CBT Engine Core.
  static const String examSessionsCollection = 'exam_sessions';
  static const String examAttemptsCollection = 'exam_attempts';

  // Stage 3.5 — Learning Materials Module: the official learning-content
  // system going forward. `learningContentCollection` above (Stage 1's
  // notes/assignments/timetables collection) is now DEPRECATED — see
  // `LearningContentModel`'s doc comment and
  // `docs/STAGE_3.5_LEARNING_MATERIALS_CHANGELOG.md` for the migration
  // path. It is kept read-only, never written to by new code, so
  // existing links/data don't 404 mid-migration.
  static const String learningMaterialsCollection = 'learning_materials';

  // Community
  static const String communitiesCollection = 'communities';
  static const String commentsCollection = 'comments';
  static const String reactionsCollection = 'reactions';
  static const String bookmarksCollection = 'bookmarks';

  // Engagement
  static const String notificationsCollection = 'notifications';
  static const String achievementsCollection = 'achievements';
  static const String badgesCollection = 'badges';
  static const String leaderboardCollection = 'leaderboard';

  // AI, moderation, insight
  static const String aiHistoryCollection = 'ai_history';
  static const String reportsCollection = 'reports';
  static const String analyticsCollection = 'analytics';

  // Remote configuration (EduSphere Control Center)
  static const String settingsCollection = 'settings';
  static const String bannersCollection = 'banners';
  static const String featureFlagsCollection = 'feature_flags';

  // Stage 1.3 — Contact Center & Payment Center
  static const String contactsCollection = 'contacts';
  static const String paymentMethodsCollection = 'payment_methods';

  // Well-known singleton documents inside `settings`.
  static const String brandingSettingsDoc = 'branding';
  static const String dashboardSettingsDoc = 'dashboard';
  static const String appSettingsDoc = 'app_config';
  static const String uploadSettingsDoc = 'uploads';

  // Stage 1.3 — Upload Engine history
  static const String uploadHistoryCollection = 'upload_history';

  // Stage 3.6.1 — Admin Productivity Pack: audit trail
  static const String auditLogsCollection = 'audit_logs';

  // Timing
  static const Duration splashDuration = Duration(milliseconds: 2200);
  static const Duration transitionDuration = Duration(milliseconds: 300);

  // Spacing scale — use these instead of magic numbers
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
}
