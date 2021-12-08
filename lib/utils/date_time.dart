// Some of the code has been adapted from -
// https://github.com/srawlins/timezone/blob/master/lib/src/date_time.dart

class GDateTime implements DateTime {
  /// Always kept in UTC
  final DateTime _native;

  /// East of UTC.
  final Duration offset;

  GDateTime(
    this.offset,
    int year, [
    int month = 1,
    int day = 1,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
    int microsecond = 0,
  ]) : _native = DateTime.utc(year, month, day, hour, minute, second,
                millisecond, microsecond)
            .subtract(offset) {
    assert(offset.inHours <= 14);
    assert(_native.timeZoneOffset.inMicroseconds == 0);
  }

  GDateTime.utc(
    int year, [
    int month = 1,
    int day = 1,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
    int microsecond = 0,
  ])  : _native = DateTime.utc(
            year, month, day, hour, minute, second, millisecond, microsecond),
        offset = Duration(hours: 0) {
    assert(_native.timeZoneOffset.inMicroseconds == 0);
  }

  GDateTime.fromDt(Duration timeZoneOffset, DateTime dt)
      : _native = dt.toUtc(),
        offset = timeZoneOffset;

  GDateTime.from(DateTime dt) : this.fromDt(dt.timeZoneOffset, dt.toUtc());

  GDateTime.fromTimeStamp(this.offset, int timeStampInSecs)
      : _native = DateTime.fromMillisecondsSinceEpoch(
          timeStampInSecs * 1000,
          isUtc: true,
        ) {
    assert(offset.inHours <= 14);
    assert(_native.timeZoneOffset.inMicroseconds == 0);
  }

  @override
  bool get isUtc => offset.inMicroseconds == 0;

  @override
  bool operator ==(Object other) {
    if (other is! DateTime) {
      return false;
    }
    return toUtc() == other.toUtc();
  }

  @override
  bool isBefore(DateTime other) => toUtc().isBefore(other.toUtc());

  @override
  bool isAfter(DateTime other) => toUtc().isAfter(other.toUtc());

  @override
  bool isAtSameMomentAs(DateTime other) =>
      toUtc().isAtSameMomentAs(other.toUtc());

  @override
  int compareTo(DateTime other) {
    var a = toUtc().microsecondsSinceEpoch;
    var b = other.toUtc().microsecondsSinceEpoch;

    return a.compareTo(b);
  }

  @override
  int get hashCode => _native.hashCode ^ offset.hashCode;

  @override
  DateTime toLocal() {
    var localOffset = DateTime.now().timeZoneOffset;
    var utc = toUtc();
    var dt = utc.add(localOffset);

    return GDateTime.fromDt(localOffset, dt);
  }

  @override
  DateTime toUtc() => _native;

  static String _fourDigits(int n) {
    var absN = n.abs();
    var sign = n < 0 ? '-' : '';
    if (absN >= 1000) return '$n';
    if (absN >= 100) return '${sign}0$absN';
    if (absN >= 10) return '${sign}00$absN';
    return '${sign}000$absN';
  }

  static String _threeDigits(int n) {
    if (n >= 100) return '$n';
    if (n >= 10) return '0$n';
    return '00$n';
  }

  static String _twoDigits(int n) {
    if (n >= 10) return '$n';
    return '0$n';
  }

  @override
  String toString() => _toString(iso8601: false);

  @override
  String toIso8601String() => _toString(iso8601: true);

  String _toString({bool iso8601 = true}) {
    var dt = _native.add(offset);

    var y = _fourDigits(dt.year);
    var m = _twoDigits(dt.month);
    var d = _twoDigits(dt.day);
    var sep = iso8601 ? 'T' : ' ';
    var h = _twoDigits(dt.hour);
    var min = _twoDigits(dt.minute);
    var sec = _twoDigits(dt.second);
    var ms = _threeDigits(dt.millisecond);
    var us = dt.microsecond == 0 ? '' : _threeDigits(dt.microsecond);

    if (isUtc) {
      return '$y-$m-$d$sep$h:$min:$sec.$ms${us}Z';
    } else {
      var offSign = offset.isNegative ? '-' : '+';
      var _offset = offset.abs();
      var offH = _twoDigits(_offset.inHours);
      var offM = _twoDigits(_offset.inMinutes % 60);

      return '$y-$m-$d$sep$h:$min:$sec.$ms$us$offSign$offH$offM';
    }
  }

  @override
  DateTime add(Duration duration) {
    var timestamp = _native.millisecondsSinceEpoch + duration.inMilliseconds;
    return GDateTime.fromDt(
      offset,
      DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true),
    );
  }

  @override
  DateTime subtract(Duration duration) {
    var timestamp = _native.millisecondsSinceEpoch - duration.inMilliseconds;
    return GDateTime.fromDt(
      offset,
      DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true),
    );
  }

  @override
  Duration difference(DateTime other) {
    return _native.toUtc().difference(other.toUtc());
  }

  @override
  int get millisecondsSinceEpoch => _native.millisecondsSinceEpoch;
  @override
  int get microsecondsSinceEpoch => _native.microsecondsSinceEpoch;

  int get secondsSinceEpoch => _native.millisecondsSinceEpoch ~/ 1000;

  @override
  String get timeZoneName => '';
  @override
  Duration get timeZoneOffset => offset;

  @override
  int get year => _native.add(offset).year;
  @override
  int get month => _native.add(offset).month;
  @override
  int get day => _native.add(offset).day;
  @override
  int get hour => _native.add(offset).hour;
  @override
  int get minute => _native.add(offset).minute;
  @override
  int get second => _native.add(offset).second;
  @override
  int get millisecond => _native.add(offset).millisecond;
  @override
  int get microsecond => _native.add(offset).microsecond;
  @override
  int get weekday => _native.add(offset).weekday;

  static GDateTime now() => GDateTime.from(DateTime.now());

  static final _regex = RegExp(
      r"(\d{4})-(\d{2})-(\d{2})T(\d{2})\:(\d{2})\:(\d{2})([+-])(\d{2})\:(\d{2})");

  /// Accepts ISO 8601 with the timezone (without milliseconds)
  static GDateTime parse(String formattedString) {
    var m = _regex.firstMatch(formattedString);
    if (m != null) {
      var year = int.parse(m.group(1)!);
      var month = int.parse(m.group(2)!);
      var day = int.parse(m.group(3)!);
      var hour = int.parse(m.group(4)!);
      var minute = int.parse(m.group(5)!);
      var second = int.parse(m.group(6)!);
      var offsetSign = m.group(7);
      var offsetHours = int.parse(m.group(8)!);
      var offsetMinutes = int.parse(m.group(9)!);
      var offsetDuration = Duration(hours: offsetHours, minutes: offsetMinutes);
      if (offsetSign == '-') {
        offsetDuration *= -1;
      }

      return GDateTime(offsetDuration, year, month, day, hour, minute, second);
    }

    return GDateTime.from(DateTime.parse(formattedString));
  }
}
