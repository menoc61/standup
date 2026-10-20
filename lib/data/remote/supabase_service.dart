import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:standup_app/core/app_identity.dart';
import 'package:standup_app/data/local/local_repository.dart';
import 'package:standup_app/data/models/org_analytics.dart';
import 'package:standup_app/data/models/user_profile.dart';

enum SyncStatus { idle, syncing, success, offline, error }

class SupabaseService {
  static const Duration _databaseRequestTimeout = Duration(seconds: 20);
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
        postgrestOptions: const PostgrestClientOptions(
          requestTimeout: _databaseRequestTimeout,
        ),
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
      emailRedirectTo: kIsWeb ? null : AppIdentity.authRedirectUrl,
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
      redirectTo: kIsWeb ? null : AppIdentity.authRedirectUrl,
    );
  }

  Future<void> sendMagicLink(String email) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Cloud accounts are not configured.');
    }
    await supabase.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: kIsWeb ? null : AppIdentity.authRedirectUrl,
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
        // Auth can change while a long offline queue is being uploaded. Stop
        // before the next aggregate if this session no longer belongs to the
        // account whose local rows were selected.
        if (client!.auth.currentUser?.id != userId) {
          return SyncStatus.offline;
        }
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
          // A timed-out request indicates the backend is not responding. Do
          // not spend another timeout interval on every remaining day; all
          // unsent rows remain local and will be retried on the next sync.
          if (e is TimeoutException) break;
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
    final fields = {
      'name': profile.name,
      'designation': profile.designation,
      'department': profile.department,
    };
    try {
      // An `upsert` is rejected by the live project: PostgREST's ON CONFLICT
      // DO UPDATE also writes the conflict target (`id`), and the client has
      // UPDATE only on name, designation, department and updated_at. That
      // column boundary is deliberate — a client may never move its row to
      // another account — so the write is an update followed by an insert
      // instead, which produces the same result inside the existing grants.
      final updated = await client!
          .from('profiles')
          .update(fields)
          .eq('id', profile.id)
          .select('id');
      if ((updated as List).isNotEmpty) return;
      try {
        await client!.from('profiles').insert({'id': profile.id, ...fields});
      } on PostgrestException catch (error) {
        // Another device created the row between the update and the insert.
        // Retry the update rather than reporting a lost profile.
        if (error.code != '23505') rethrow;
        await client!
            .from('profiles')
            .update(fields)
            .eq('id', profile.id)
            .select('id');
      }
    } catch (e) {
      debugPrint('Failed to sync profile: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Org Aggregates (Admin View)
  // ---------------------------------------------------------------------------
  /// The newest daily aggregate for an organisation, or null when none is
  /// visible. A thin wrapper over [fetchOrganizationTrend] so every caller sees
  /// the same query, cohort rules and department rows.
  Future<OrgAnalytics?> fetchOrganizationAnalytics(String orgId) async {
    final trend = await fetchOrganizationTrend(orgId, days: 1);
    return trend.isEmpty ? null : trend.first;
  }

  /// The most recent [days] daily aggregates for an organisation, newest first.
  ///
  /// One row per measured day, so the dashboard can show a trend rather than a
  /// single number that says nothing about direction. The view already carries
  /// one row per date and filters unauthorised callers, untrusted rows and
  /// cohorts smaller than five, so asking for more days widens the window
  /// without widening what an admin can see about any individual.
  ///
  /// Department rows are fetched for the newest day only: the screen shows one
  /// leaderboard, and repeating that query per day would be [days] round trips
  /// for a breakdown nobody reads historically.
  Future<List<OrgAnalytics>> fetchOrganizationTrend(
    String orgId, {
    int days = 14,
  }) async {
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
          .limit(days);

      if (response.isEmpty) {
        throw StateError('No aggregate data is available.');
      }

      final latestDate = response.first['date'];
      final orgResponse = await client!
          .from('organizations')
          .select('name')
          .eq('id', orgId)
          .maybeSingle();
      final departmentRows = await client!
          .from('org_department_analytics')
          .select(
            'department, active_users, total_sent, total_completed, '
            'total_snoozed, total_skipped, adherence_rate',
          )
          .eq('organization_id', orgId)
          .eq('date', latestDate);

      return [
        for (final row in response)
          OrgAnalytics.fromJson({
            ...row,
            'organization_name': orgResponse?['name'] ?? 'Organization',
            'departments': row['date'] == latestDate
                ? departmentRows
                : const <dynamic>[],
            // Skip times are intentionally not shared; reminder-level timestamps
            // remain local to each employee.
            'peak_skip_hours': const <dynamic>[],
          }),
      ];
    } catch (e) {
      debugPrint('Error fetching organization analytics: $e');
    }

    throw StateError('Organization analytics are unavailable.');
  }
}
