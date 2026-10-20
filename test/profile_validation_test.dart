import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/profile_validation.dart';

void main() {
  group('profile name', () {
    test('rejects an empty or whitespace-only name', () {
      expect(profileNameError(''), 'Enter your full name.');
      expect(profileNameError('   '), 'Enter your full name.');
    });

    test('rejects a single character', () {
      expect(profileNameError('A'), 'Your name is too short.');
    });

    test('accepts accented and hyphenated names', () {
      expect(profileNameError('Aïcha Ngo-Bassong'), isNull);
      expect(profileNameError('  Jeanne  '), isNull);
    });

    test('rejects a pasted paragraph', () {
      expect(
        profileNameError('A' * (kProfileNameMaxLength + 1)),
        'Your name is too long.',
      );
    });
  });

  group('profile designation', () {
    test('is required', () {
      expect(profileDesignationError(''), 'Enter your role or designation.');
      expect(profileDesignationError('  '), 'Enter your role or designation.');
    });

    test('accepts a real role', () {
      expect(profileDesignationError('Ingénieure logiciel'), isNull);
    });

    test('rejects a pasted paragraph', () {
      expect(
        profileDesignationError('R' * (kProfileDesignationMaxLength + 1)),
        'Your role is too long.',
      );
    });
  });

  group('profile email', () {
    test('is optional', () {
      expect(profileEmailError(''), isNull);
      expect(profileEmailError('   '), isNull);
    });

    test('accepts a work address', () {
      expect(profileEmailError('mony.aye@cnps.cm'), isNull);
    });

    test('rejects a malformed address', () {
      for (final value in [
        'mony.aye',
        'mony.aye@cnps',
        '@cnps.cm',
        'mony aye@cnps.cm',
        'mony.aye@.cm',
        'mony.aye@cnps.',
      ]) {
        expect(
          profileEmailError(value),
          'Enter a valid work email address.',
          reason: value,
        );
      }
    });
  });

  group('profile draft', () {
    test('is complete only with a name and a role', () {
      expect(
        profileDraftIsComplete(
          name: 'Mony Aye',
          designation: 'Analyst',
          email: '',
        ),
        isTrue,
      );
      expect(
        profileDraftIsComplete(name: '', designation: 'Analyst', email: ''),
        isFalse,
      );
      expect(
        profileDraftIsComplete(name: 'Mony Aye', designation: '', email: ''),
        isFalse,
      );
      expect(
        profileDraftIsComplete(
          name: 'Mony Aye',
          designation: 'Analyst',
          email: 'not-an-email',
        ),
        isFalse,
      );
    });
  });
}
