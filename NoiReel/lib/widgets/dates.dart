// Dates written out in English, without adding the intl package

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Nov 8, 2026"
String formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// "Thu, Nov 26, 2026"
String formatDateWithDay(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${formatDate(d)}';

/// Today's date with no time
DateTime today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
