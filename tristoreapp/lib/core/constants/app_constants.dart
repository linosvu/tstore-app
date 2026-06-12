import '../config/app_template_config.dart';

class AppConstants {
  // App Information — [AppTemplateConfig] is the single source of truth.
  static String get appName => AppTemplateConfig.appDisplayName;

  // Storage Keys
  static const String userPointsKey = 'user_points';
  static const String diaryEntriesKey = 'diary_entries';
  static const String timeEntriesKey = 'time_entries';
  static const String transactionsKey = 'transactions';
  static const String languageCodeKey = 'language_code';
  static const String firstLaunchKey = 'first_launch';
  static const String lastCheckInKey = 'last_check_in';
  static const String dailyCheckInStreakKey = 'daily_check_in_streak';
  static const String notificationsEnabledKey = 'notifications_enabled';
  static const String biometricEnabledKey = 'biometric_enabled';

  // Points System
  static const int dailyCheckInPoints = 5;
  static const int diaryEntryPoints = 2;
  static const int timeTrackingPoints = 3;
  static const int transactionPoints = 1;
  static const int weeklyBonusPoints = 20;
  static const int monthlyBonusPoints = 100;

  // Premium Features Costs
  static const int exportDataCost = 3;
  static const int advancedStatsCost = 2;
  static const int themeCustomizationCost = 1;
  static const int backupCloudCost = 5;
  static const int unlimitedDiaryEntriesCost = 10;
  static const int customCategoriesCost = 3;

  // Default Categories
  static const List<String> defaultCategories = [
    'food',
    'transport',
    'shopping',
    'entertainment',
    'health',
    'education',
    'work',
    'other',
  ];

  // Category Icons
  static const Map<String, String> categoryIcons = {
    'food': '🍽️',
    'transport': '🚗',
    'shopping': '🛒',
    'entertainment': '🎬',
    'health': '⚕️',
    'education': '📚',
    'work': '💼',
    'other': '📦',
  };

  // Limits and Constraints
  static const int maxDiaryContentLength = 5000;
  static const int maxTaskNameLength = 100;
  static const int maxTransactionDescriptionLength = 200;
  static const int maxPointsTransactionHistory = 100;
  static const int maxTimeEntriesDisplay = 50;
  static const int maxDiaryEntriesDisplay = 30;
  static const int maxTransactionsDisplay = 100;

  // Time Tracking
  static const Duration minTrackingDuration = Duration(minutes: 1);
  static const Duration maxTrackingDuration = Duration(hours: 12);
  static const int maxConcurrentTasks = 1;

  // Notification Settings
  static const String dailyReminderTime = '20:00'; // 8 PM
  static const String weeklyReviewTime = '09:00'; // 9 AM Sunday
  static const String monthlyReportTime = '10:00'; // 10 AM 1st of month

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double cardBorderRadius = 12.0;
  static const double buttonBorderRadius = 8.0;
  static const double dialogBorderRadius = 16.0;
  static const double bottomSheetBorderRadius = 20.0;

  // Animation Durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 400);
  static const Duration longAnimationDuration = Duration(milliseconds: 600);
  static const Duration splashAnimationDuration = Duration(milliseconds: 2000);

  // File Formats
  static const List<String> supportedExportFormats = ['CSV', 'PDF', 'JSON'];
  static const List<String> supportedImageFormats = ['JPG', 'PNG', 'WEBP'];

  // Currency
  static const String defaultCurrency = 'VND';
  static const String currencySymbol = '₫';
  static const List<String> supportedCurrencies = ['VND', 'USD', 'EUR', 'JPY'];

  // Localization
  static const List<String> supportedLanguages = ['vi', 'en'];
  static const String defaultLanguage = 'vi';

  // Date Formats
  static const String defaultDateFormat = 'dd/MM/yyyy';
  static const String defaultTimeFormat = 'HH:mm';
  static const String defaultDateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String iso8601DateFormat = 'yyyy-MM-ddTHH:mm:ss.SSSZ';

  // Backup and Sync
  static const int maxBackupSizeMB = 50;
  static const Duration backupRetentionPeriod = Duration(days: 90);
  static const int maxSyncRetries = 3;

  // Security
  static const int maxLoginAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);
  static const int pinCodeLength = 4;
  static const Duration sessionTimeout = Duration(minutes: 30);

  // Performance
  static const int maxCacheSize = 100;
  static const Duration cacheExpiration = Duration(hours: 24);
  static const int maxConcurrentOperations = 3;

  // Debug Settings
  static const bool enableDebugMode = false;
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;
  static const bool enablePerformanceMonitoring = true;

  // Feature Flags
  static const bool enableBiometricAuth = true;
  static const bool enableCloudBackup = true;
  static const bool enableNotifications = true;
  static const bool enableExport = true;
  static const bool enableAdvancedStats = true;
  static const bool enableThemeCustomization = true;

  // Validation Rules
  static const String emailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String phoneRegex = r'^[+]?[\d\s\-\(\)]{10,}$';
  static const String passwordRegex = r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d@$!%*?&]{8,}$';

  // Error Messages
  static const String networkErrorMessage = 'Network connection error. Please check your internet connection.';
  static const String serverErrorMessage = 'Server error occurred. Please try again later.';
  static const String unknownErrorMessage = 'An unknown error occurred. Please try again.';
  static const String validationErrorMessage = 'Please check your input and try again.';

  // Success Messages
  static const String dataSavedMessage = 'Data saved successfully!';
  static const String dataExportedMessage = 'Data exported successfully!';
  static const String pointsEarnedMessage = 'Points earned successfully!';
  static const String featureUnlockedMessage = 'Feature unlocked successfully!';

  // Tutorial and Onboarding
  static const List<String> onboardingPages = [
    'welcome',
    'diary',
    'time_tracking',
    'finance',
    'points_system',
    'getting_started',
  ];

  // Premium Subscription (Future Feature)
  static const String monthlySubscriptionId = 'lifesync_monthly';
  static const String yearlySubscriptionId = 'lifesync_yearly';
  static const double monthlySubscriptionPrice = 29000; // 29k VND
  static const double yearlySubscriptionPrice = 299000; // 299k VND (save 17%)

  // Social Features (Future)
  static const int maxFriends = 100;
  static const int maxGroupMembers = 10;
  static const Duration challengeDuration = Duration(days: 30);

  // Gamification
  static const List<String> achievementIds = [
    'first_diary_entry',
    'week_streak',
    'month_streak',
    'time_master',
    'finance_tracker',
    'point_collector',
    'early_bird',
    'night_owl',
  ];

  // Widget Sizes
  static const double smallWidgetHeight = 120.0;
  static const double mediumWidgetHeight = 200.0;
  static const double largeWidgetHeight = 300.0;

  // Grid Layout
  static const int mobileGridColumns = 2;
  static const int tabletGridColumns = 3;
  static const int desktopGridColumns = 4;

  // Typography
  static const double smallFontSize = 12.0;
  static const double regularFontSize = 14.0;
  static const double mediumFontSize = 16.0;
  static const double largeFontSize = 18.0;
  static const double extraLargeFontSize = 24.0;
  static const double titleFontSize = 32.0;

  // Spacing
  static const double extraSmallSpacing = 4.0;
  static const double smallSpacing = 8.0;
  static const double regularSpacing = 12.0;
  static const double mediumSpacing = 16.0;
  static const double largeSpacing = 24.0;
  static const double extraLargeSpacing = 32.0;

  // API Configuration (Future Backend Integration)
  static const Duration apiTimeout = Duration(seconds: 30);
  static const String apiVersion = 'v1';

  // Rate Limiting
  static const int maxApiRequestsPerMinute = 60;
  static const Duration rateLimitWindow = Duration(minutes: 1);

  // Data Validation
  static const double minAmount = 0.01;
  static const double maxAmount = 999999999.99;
  static const int minAge = 13;
  static const int maxAge = 120;
}
