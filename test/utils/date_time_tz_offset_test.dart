import 'package:test/test.dart';

import 'package:dart_git/utils/date_time_tz_offset.dart';

void main() {
  group('Constructors', () {
    test('Default', () {
      final t = DateTimeWithTzOffset(-8, 2010, 1, 2, 3, 4, 5, 6, 7);
      expect(t.toString(), equals('2010-01-02 03:04:05.006007-0800'));
    });

    test('Default, only year argument', () {
      final t = DateTimeWithTzOffset(5.5, 2010);
      expect(t.toString(), equals('2010-01-01 00:00:00.000+0530'));
    });

    test('from DateTime', () {
      final utcTime = DateTime.utc(2010, 1, 2, 3, 4, 5, 6, 7);
      final t = DateTimeWithTzOffset.from(11.5, utcTime);
      expect(t.toString(), equals('2010-01-02 03:04:05.006007+1130'));
    });

    test('from local DateTime', () {
      final localTime = DateTime(2010, 1, 2, 3, 4, 5, 6, 7);
      final t = DateTimeWithTzOffset.from(-12.5, localTime);
      expect(t.toString(), equals('2010-01-02 03:04:05.006007-1230'));
    });
  });

  test('timeZoneOffset', () {
    final t1 = DateTimeWithTzOffset(-8, 2010, 1, 2, 3, 4, 5, 6, 7);
    expect(t1.timeZoneOffset.inHours, -8);

    final t2 = DateTimeWithTzOffset(5.5, 2010, 1, 2, 3, 4, 5, 6, 7);
    expect(t2.timeZoneOffset.inHours, 5);
    expect(t2.timeZoneOffset.inMinutes, (5 * 60) + 30);
  });

  test('millisecondsSinceEpoch', () {
    final t = DateTimeWithTzOffset(2, 2010, 1, 2, 3, 4, 5, 6, 7);
    expect(t.millisecondsSinceEpoch, 1262408645006);
  });

  test('microsecondsSinceEpoch', () {
    final t = DateTimeWithTzOffset(1, 2010, 1, 2, 3, 4, 5, 6, 7);
    expect(t.microsecondsSinceEpoch, 1262405045006007);
  });
}
