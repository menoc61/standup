import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/data/models/user_profile.dart';

/// Signing in used to push the device's profile before reading the account's
/// row. On a new device that row starts as "Employee" with no department, so the
/// first sign-in erased the name and department the person had set elsewhere.
/// These tests pin the merge order that replaced it.
void main() {
  UserProfile local({
    String name = 'Employee',
    String? designation,
    String? department,
    String? organizationId,
    String? organizationName,
    String role = 'employee',
  }) {
    return UserProfile(
      id: 'user-1',
      name: name,
      designation: designation,
      department: department,
      organizationId: organizationId,
      organizationName: organizationName,
      role: role,
    );
  }

  group('Remote profile merge', () {
    test('a new device adopts the account name and department', () {
      final merged = mergeRemoteProfile(local(), {
        'name': 'Mony Aye',
        'designation': 'HR Lead',
        'department': 'Finance',
        'organization_id': 'org-1',
        'role': 'admin',
      });

      expect(merged.name, 'Mony Aye');
      expect(merged.designation, 'HR Lead');
      expect(merged.department, 'Finance');
      expect(merged.organizationId, 'org-1');
      expect(merged.role, 'admin');
    });

    test('a complete remote row is not pushed back over itself', () {
      final remote = <String, dynamic>{
        'name': 'Mony Aye',
        'designation': 'HR Lead',
        'department': 'Finance',
        'organization_id': 'org-1',
        'role': 'admin',
      };
      final merged = mergeRemoteProfile(local(), remote);

      expect(profileNeedsPush(merged, remote), isFalse);
    });

    test('a local field the server is missing is merged and pushed once', () {
      final remote = <String, dynamic>{
        'name': 'Mony Aye',
        'designation': null,
        'department': null,
        'organization_id': 'org-1',
        'role': 'employee',
      };
      final merged = mergeRemoteProfile(
        local(department: 'Finance', designation: 'HR Lead'),
        remote,
      );

      expect(merged.name, 'Mony Aye');
      expect(merged.department, 'Finance');
      expect(merged.designation, 'HR Lead');
      expect(profileNeedsPush(merged, remote), isTrue);
    });

    test('whitespace in the remote row counts as missing', () {
      final remote = <String, dynamic>{
        'name': '   ',
        'designation': ' ',
        'department': '',
        'organization_id': 'org-1',
        'role': 'employee',
      };
      final merged = mergeRemoteProfile(
        local(name: 'Awa', department: 'IT'),
        remote,
      );

      expect(merged.name, 'Awa');
      expect(merged.department, 'IT');
      expect(profileNeedsPush(merged, remote), isTrue);
    });

    test('an empty local profile is not pushed as data', () {
      final remote = <String, dynamic>{
        'name': 'Employee',
        'designation': null,
        'department': null,
        'organization_id': null,
        'role': 'employee',
      };
      final merged = mergeRemoteProfile(local(), remote);

      expect(profileNeedsPush(merged, remote), isFalse);
    });

    test('leaving the workspace clears the cached organisation', () {
      // Organisation and role are server-authoritative. Keeping a stale
      // organisation id would leave the admin screen trying to read aggregates
      // the account no longer has access to.
      final merged = mergeRemoteProfile(
        local(organizationId: 'org-1', organizationName: 'CNPS', role: 'admin'),
        {
          'name': 'Mony Aye',
          'designation': 'HR Lead',
          'department': 'Finance',
          'organization_id': null,
          'role': 'employee',
        },
      );

      expect(merged.organizationId, isNull);
      expect(merged.organizationName, isNull);
      expect(merged.role, 'employee');
    });

    test('the account id is never taken from the payload', () {
      final merged = mergeRemoteProfile(local(), {
        'id': 'someone-else',
        'name': 'Mony Aye',
        'designation': null,
        'department': null,
        'organization_id': 'org-1',
        'role': 'employee',
      });

      expect(merged.id, 'user-1');
    });
  });
}
