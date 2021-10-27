import 'package:test/test.dart';

import 'package:dart_git/utils/date_time.dart';

void main() {
  group('Constructors', () {
    test('Default', () {
      final offset = Duration(hours: -8);
      final t = GDateTime(offset, 2010, 1, 2, 3, 4, 5, 6, 7);
      expect(t.toString(), equals('2010-01-02 03:04:05.006007-0800'));
    });

    test('Default, only year argument', () {
      final offset = Duration(hours: 5, minutes: 30);
      final t = GDateTime(offset, 2010);
      expect(t.toString(), equals('2010-01-01 00:00:00.000+0530'));
    });

    test('from DateTime', () {
      final offset = Duration(hours: 11, minutes: 30);
      final utcTime = DateTime.utc(2010, 1, 2, 3, 4, 5, 6, 7);
      final t = GDateTime.fromDt(offset, utcTime);
      expect(t.toString(), equals('2010-01-02 03:04:05.006007+1130'));
    });

    test('from local DateTime', () {
      final offset = Duration(hours: -12, minutes: -30);
      final localTime = DateTime(2010, 1, 2, 3, 4, 5, 6, 7);
      final t = GDateTime.fromDt(offset, localTime);
      expect(t.toString(), equals('2010-01-02 03:04:05.006007-1230'));
    });
  });

  test('timeZoneOffset', () {
    final offset1 = Duration(hours: -8);
    final t1 = GDateTime(offset1, 2010, 1, 2, 3, 4, 5, 6, 7);
    expect(t1.timeZoneOffset.inHours, -8);

    final offset2 = Duration(hours: 5, minutes: 30);
    final t2 = GDateTime(offset2, 2010, 1, 2, 3, 4, 5, 6, 7);
    expect(t2.timeZoneOffset.inHours, 5);
    expect(t2.timeZoneOffset.inMinutes, (5 * 60) + 30);
  });

  test('millisecondsSinceEpoch', () {
    final offset = Duration(hours: 2);
    final t = GDateTime(offset, 2010, 1, 2, 3, 4, 5, 0, 0);
    final t2 = GDateTime.fromTimeStamp(
      offset,
      t.millisecondsSinceEpoch ~/ 1000,
    );

    expect(t, t2);
  });

  test('microsecondsSinceEpoch', () {
    final offset = Duration(hours: 1);
    final t = GDateTime(offset, 2010, 1, 2, 3, 4, 5, 0, 0);
    final t2 = GDateTime.fromTimeStamp(
      offset,
      t.microsecondsSinceEpoch ~/ 1000000,
    );
    expect(t, t2);
  });

  test('secondsSinceEpoch', () {
    var offset = Duration(hours: -8);
    var dt = GDateTime(offset, 2010, 1, 2, 3, 4, 5);

    var dt2 = GDateTime.fromTimeStamp(offset, dt.secondsSinceEpoch);
    expect(dt, dt2);
  });
}
