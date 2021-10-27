// Some of the code has been adapted from -
// https://github.com/srawlins/timezone/blob/master/lib/src/date_time.dart

class GDateTime implements DateTime {
  /// The timezone in this doesn't matter, so lets always keep it UTC
  final DateTime _native;

  /// East of UTC.
  final Duration offset;

  GDateTime(
    Duration offset,
    int year, [
    int month = 1,
    int day = 1,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
    int microsecond = 0,
  ]) : this._internal(offset, year, month, day, hour, minute, second,
            millisecond, microsecond);

  GDateTime.fromDt(Duration offset, DateTime dt)
      : this._internal(offset, dt.year, dt.month, dt.day, dt.hour, dt.minute,
            dt.second, dt.millisecond, dt.microsecond);

  GDateTime.from(DateTime dt) : this.fromDt(dt.timeZoneOffset, dt);

  GDateTime.fromTimeStamp(this.offset, int timeStampInSecs)
      : _native = DateTime.fromMillisecondsSinceEpoch(
          timeStampInSecs * 1000,
          isUtc: true,
        ) {
    assert(offset.inHours <= 14);
  }

  GDateTime._internal(this.offset, int year, int month, int day, int hour,
      int minute, int second, int millisecond, int microsecond)
      : _native = DateTime.utc(
            year, month, day, hour, minute, second, millisecond, microsecond) {
    assert(offset.inHours <= 14);
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
  DateTime toUtc() => _native.add(offset);

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
    var y = _fourDigits(_native.year);
    var m = _twoDigits(_native.month);
    var d = _twoDigits(_native.day);
    var sep = iso8601 ? 'T' : ' ';
    var h = _twoDigits(_native.hour);
    var min = _twoDigits(_native.minute);
    var sec = _twoDigits(_native.second);
    var ms = _threeDigits(_native.millisecond);
    var us = _native.microsecond == 0 ? '' : _threeDigits(_native.microsecond);

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
  int get millisecondsSinceEpoch =>
      _native.millisecondsSinceEpoch + timeZoneOffset.inMilliseconds;
  @override
  int get microsecondsSinceEpoch =>
      _native.microsecondsSinceEpoch + timeZoneOffset.inMicroseconds;

  @override
  String get timeZoneName => '';
  @override
  Duration get timeZoneOffset => offset;

  @override
  int get year => _native.year;
  @override
  int get month => _native.month;
  @override
  int get day => _native.day;
  @override
  int get hour => _native.hour;
  @override
  int get minute => _native.minute;
  @override
  int get second => _native.second;
  @override
  int get millisecond => _native.millisecond;
  @override
  int get microsecond => _native.microsecond;
  @override
  int get weekday => _native.weekday;

  static GDateTime now() => GDateTime.from(DateTime.now());
}
