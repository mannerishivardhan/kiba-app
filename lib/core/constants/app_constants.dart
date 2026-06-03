class AppConstants {
  AppConstants._();

  // App info
  static const String appName    = 'Kiba';
  static const String appVersion = '1.0.0';

  // ── Firestore collections ─────────────────────────────────────────────────
  static const String usersCollection         = 'users';
  static const String attendanceCollection    = 'attendance';
  static const String leavesCollection        = 'leaves';
  static const String visitsCollection        = 'visits';
  static const String tasksCollection         = 'tasks';
  static const String alertsCollection        = 'alerts';
  static const String teamsCollection         = 'teams';
  static const String notificationsCollection = 'notifications';
  static const String liveLocationsCollection = 'live_locations';
  static const String locationLogsCollection  = 'location_logs';
  static const String settingsCollection      = 'settings';

  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyUserRole       = 'user_role';

  // ── User roles ────────────────────────────────────────────────────────────
  static const String roleFieldAdvisor = 'field_advisor';
  static const String roleClerk        = 'clerk';
  static const String roleAdmin        = 'admin';

  // ── User account statuses ─────────────────────────────────────────────────
  static const String accountPending  = 'pending';
  static const String accountApproved = 'approved';
  static const String accountRejected = 'rejected';

  // ── Attendance day statuses ───────────────────────────────────────────────
  static const String statusPresent              = 'present';
  static const String statusLate                 = 'late';
  static const String statusAbsent               = 'absent';
  static const String statusEarlyCheckout        = 'early_checkout';
  static const String statusVisitThresholdNotMet = 'visit_threshold_not_met';
  static const String statusDistanceNotMet       = 'distance_threshold_not_met';
  static const String statusLeave                = 'leave';
  static const String statusHoliday             = 'holiday';

  // ── Alert types ───────────────────────────────────────────────────────────
  static const String alertLateCheckin              = 'late_checkin';
  static const String alertEarlyCheckout            = 'early_checkout';
  static const String alertAbsent                   = 'absent';
  static const String alertVisitThresholdNotMet     = 'visit_threshold_not_met';
  static const String alertDistanceNotMet           = 'distance_threshold_not_met';
  static const String alertMultipleThresholdsMissed = 'multiple_thresholds_missed';

  // ── Alert severities ──────────────────────────────────────────────────────
  static const String severityInfo     = 'info';
  static const String severityWarning  = 'warning';
  static const String severityCritical = 'critical';

  // ── Animation durations ───────────────────────────────────────────────────
  static const Duration animFast   = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow   = Duration(milliseconds: 600);

  // ── Geofence ──────────────────────────────────────────────────────────────
  static const double geofenceRadiusMeters = 100.0;
}
