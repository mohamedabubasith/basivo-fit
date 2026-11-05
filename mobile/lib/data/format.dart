/// Small, locale-free formatters (12-hour clock, short weekday) used across the app.
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _longDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String clock(DateTime t) {
  final l = t.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  return '$h:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'AM' : 'PM'}';
}

String hourLabel(DateTime t) {
  final l = t.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  return '$h ${l.hour < 12 ? 'AM' : 'PM'}';
}

String weekday(DateTime t) => _days[t.toLocal().weekday - 1];
String longDate(DateTime t) {
  final l = t.toLocal();
  return '${_longDays[l.weekday - 1]}, ${l.day} ${_months[l.month - 1]}';
}

String num0(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// "6 h 54 min"
String hm(num minutes) => '${minutes ~/ 60} h ${(minutes % 60).round()} min';

/// "6h 54m" or "24 min"
String dur(num minutes) {
  final h = minutes ~/ 60, m = (minutes % 60).round();
  return h > 0 ? '${h}h ${m}m' : '$m min';
}

String fromSeconds(num s) => dur(s / 60);
