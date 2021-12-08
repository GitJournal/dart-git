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
      expect(t.toString(), equals('2010-01-02 14:34:05.006007+1130'));
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

  test('toUTC', () {
    var offset = Duration(hours: 1);
    var dt = GDateTime(offset, 2010, 1, 2, 3, 4, 5).toUtc();

    expect(dt.toIso8601String(), '2010-01-02T02:04:05.000Z');
  });

  test('Parse', () {
    var dt = GDateTime.parse('2010-01-02T03:04:05Z');
    expect(dt.year, 2010);
    expect(dt.month, 1);
    expect(dt.day, 2);
    expect(dt.hour, 3);
    expect(dt.minute, 4);
    expect(dt.second, 5);
    expect(dt.offset, Duration(hours: 0));

    dt = GDateTime.parse('2010-01-02T03:04:05.006Z');
    expect(dt.year, 2010);
    expect(dt.month, 1);
    expect(dt.day, 2);
    expect(dt.hour, 3);
    expect(dt.minute, 4);
    expect(dt.second, 5);
    expect(dt.millisecond, 6);
    expect(dt.offset, Duration(hours: 0));

    dt = GDateTime.parse('2010-01-02T03:04:05+02:00');
    expect(dt.year, 2010);
    expect(dt.month, 1);
    expect(dt.day, 2);
    expect(dt.hour, 3);
    expect(dt.minute, 4);
    expect(dt.second, 5);
    expect(dt.offset, Duration(hours: 2));

    dt = GDateTime.parse('2010-01-02T03:04:05-06:30');
    expect(dt.year, 2010);
    expect(dt.month, 1);
    expect(dt.day, 2);
    expect(dt.hour, 3);
    expect(dt.minute, 4);
    expect(dt.second, 5);
    expect(dt.offset, Duration(hours: -6, minutes: -30));

    dt = GDateTime.parse('2020-02-15T09:08:07.000Z');
    expect(dt, DateTime.parse('2020-02-15T09:08:07.000Z'));
  });
}
