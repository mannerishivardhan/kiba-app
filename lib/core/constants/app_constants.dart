/// App-wide constants for Kiba.
class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'Kiba';
  static const String appVersion = '1.0.0';

  // Firestore collections
  static const String usersCollection = 'users';
  static const String attendanceCollection = 'attendance';
  static const String leavesCollection = 'leaves';
  static const String tasksCollection = 'tasks';
  static const String teamsCollection = 'teams';
  static const String notificationsCollection = 'notifications';

  // Shared Preferences keys
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyUserRole = 'user_role';

  // User roles — FA and Clerk are equal (own data only). Admin has full access.
  static const String roleFieldAdvisor = 'field_advisor'; // field staff
  static const String roleClerk = 'clerk';               // office staff
  static const String roleAdmin = 'admin';               // full access

  // Attendance status
  static const String statusPresent = 'present';
  static const String statusAbsent = 'absent';
  static const String statusLate = 'late';
  static const String statusHalfDay = 'half_day';
  static const String statusLeave = 'leave';

  // Geofence
  static const double geofenceRadiusMeters = 100.0;

  // Animation durations
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 600);
}
