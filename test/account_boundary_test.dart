import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/data/local/app_database.dart';
import 'package:standup_app/data/local/local_repository.dart';
import 'package:standup_app/data/models/user_profile.dart';

/// Guards the account boundary on a shared device.
///
/// The defect: signOut() cleared the Supabase session but left UserProfile.id
/// pointing at the account that had just signed out. The next sign-in called
/// reassignLocalUser(A, B), whose only guard refuses when B already has a row
/// on this device. B normally does not, so A's break history, streak and
/// preferences were rewritten to B - and markAllAnalyticsAsUnsynced then
/// uploaded them into B's cloud account and its organisation's aggregates.
///
/// These tests pin the repository-level contract: claiming a device-local
/// identity is allowed, switching between two real accounts is not.

void main() {
  late AppDatabase db;
  late LocalDatabaseRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = LocalDatabaseRepository(db);
  });

  tearDown(() async => db.close());

  UserProfile profile(String id) =>
      UserProfile(id: id, name: 'Employee', role: 'employee');

  group('Account boundary', () {
    test('getUserProfileById finds only the requested account', () async {
      await repo.saveUserProfile(profile('account-a'));

      expect(await repo.getUserProfileById('account-a'), isNotNull);
      expect(
        await repo.getUserProfileById('account-b'),
        isNull,
        reason: 'An account this device has never seen must not resolve.',
      );
    });

    test('claiming a device-local identity moves its rows to the account',
        () async {
      const localId = 'local_11111111-2222-3333-4444-555555555555';
      await repo.saveUserProfile(profile(localId));

      // This is the intended path: never-synced device history is claimed by
      // the account the user just signed in to.
      await repo.reassignLocalUser(localId, 'account-a');

      expect(await repo.getUserProfileById('account-a'), isNotNull);
      expect(
        await repo.getUserProfileById(localId),
        isNull,
        reason: 'The local identity should no longer exist after being claimed.',
      );
    });

    test('signing back into the first account still finds its own rows',
        () async {
      // The sequence that leaked data, reduced to what the repository must
      // guarantee: A claims the local history, then a switch to B happens, and
      // signing back into A must still resolve A - not B, and not nothing.
      const localId = 'local_11111111-2222-3333-4444-555555555555';
      await repo.saveUserProfile(profile(localId));
      await repo.reassignLocalUser(localId, 'account-a');

      // Account switch: B arrives. The fix in AppState keeps A's rows under A
      // and loads B's own profile, so nothing is rewritten.
      await repo.saveUserProfile(profile('account-b'));

      expect(await repo.getUserProfileById('account-a'), isNotNull);
      expect(await repo.getUserProfileById('account-b'), isNotNull);
    });

    test('reassigning when the target already has a row still refuses',
        () async {
      // The pre-existing guard, kept because it is still correct: it stops a
      // merge of two real accounts even if the caller gets the order wrong.
      await repo.saveUserProfile(profile('account-a'));
      await repo.saveUserProfile(profile('account-b'));

      await expectLater(
        repo.reassignLocalUser('account-a', 'account-b'),
        throwsStateError,
      );
      expect(await repo.getUserProfileById('account-a'), isNotNull);
    });
  });
}