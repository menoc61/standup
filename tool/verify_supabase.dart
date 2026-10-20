// Live verification of a configured Supabase project.
//
// The SQL files in the repository prove what the server is *supposed* to do.
// This tool proves what it *does*, through the same publishable key and the same
// REST surface the app uses. It is the live counterpart to
// test/supabase_privacy_test.dart, which can only read the SQL.
//
// It never uses a service-role key: every call is made as an ordinary
// authenticated (or anonymous) user, so a passing run is evidence that the
// policies hold rather than evidence that the operator can bypass them.
//
//   dart run tool/verify_supabase.dart
//   dart run tool/verify_supabase.dart --cohort
//
// Environment:
//   SUPABASE_URL               required
//   SUPABASE_PUBLISHABLE_KEY   required (SUPABASE_KEY is accepted for the TUI)
//   STANDUP_INVITE_CODE        optional; join checks are skipped without it
//   STANDUP_ADMIN_EMAIL        optional, with the password, for --cohort
//   STANDUP_ADMIN_PASSWORD
//   STANDUP_VERIFY_EMAIL_DOMAIN  optional; defaults to example.com. Supabase
//                              rejects some domains outright (example.com and
//                              domains without mail records both return
//                              email_address_invalid), so set this to a domain
//                              the project accepts.
//
// The run creates throwaway users named standup.verify.<stamp>.*@example.com.
// It cannot delete them (that needs the admin API), so either confirm email is
// disabled on the project or delete those users afterwards. They are printed at
// the end so nothing is left behind silently.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:supabase/supabase.dart';

const _password = 'StandUp-verify-4f9c!7d';

Future<void> main(List<String> args) async {
  final env = Platform.environment;
  final url = (env['SUPABASE_URL'] ?? '').trim();
  final key = (env['SUPABASE_PUBLISHABLE_KEY'] ?? env['SUPABASE_KEY'] ?? '')
      .trim();
  final inviteCode = (env['STANDUP_INVITE_CODE'] ?? '').trim();
  final verifyDomain = (env['STANDUP_VERIFY_EMAIL_DOMAIN'] ?? 'example.com')
      .trim();
  final runCohort = args.contains('--cohort');

  if (url.isEmpty || key.isEmpty) {
    stderr.writeln(
      'Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY before running this.\n'
      'Without them the app is local-only, so there is nothing to verify.',
    );
    exit(2);
  }
  if (url.contains('service_role') || key.startsWith('sb_secret_')) {
    stderr.writeln(
      'That is a secret key. This tool must run as an ordinary user, or the '
      'checks prove nothing.',
    );
    exit(2);
  }

  final stamp = DateTime.now().millisecondsSinceEpoch;
  final results = _Results();
  final created = <String>[];

  _section('Project');
  final anon = _client(url, key);
  results.note('url', url);
  results.note('key', '${key.substring(0, min(12, key.length))}…');

  // 1. Anonymous callers must not reach the invite function.
  await results.check('anonymous callers cannot join an organisation', () async {
    try {
      await anon.rpc('join_organization', params: {'invite_code': 'anything'});
    } on PostgrestException catch (e) {
      if (e.code == '42501' || e.code == '401' || e.code == '403') return;
      rethrow;
    } on AuthException {
      return;
    }
    throw const _CheckFailure(
      'join_organization answered an anonymous caller; EXECUTE is granted too '
      'widely',
    );
  });

  // 2. Two ordinary accounts, one per device in the real world.
  _section('Accounts');
  final alice = _client(url, key);
  final bob = _client(url, key);
  final aliceEmail = 'standup.verify.$stamp.a@$verifyDomain';
  final bobEmail = 'standup.verify.$stamp.b@$verifyDomain';

  await results.check('a new account gets a session', () async {
    await _signUp(alice, url, key, aliceEmail);
    created.add(aliceEmail);
    if (alice.auth.currentSession == null) {
      throw const _CheckFailure(
        'sign-up returned no session. Email confirmation is enabled; this '
        'verifier (and the demo join flow) expects folded confirmation.',
      );
    }
  });
  await results.check('a second account gets its own session', () async {
    await _signUp(bob, url, key, bobEmail);
    created.add(bobEmail);
    if (bob.auth.currentUser?.id == alice.auth.currentUser?.id) {
      throw const _CheckFailure('both clients share one identity');
    }
  });

  final aliceId = alice.auth.currentUser?.id;
  final bobId = bob.auth.currentUser?.id;
  if (aliceId == null || bobId == null) {
    results.abort('accounts were not created; nothing else can be checked');
    _finish(results, created);
    return;
  }

  // 3. Reminder events stay on the device that recorded them.
  _section('Individual privacy');
  final scheduled = DateTime.now().toUtc().toIso8601String();
  await results.check('a user can write a break event', () async {
    await alice.from('reminder_logs').insert({
      'user_id': aliceId,
      'scheduled_time': scheduled,
      'action_taken': 'completed',
      'snooze_duration': 0,
    });
  });
  await results.check('another user cannot read that event', () async {
    final rows = await bob.from('reminder_logs').select();
    if (rows.isNotEmpty) {
      throw _CheckFailure(
        'RLS returned ${rows.length} foreign reminder log(s)',
      );
    }
  });
  await results.check(
    'a user cannot forge an event for someone else',
    () async {
      try {
        await bob.from('reminder_logs').insert({
          'user_id': aliceId,
          'scheduled_time': scheduled,
          'action_taken': 'completed',
        });
      } on PostgrestException catch (e) {
        if (e.code == '42501' || e.code == '401' || e.code == '403') return;
        rethrow;
      }
      throw const _CheckFailure(
        'an insert attributed to another user was accepted',
      );
    },
  );

  // 4. The invite code is not readable, only redeemable.
  _section('Workspace membership');
  await results.check('the invite code is not selectable', () async {
    try {
      await alice.from('organizations').select('code');
    } on PostgrestException catch (e) {
      if (e.code == '42501' || e.code == '42703' || e.code == '401') return;
      rethrow;
    }
    throw const _CheckFailure(
      'organizations.code is readable; the column grant is too wide',
    );
  });
  await results.check('a user cannot promote themselves', () async {
    try {
      await alice.from('profiles').update({'role': 'admin'}).eq('id', aliceId);
    } on PostgrestException catch (e) {
      if (e.code == '42501' || e.code == '401' || e.code == '403') return;
      rethrow;
    }
    throw const _CheckFailure('a user changed their own role');
  });

  // 5. Analytics are server-validated, never client-written.
  _section('Analytics');
  await results.check('direct writes to analytics_daily are refused', () async {
    try {
      await alice.from('analytics_daily').insert({
        'user_id': aliceId,
        'date': _day(0),
        'reminders_sent': 8,
        'reminders_completed': 8,
      });
    } on PostgrestException catch (e) {
      if (e.code == '42501' || e.code == '401' || e.code == '403') return;
      rethrow;
    }
    throw const _CheckFailure(
      'INSERT on analytics_daily is still granted; the validation script did '
      'not run or did not revoke it',
    );
  });
  await results.check('a plausible day is recorded and trusted', () async {
    final row = await alice.rpc(
      'record_daily_analytics',
      params: {
        'p_date': _day(0),
        'p_reminders_sent': 8,
        'p_reminders_completed': 6,
        'p_reminders_snoozed': 1,
        'p_reminders_skipped': 1,
        'p_total_stand_minutes': 30,
      },
    );
    final map = Map<String, dynamic>.from(row as Map);
    if (map['trusted'] != true) {
      throw _CheckFailure(
        'a plausible day was marked untrusted (${map['trust_note']})',
      );
    }
  });
  await results.check('impossible counters are flagged, not trusted', () async {
    final row = await alice.rpc(
      'record_daily_analytics',
      params: {
        'p_date': _day(-2),
        'p_reminders_sent': 10,
        'p_reminders_completed': 99,
        'p_total_stand_minutes': 495,
      },
    );
    final map = Map<String, dynamic>.from(row as Map);
    if (map['trusted'] == true) {
      throw const _CheckFailure(
        'a row whose actions exceed the reminders sent stayed trusted',
      );
    }
  });

  // 6. Organisation data only through aggregates.
  _section('Organisation');
  await results.check('an unknown invite code is rejected', () async {
    try {
      await alice.rpc(
        'join_organization',
        params: {'invite_code': 'NOT-A-REAL-CODE-$stamp'},
      );
    } on PostgrestException catch (e) {
      if (e.code == 'P0001' || e.code == '42501' || e.code == '400') return;
      rethrow;
    }
    throw const _CheckFailure('an invalid invite code was accepted');
  });

  if (inviteCode.isEmpty) {
    results.skip('joining a workspace', 'STANDUP_INVITE_CODE is not set');
    results.skip('non-admins see no aggregate', 'needs a joined workspace');
  } else {
    await results.check('both users can join with the code', () async {
      final joined = await alice.rpc(
        'join_organization',
        params: {'invite_code': inviteCode},
      );
      await bob.rpc('join_organization', params: {'invite_code': inviteCode});
      final map = Map<String, dynamic>.from(joined as Map);
      if (map['id'] == null) {
        throw const _CheckFailure('join returned no organisation id');
      }
    });
    await results.check('an employee sees no organisation aggregate', () async {
      final rows = await alice.from('org_analytics_daily').select();
      if (rows.isNotEmpty) {
        throw _CheckFailure('an employee read ${rows.length} aggregate row(s)');
      }
    });
  }

  if (!runCohort) {
    results.skip(
      'the aggregate never exposes a cohort below five',
      'run with --cohort and STANDUP_ADMIN_EMAIL/PASSWORD',
    );
  } else {
    final adminEmail = (env['STANDUP_ADMIN_EMAIL'] ?? '').trim();
    final adminPassword = env['STANDUP_ADMIN_PASSWORD'] ?? '';
    if (adminEmail.isEmpty || adminPassword.isEmpty) {
      results.skip(
        'an admin sees a cohort-protected aggregate',
        'STANDUP_ADMIN_EMAIL/STANDUP_ADMIN_PASSWORD are not set',
      );
    } else if (inviteCode.isEmpty) {
      results.skip(
        'the aggregate never exposes a cohort below five',
        'STANDUP_INVITE_CODE is not set',
      );
    } else {
      await results.check(
        'the aggregate never exposes a cohort below five',
        () async {
          final admin = _client(url, key);
          await admin.auth.signInWithPassword(
            email: adminEmail,
            password: adminPassword,
          );
          final rows = await admin
              .from('org_analytics_daily')
              .select()
              .order('date', ascending: false)
              .limit(1);
          // Fewer than five contributors in the cohort is the normal state of a
          // fresh organisation; the correct answer is no row at all, not a row
          // describing one or two people.
          if (rows.isEmpty) return;
          final users = rows.first['active_users'];
          if (users is int && users < 5) {
            throw _CheckFailure(
              'the view exposed a cohort of $users, below its own minimum of 5',
            );
          }
        },
      );
    }
  }

  _finish(results, created);
}

SupabaseClient _client(String url, String key) => SupabaseClient(
  url,
  key,
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

Future<void> _signUp(
  SupabaseClient client,
  String url,
  String key,
  String email,
) async {
  try {
    await client.auth.signUp(email: email, password: _password);
  } on TypeError {
    // The SDK crashes on an error body it cannot map to AuthResponse, which
    // turns "this domain is rejected" into "null check operator used on a null
    // value". Ask the same endpoint directly so the operator sees the reason.
    throw _CheckFailure(await _signUpRejection(url, key, email));
  } catch (e) {
    throw _CheckFailure('sign-up failed ($e)');
  }
}

Future<String> _signUpRejection(String url, String key, String email) async {
  final http = HttpClient();
  try {
    final request = await http.postUrl(Uri.parse('$url/auth/v1/signup'));
    request.headers.set('apikey', key);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'email': email, 'password': _password}));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return 'sign-up rejected (HTTP ${response.statusCode}): $body';
  } finally {
    http.close(force: true);
  }
}

String _day(int offset) {
  final now = DateTime.now().toUtc().add(Duration(days: offset));
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

void _section(String title) {
  stdout.writeln('\n$title');
}

void _finish(_Results results, List<String> created) {
  stdout.writeln('\n${results.summary()}');
  if (created.isNotEmpty) {
    stdout.writeln(
      '\nAccounts created by this run (delete them when you are done). Without '
      'the admin API this tool cannot remove them:\n'
      '${created.map((e) => '  $e').join('\n')}',
    );
  }
  exit(results.failed ? 1 : 0);
}

class _CheckFailure implements Exception {
  const _CheckFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class _Results {
  final _notes = <String>[];
  int _passed = 0;
  final _failures = <String>[];
  final _skips = <String>[];
  bool _aborted = false;

  bool get failed => _failures.isNotEmpty || _aborted;

  void note(String key, String value) => _notes.add('$key = $value');

  void skip(String name, String why) {
    _skips.add('$name ($why)');
    stdout.writeln('  SKIP  $name — $why');
  }

  void abort(String why) {
    _aborted = true;
    _failures.add(why);
    stdout.writeln('  ABORT $why');
  }

  Future<void> check(String name, Future<void> Function() body) async {
    try {
      await body();
      _passed++;
      stdout.writeln('  PASS  $name');
    } on _CheckFailure catch (e) {
      _failures.add('$name: ${e.message}');
      stdout.writeln('  FAIL  $name\n        ${e.message}');
    } on PostgrestException catch (e) {
      final text = '${e.code ?? '?'} ${e.message}';
      _failures.add('$name: $text');
      stdout.writeln('  FAIL  $name\n        $text');
    } on AuthException catch (e) {
      _failures.add('$name: ${e.message}');
      stdout.writeln('  FAIL  $name\n        ${e.message}');
    } catch (e) {
      _failures.add('$name: $e');
      stdout.writeln('  FAIL  $name\n        $e');
    }
  }

  String summary() {
    final buffer = StringBuffer()
      ..writeln(
        '$_passed passed, ${_failures.length} failed, '
        '${_skips.length} skipped',
      );
    if (_notes.isNotEmpty) {
      for (final note in _notes) {
        buffer.writeln('  $note');
      }
    }
    for (final failure in _failures) {
      buffer.writeln('  failed: $failure');
    }
    return buffer.toString().trimRight();
  }
}
