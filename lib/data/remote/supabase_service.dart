import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:standup_app/data/local/local_repository.dart';
import 'package:standup_app/data/models/org_analytics.dart';
import 'package:standup_app/data/models/user_profile.dart';

enum SyncStatus { idle, syncing, success, offline, error }

class SupabaseService {
  static const String defaultUrl = String.fromEnvironment('SUPABASE_URL');
  static const String defaultAnonKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  bool _isInitialized = false;
  RealtimeChannel? _analyticsChannel;
  String? _analyticsChannelUserId;
  bool get isInitialized => _isInitialized;

  String? get signedInEmail => client?.auth.currentUser?.email;
  String? get signedInUserId => client?.auth.currentUser?.id;
  Stream<void> get authStateChanges =>
      client?.auth.onAuthStateChange.map<void>((_) {}) ??
      const Stream<void>.empty();

  SupabaseClient? get client =>
      _isInitialized ? Supabase.instance.client : null;

  Future<void> initialize({String? url, String? anonKey}) async {
    final targetUrl = (url ?? defaultUrl).trim();
    final targetKey = (anonKey ?? defaultAnonKey).trim();

    // Offline/local mode is the default until real project credentials are
    // supplied with --dart-define. Never try to initialize a fake endpoint.
    if (targetUrl.isEmpty ||
        targetKey.isEmpty ||
        !targetUrl.startsWith('https://')) {
      _isInitialized = false;
      return;
    }

    try {
      await Supabase.initialize(
        url: targetUrl,
        publishableKey: targetKey,
        debug: kDebugMode,
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Supabase initialization fallback: $e');
      _isInitialized = false;
    }
  }

  Future<bool> createEmailAccount({
    required String email,
    required String password,
  }) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Cloud accounts are not configured.');
    }
    final response = await supabase.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: kIsWeb ? null : 'standup://login-callback',
    );
    return response.session != null;
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Cloud accounts are not configured.');
    }
    await supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    final supabase = client;
    if (supabase == null) return;
    await supabase.auth.signOut();
  }

  Future<void> signInWithProvider(OAuthProvider provider) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Cloud accounts are not configured.');
    }
    await supabase.auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? null : 'standup://login-callback',
    );
  }

  Future<void> sendMagicLink(String email) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Cloud accounts are not configured.');
    }
    await supabase.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: kIsWeb ? null : 'standup://login-callback',
    );
  }

  Future<Map<String, dynamic>> joinOrganization(String inviteCode) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Cloud accounts are not configured.');
    }
    if (supabase.auth.currentUser == null) {
      throw StateError('Sign in before joining a workspace.');
    }
    final result = await supabase.rpc(
      'join_organization',
      params: {'invite_code': inviteCode.trim()},
    );
    if (result is! Map) {
      throw StateError('The workspace service returned an invalid response.');
    }
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>?> fetchMyProfile() async {
    final supabase = client;
    final user = supabase?.auth.currentUser;
    if (supabase == null || user == null) return null;
    return await supabase
        .from('profiles')
        .select('name, designation, department, organization_id, role')
        .eq('id', user.id)
        .maybeSingle();
  }

  Future<String?> fetchOrganizationName(String organizationId) async {
    final supabase = client;
    if (supabase == null) return null;
    final organization = await supabase
        .from('organizations')
        .select('name')
        .eq('id', organizationId)
        .maybeSingle();
    return organization?['name'] as String?;
  }

  Future<void> watchMyAnalytics(
    String userId,
    ValueChanged<Map<String, dynamic>> onChange,
  ) async {
    final supabase = client;
    if (supabase == null || signedInUserId != userId) return;
    if (_analyticsChannelUserId == userId && _analyticsChannel != null) return;
    await stopWatchingAnalytics();
    _analyticsChannelUserId = userId;
    _analyticsChannel = supabase
        .channel('standup-analytics-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'analytics_daily',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) onChange(payload.newRecord);
          },
        )
        .subscribe();
  }

  Future<void> stopWatchingAnalytics() async {
    final channel = _analyticsChannel;
    _analyticsChannel = null;
    _analyticsChannelUserId = null;
    if (channel != null) await channel.unsubscribe();
  }

  // ---------------------------------------------------------------------------
  // Cloud Sync
  // ---------------------------------------------------------------------------
  Future<SyncStatus> syncLocalToCloud({
    required String userId,
    required LocalDatabaseRepository localRepo,
    required bool optIn,
    bool clockUnreliable = false,
  }) async {
    if (!_isInitialized || client == null) {
      return SyncStatus.offline;
    }

    final authUser = client!.auth.currentUser;
    if (authUser == null || authUser.id != userId) {
      return SyncStatus.offline;
    }

    if (!optIn) {
      try {
        await client!.from('analytics_daily').delete().eq('user_id', userId);
        return SyncStatus.idle;
      } catch (e) {
        debugPrint('Unable to remove previously shared analytics: $e');
        return SyncStatus.error;
      }
    }

    try {
      var hadErrors = false;
      // Only opted-in users' daily totals are shared for organization insights.
      // Individual reminder timestamps and actions stay on this device.
      final unsyncedAnalytics = await localRepo.getUnsyncedAnalytics(userId);
      for (final analytic in unsyncedAnalytics) {
        try {
          // Go through the server-side validator rather than writing the table
          // directly. The RPC derives the user id from the JWT and the
          // organization from the private profile, rejects implausible totals,
          // and marks suspicious rows untrusted so they never reach the
          // organisation leaderboards. See supabase_validation.sql.
          await client!.rpc(
            'record_daily_analytics',
            params: {
              'p_date': analytic.date,
              'p_reminders_sent': analytic.remindersSent,
              'p_reminders_completed': analytic.remindersCompleted,
              'p_reminders_snoozed': analytic.remindersSnoozed,
              'p_reminders_skipped': analytic.remindersSkipped,
              'p_total_stand_minutes': analytic.totalStandTime,
              'p_client_reports_clock_issue': clockUnreliable,
            },
          );
          await localRepo.markAnalyticAsSynced(analytic.id);
        } catch (e) {
          hadErrors = true;
          debugPrint('Error syncing analytics ${analytic.id}: $e');
        }
      }

      return hadErrors ? SyncStatus.error : SyncStatus.success;
    } catch (e) {
      debugPrint('Sync failed: $e');
      return SyncStatus.error;
    }
  }

  // ---------------------------------------------------------------------------
  // Profile Cloud Sync
  // ---------------------------------------------------------------------------
  Future<void> syncProfileToCloud(UserProfile profile) async {
    if (!_isInitialized || client == null) return;
    if (client!.auth.currentUser?.id != profile.id) return;
    try {
      await client!.from('profiles').upsert({
        'id': profile.id,
        'name': profile.name,
        'designation': profile.designation,
        'department': profile.department,
      });
    } catch (e) {
      debugPrint('Failed to sync profile: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Org Aggregates (Admin View)
  // ---------------------------------------------------------------------------
  Future<OrgAnalytics> fetchOrganizationAnalytics(String orgId) async {
    if (!_isInitialized || client == null) {
      throw StateError('Supabase is not configured.');
    }
    if (client!.auth.currentUser == null) {
      throw StateError('Sign in to view organization analytics.');
    }

    try {
      final response = await client!
          .from('org_analytics_daily')
          .select()
          .eq('organization_id', orgId)
          .order('date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) throw StateError('No aggregate data is available.');

      final orgResponse = await client!
          .from('organizations')
          .select('name')
          .eq('id', orgId)
          .maybeSingle();
      final departmentRows = await client!
          .from('org_department_analytics')
          .select(
            'department, active_users, total_completed, total_skipped, adherence_rate',
          )
          .eq('organization_id', orgId)
          .eq('date', response['date']);

      return OrgAnalytics.fromJson({
        ...response,
        'organization_name': orgResponse?['name'] ?? 'Organization',
        'departments': departmentRows,
        // Skip times are intentionally not shared; reminder-level timestamps
        // remain local to each employee.
        'peak_skip_hours': const <dynamic>[],
      });
    } catch (e) {
      debugPrint('Error fetching organization analytics: $e');
    }

    throw StateError('Organization analytics are unavailable.');
  }
}
