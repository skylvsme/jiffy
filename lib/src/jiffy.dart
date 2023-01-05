import 'dart:math';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:jiffy/src/enums/startOfWeek.dart';
import 'package:jiffy/src/enums/units.dart';
import 'package:jiffy/src/locale/availableLocales.dart';
import 'package:jiffy/src/locale/locale.dart';
import 'package:jiffy/src/utils/exception.dart';
import 'package:jiffy/src/utils/normalize_units.dart';
import 'package:jiffy/src/utils/regex.dart';
import 'package:jiffy/src/utils/replace.dart';

class Jiffy {
  late DateTime _dateTime;
  static late Locale _defaultLocale;

  DateTime get dateTime => _dateTime;

  Jiffy([var input, String? pattern]) {
    _initializeDateTime(input, pattern);
    _initializeLocale();
  }

  Jiffy.unixFromSecondsSinceEpoch(int timestamp) {
    _unix(timestamp * 1000);
  }

  Jiffy.unixFromMillisecondsSinceEpoch(int timestamp) {
    _unix(timestamp);
  }

  void _unix(int timestamp) {
    _dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Jiffy clone() {
    return Jiffy(this);
  }

  void _initializeDateTime(var input, [String? pattern]) {
    _dateTime = _parse(input, pattern);
  }

  DateTime _parse(var input, [String? pattern]) {
    var dateTime;
    if (input == null && pattern == null) {
      dateTime = DateTime.now();
    } else if (isDateTime(input)) {
      dateTime = input;
    } else if (isJiffy(input)) {
      dateTime = input.dateTime;
    } else if (input is Map) {
      dateTime = _parseMap(input);
    } else if (input is List) {
      dateTime = _parseList(input);
    } else if (input is String) {
      dateTime = _parseString(input, pattern);
    } else {
      throw JiffyException(
              'Jiffy only accepts String, List, Map, DateTime or Jiffy itself as parameters')
          .cause;
    }
    return dateTime;
  }

  DateTime _parseMap(Map input) {
    input.forEach((key, value) {
      validateUnits(key);
    });
    if (input.isEmpty) {
      return DateTime.now();
    } else {
      return DateTime(
          input['year'] ?? input['years'] ?? input['y'] ?? DateTime.now().year,
          input['month'] ??
              input['months'] ??
              input['M'] ??
              DateTime.now().month,
          input['day'] ?? input['days'] ?? input['d'] ?? DateTime.now().day,
          input['hour'] ?? input['hours'] ?? input['h'] ?? DateTime.now().hour,
          input['minute'] ??
              input['minutes'] ??
              input['m'] ??
              DateTime.now().minute,
          input['second'] ??
              input['seconds'] ??
              input['s'] ??
              DateTime.now().second,
          input['millisecond'] ??
              input['milliseconds'] ??
              input['ms'] ??
              DateTime.now().millisecond);
    }
  }

  DateTime _parseList(List input) {
    if (input.isEmpty) {
      return DateTime.now();
    } else {
      return DateTime(
          input[0],
          input.length > 1 ? input[1] : 1,
          input.length > 2 ? input[2] : 1,
          input.length > 3 ? input[3] : 0,
          input.length > 4 ? input[4] : 0,
          input.length > 5 ? input[5] : 0,
          input.length > 6 ? input[6] : 0);
    }
  }

  DateTime _parseString(String input, String? pattern) {
    if (pattern != null) {
      return DateFormat(replacePatternInput(pattern))
          .parse(replaceParseInput(input));
    } else if (matchHyphenStringDateTime(input)) {
      return DateFormat('yyyy-MM-dd').parse(input);
    } else if (matchDartStringDateTime(input) ||
        matchISOStringDateTime(input)) {
      return DateTime.parse(input).toLocal();
    } else if (matchSlashStringDateTime(input)) {
      return DateFormat('yyyy/MM/dd').parse(input);
    } else if (matchBasicStringDateTime().hasMatch(input)) {
      return DateFormat('yyyy/MM/dd')
          .parse(input.replaceAllMapped(matchBasicStringDateTime(), (match) {
        return '${match.group(1)}/${match.group(2)}/${match.group(3)}';
      }));
    } else {
      throw JiffyException(
              'Date time not recognized, a pattern must be passed, e.g. Jiffy("12, Oct", "dd, MMM")')
          .cause;
    }
  }

  static void _initializeLocale() {
    var currentLocale = Intl.getCurrentLocale();
    _defaultLocale = getLocale(currentLocale);
    _defaultLocale.code = currentLocale.toLowerCase();
  }

  static Future<Locale> locale([String? locale]) async {
    _initializeLocale();
    if (locale != null) {
      if (isLocalAvailable(locale)) {
        throw JiffyException(
                'The locale "$locale" does not exist in Jiffy, run Jiffy.getAllAvailableLocales() for more locales')
            .cause;
      }
      await initializeDateFormatting();
      Intl.defaultLocale = locale;
      _defaultLocale = getLocale(locale);
      _defaultLocale.code = locale.toLowerCase();
    }
    return Future.value(_defaultLocale);
  }

  static List<String> getAllAvailableLocales() {
    return getAllLocales();
  }

//  GET
  int get millisecond => _dateTime.millisecond;

  int get second => _dateTime.second;

  int get minute => _dateTime.minute;

  int get hour => _dateTime.hour;

  int get date => _dateTime.day;

  int get day {
    var weekDays = [1, 2, 3, 4, 5, 6, 7, 1, 2];
    var weekDayIndex = _dateTime.weekday - 1;

    switch (_defaultLocale.startOfWeek()) {
      case StartOfWeek.MONDAY:
        weekDayIndex += 0;
        break;
      case StartOfWeek.SUNDAY:
        weekDayIndex += 1;
        break;
      case StartOfWeek.SATURDAY:
        weekDayIndex += 2;
        break;
    }
    return weekDays[weekDayIndex];
  }

  int get daysInMonth => _daysInMonth(_dateTime.year, _dateTime.month);

  int get dayOfYear => int.parse(DateFormat('D').format(_dateTime));

  int get week => ((dayOfYear - day + 10) / 7).floor();

  int get month => _dateTime.month;

  int get quarter => int.parse(DateFormat('Q').format(_dateTime));

  int get year => _dateTime.year;

//  MANIPULATE
  Jiffy add({
    Duration duration = Duration.zero,
    int years = 0,
    int months = 0,
    int weeks = 0,
    int days = 0,
    int hours = 0,
    int minutes = 0,
    int seconds = 0,
    int milliseconds = 0,
    int microseconds = 0,
  }) {
    _dateTime = _dateTime.add(duration);
    _dateTime = _dateTime.add(Duration(
      days: days + (weeks * 7),
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
      microseconds: microseconds,
    ));
    _dateTime = _addMonths(_dateTime, months);
    _dateTime = _addMonths(_dateTime, years * 12);
    return clone();
  }

  Jiffy subtract({
    Duration duration = Duration.zero,
    int years = 0,
    int months = 0,
    int weeks = 0,
    int days = 0,
    int hours = 0,
    int minutes = 0,
    int seconds = 0,
    int milliseconds = 0,
    int microseconds = 0,
  }) {
    _dateTime = _dateTime.subtract(duration);
    _dateTime = _dateTime.subtract(Duration(
      days: days + weeks * 7,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
      microseconds: microseconds,
    ));
    _dateTime = _addMonths(_dateTime, -months);
    _dateTime = _addMonths(_dateTime, -years * 12);
    return clone();
  }

  Jiffy startOf(Units units) {
    switch (units) {
      case Units.MILLISECOND:
        _dateTime = DateTime(
            _dateTime.year,
            _dateTime.month,
            _dateTime.day,
            _dateTime.hour,
            _dateTime.minute,
            _dateTime.second,
            _dateTime.millisecond);
        break;
      case Units.SECOND:
        _dateTime = DateTime(_dateTime.year, _dateTime.month, _dateTime.day,
            _dateTime.hour, _dateTime.minute, _dateTime.second);
        break;
      case Units.MINUTE:
        _dateTime = DateTime(_dateTime.year, _dateTime.month, _dateTime.day,
            _dateTime.hour, _dateTime.minute);
        break;
      case Units.HOUR:
        _dateTime = DateTime(
            _dateTime.year, _dateTime.month, _dateTime.day, _dateTime.hour);
        break;
      case Units.DAY:
        _dateTime = DateTime(_dateTime.year, _dateTime.month, _dateTime.day);
        break;
      case Units.WEEK:
        var newDate = _dateTime.subtract(Duration(days: day - 1));
        _dateTime = DateTime(newDate.year, newDate.month, newDate.day);
        break;
      case Units.MONTH:
        _dateTime = DateTime(_dateTime.year, _dateTime.month, 1);
        break;
      case Units.YEAR:
        _dateTime = DateTime(_dateTime.year);
        break;
    }
    return clone();
  }

  Jiffy endOf(Units units) {
    switch (units) {
      case Units.MILLISECOND:
        _dateTime = DateTime(
            _dateTime.year,
            _dateTime.month,
            _dateTime.day,
            _dateTime.hour,
            _dateTime.minute,
            _dateTime.second,
            _dateTime.millisecond);
        break;
      case Units.SECOND:
        _dateTime = DateTime(_dateTime.year, _dateTime.month, _dateTime.day,
            _dateTime.hour, _dateTime.minute, _dateTime.second, 999);
        break;
      case Units.MINUTE:
        _dateTime = DateTime(_dateTime.year, _dateTime.month, _dateTime.day,
            _dateTime.hour, _dateTime.minute, 59, 999);
        break;
      case Units.HOUR:
        _dateTime = DateTime(_dateTime.year, _dateTime.month, _dateTime.day,
            _dateTime.hour, 59, 59, 999);
        break;
      case Units.DAY:
        _dateTime = DateTime(
            _dateTime.year, _dateTime.month, _dateTime.day, 23, 59, 59, 999);
        break;
      case Units.WEEK:
        var newDate = _dateTime.add(Duration(days: DateTime.daysPerWeek - day));
        _dateTime =
            DateTime(newDate.year, newDate.month, newDate.day, 23, 59, 59, 999);
        break;
      case Units.MONTH:
        var date = _daysInMonthArray[_dateTime.month];
        if (_isLeapYear(_dateTime.year) && _dateTime.month == 2) {
          date = 29;
        }
        _dateTime =
            DateTime(_dateTime.year, _dateTime.month, date, 23, 59, 59, 999);
        break;
      case Units.YEAR:
        _dateTime = DateTime(_dateTime.year, 12, 31, 23, 59, 59, 999);
        break;
    }
    return clone();
  }

  DateTime local() {
    return _dateTime = _dateTime.toLocal();
  }

  DateTime utc() {
    return _dateTime = _dateTime.toUtc();
  }

  static const _daysInMonthArray = [
    0,
    31,
    28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31
  ];

  int _daysInMonth(int year, int month) {
    var result = _daysInMonthArray[month];
    if (month == 2 && _isLeapYear(year)) result++;
    return result;
  }

  DateTime _addMonths(DateTime from, int months) {
    final r = months % 12;
    final q = (months - r) ~/ 12;
    var newYear = from.year + q;
    var newMonth = from.month + r;
    if (newMonth > 12) {
      newYear++;
      newMonth -= 12;
    }
    final newDay = min(from.day, _daysInMonth(newYear, newMonth));
    if (from.isUtc) {
      return DateTime.utc(newYear, newMonth, newDay, from.hour, from.minute,
          from.second, from.millisecond, from.microsecond);
    } else {
      return DateTime(newYear, newMonth, newDay, from.hour, from.minute,
          from.second, from.millisecond, from.microsecond);
    }
  }

//  DISPLAY
  String format([String? pattern]) {
    if (pattern == null) return _dateTime.toIso8601String();
    var ordinal = _defaultLocale.ordinal(_dateTime.day);
    var escaped = replaceEscapePattern(pattern);
    var newPattern = replaceOrdinalDatePattern(escaped, ordinal);
    return DateFormat(newPattern).format(_dateTime);
  }

  String get E => DateFormat.E().format(_dateTime);

  String get EEEE => DateFormat.EEEE().format(_dateTime);

  String get LLL => DateFormat.LLL().format(_dateTime);

  String get LLLL => DateFormat.LLLL().format(_dateTime);

  String get Md => DateFormat.Md().format(_dateTime);

  String get MEd => DateFormat.MEd().format(_dateTime);

  String get MMM => DateFormat.MMM().format(_dateTime);

  String get MMMd => DateFormat.MMMd().format(_dateTime);

  String get MMMEd => DateFormat.MMMEd().format(_dateTime);

  String get MMMM => DateFormat.MMMM().format(_dateTime);

  String get MMMMd => DateFormat.MMMMd().format(_dateTime);

  String get MMMMEEEEd => DateFormat.MMMMEEEEd().format(_dateTime);

  String get QQQ => DateFormat.QQQ().format(_dateTime);

  String get QQQQ => DateFormat.QQQQ().format(_dateTime);

  String get yM => DateFormat.yM().format(_dateTime);

  String get yMd => DateFormat.yMd().format(_dateTime);

  String get yMEd => DateFormat.yMEd().format(_dateTime);

  String get yMMM => DateFormat.yMMM().format(_dateTime);

  String get yMMMd => DateFormat.yMMMd().format(_dateTime);

  String get yMMMdjm => DateFormat.yMMMd().add_jm().format(_dateTime);

  String get yMMMEd => DateFormat.yMMMEd().format(_dateTime);

  String get yMMMEdjm => DateFormat.yMMMEd().add_jm().format(_dateTime);

  String get yMMMM => DateFormat.yMMMM().format(_dateTime);

  String get yMMMMd => DateFormat.yMMMMd().format(_dateTime);

  String get yMMMMdjm => DateFormat.yMMMMd().add_jm().format(_dateTime);

  String get yMMMMEEEEd => DateFormat.yMMMMEEEEd().format(_dateTime);

  String get yMMMMEEEEdjm => DateFormat.yMMMMEEEEd().add_jm().format(_dateTime);

  String get yQQQ => DateFormat.yQQQ().format(_dateTime);

  String get yQQQQ => DateFormat.yQQQQ().format(_dateTime);

  String get Hm => DateFormat.Hm().format(_dateTime);

  String get Hms => DateFormat.Hms().format(_dateTime);

  String get j => DateFormat.j().format(_dateTime);

  String get jm => DateFormat.jm().format(_dateTime);

  String get jms => DateFormat.jms().format(_dateTime);

  String fromNow({bool withoutPrefixAndSuffix = false}) {
    return _defaultLocale.getRelativeTime(_dateTime,
        omitPrefixAndSuffix: withoutPrefixAndSuffix);
  }

  String from(var input, {bool withoutPrefixAndSuffix = false}) {
    var dateTime = _parse(input);
    return _defaultLocale.getRelativeTime(_dateTime,
        date2: dateTime, omitPrefixAndSuffix: withoutPrefixAndSuffix);
  }

  num diff(var input, [Units units = Units.MILLISECOND, bool asFloat = false]) {
    var dateTime = _parse(input);
    num diff;

    var dt1 = _dateTime.millisecondsSinceEpoch;
    var dt2 = dateTime.millisecondsSinceEpoch;

    switch (units) {
      case Units.MILLISECOND:
        diff = dt1 - dt2;
        break;
      case Units.SECOND:
        diff = (dt1 - dt2) / Duration.millisecondsPerSecond;
        break;
      case Units.MINUTE:
        diff = (dt1 - dt2) / Duration.millisecondsPerMinute;
        break;
      case Units.HOUR:
        diff = (dt1 - dt2) / Duration.millisecondsPerHour;
        break;
      case Units.DAY:
        diff = (dt1 - dt2) / Duration.millisecondsPerDay;
        break;
      case Units.WEEK:
        diff = ((dt1 - dt2) / Duration.millisecondsPerDay) / 7;
        break;
      case Units.MONTH:
        diff = _monthDiff(_dateTime, dateTime);
        break;
      case Units.YEAR:
        diff = _monthDiff(_dateTime, dateTime) / 12;
        break;
    }
    if (!asFloat) return _absFloor(diff);
    return diff;
  }

  num _monthDiff(DateTime a, DateTime b) {
    var wholeMonthDiff = ((b.year - a.year) * 12) + (b.month - a.month);
    var anchor = _addMonths(a, wholeMonthDiff);
    var anchor2;
    var adjust;

    if (b.millisecondsSinceEpoch - anchor.millisecondsSinceEpoch < 0) {
      anchor2 = _addMonths(a, wholeMonthDiff - 1);
      adjust = (b.millisecondsSinceEpoch - anchor.millisecondsSinceEpoch) /
          (anchor.millisecondsSinceEpoch - anchor2.millisecondsSinceEpoch);
    } else {
      anchor2 = _addMonths(a, wholeMonthDiff + 1);
      adjust = (b.millisecondsSinceEpoch - anchor.millisecondsSinceEpoch) /
          (anchor2.millisecondsSinceEpoch - anchor.millisecondsSinceEpoch);
    }
    return -(wholeMonthDiff + adjust);
  }

  int _absFloor(num number) {
    if (number < 0) {
      return number.ceil();
    } else {
      return number.floor();
    }
  }

  int valueOf() {
    return _dateTime.millisecondsSinceEpoch;
  }

  int unix() {
    return (_dateTime.millisecondsSinceEpoch / 1000).round();
  }

//  QUERY
  bool isBefore(var input, [Units units = Units.MILLISECOND]) {
    var dateTime = _parse(input);
    if (units == Units.MILLISECOND) {
      return valueOf() < dateTime.millisecondsSinceEpoch;
    }
    var endOfMs = (clone()..endOf(units)).valueOf();
    return endOfMs < dateTime.millisecondsSinceEpoch;
  }

  bool isAfter(var input, [Units units = Units.MILLISECOND]) {
    var dateTime = _parse(input);
    if (units == Units.MILLISECOND) {
      return valueOf() > dateTime.millisecondsSinceEpoch;
    }
    var startOfMs = (clone()..startOf(units)).valueOf();
    return dateTime.millisecondsSinceEpoch < startOfMs;
  }

  bool isSame(var input, [Units units = Units.MILLISECOND]) {
    var dateTime = _parse(input);
    if (units == Units.MILLISECOND) {
      return valueOf() == dateTime.millisecondsSinceEpoch;
    }
    var startOfMs = (clone()..startOf(units)).valueOf();
    var endOfMs = (clone()..endOf(units)).valueOf();
    var dateTimeMs = dateTime.millisecondsSinceEpoch;
    return startOfMs <= dateTimeMs && dateTimeMs <= endOfMs;
  }

  bool isSameOrBefore(var input, [Units units = Units.MILLISECOND]) {
    var dateTime = _parse(input);
    return isSame(dateTime, units) || isBefore(dateTime, units);
  }

  bool isSameOrAfter(var input, [Units units = Units.MILLISECOND]) {
    var dateTime = _parse(input);
    return isSame(dateTime, units) || isAfter(dateTime, units);
  }

  bool isBetween(var inputFrom, var inputTo,
      [Units units = Units.MILLISECOND]) {
    var dateTimeFrom = _parse(inputFrom);
    var dateTimeTo = _parse(inputTo);
    return isAfter(dateTimeFrom, units) && isBefore(dateTimeTo, units);
  }

  bool _isLeapYear(int year) =>
      (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0));

  bool get isLeapYear => _isLeapYear(_dateTime.year);

  static bool isJiffy(var input) => input is Jiffy;

  static bool isDateTime(var input) => input is DateTime;
}
