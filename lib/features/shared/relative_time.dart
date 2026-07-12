import 'package:intl/intl.dart';

/// Compact relative timestamp for feed rows:
/// "Just now", "2m ago", "3h ago", "Yesterday", "Tuesday", "4 Mar".
String relativeTime(DateTime time, {DateTime? relativeTo}) {
  final now = relativeTo ?? DateTime.now();
  final diff = now.difference(time);

  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';

  final startOfToday = DateTime(now.year, now.month, now.day);
  if (!time.isBefore(startOfToday)) return '${diff.inHours}h ago';

  final startOfYesterday = startOfToday.subtract(const Duration(days: 1));
  if (!time.isBefore(startOfYesterday)) return 'Yesterday';
  if (diff.inDays < 7) return DateFormat('EEEE').format(time);
  if (time.year == now.year) return DateFormat('d MMM').format(time);
  return DateFormat('d MMM yyyy').format(time);
}

/// Day header label for grouped timelines:
/// "Today", "Yesterday", "Tuesday", "4 March", "4 March 2025".
String dayLabel(DateTime day, {DateTime? relativeTo}) {
  final now = relativeTo ?? DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final d = DateTime(day.year, day.month, day.day);
  final delta = startOfToday.difference(d).inDays;

  if (delta <= 0) return 'Today';
  if (delta == 1) return 'Yesterday';
  if (delta < 7) return DateFormat('EEEE').format(d);
  if (d.year == now.year) return DateFormat('d MMMM').format(d);
  return DateFormat('d MMMM yyyy').format(d);
}
