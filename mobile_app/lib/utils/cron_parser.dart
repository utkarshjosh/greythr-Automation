class CronParser {
  /// Parse a cron expression and return the next scheduled time
  /// Format: minute hour day month weekday
  /// Example: "0 9 * * *" = 9:00 AM daily
  static DateTime? getNextScheduledTime(String cron) {
    try {
      final parts = cron.trim().split(RegExp(r'\s+'));
      if (parts.length < 5) {
        return null;
      }

      final minute = int.tryParse(parts[0]) ?? 0;
      final hour = int.tryParse(parts[1]) ?? 9;
      
      // Validate time
      if (minute < 0 || minute > 59 || hour < 0 || hour > 23) {
        return null;
      }

      final now = DateTime.now();
      var nextTime = DateTime(now.year, now.month, now.day, hour, minute);

      // If the time has already passed today, schedule for tomorrow
      if (nextTime.isBefore(now)) {
        nextTime = nextTime.add(const Duration(days: 1));
      }

      // Handle weekday constraints (parts[4])
      if (parts[4] != '*') {
        final targetWeekday = _parseWeekday(parts[4]);
        if (targetWeekday != null) {
          // Find next occurrence of the weekday
          while (nextTime.weekday != targetWeekday) {
            nextTime = nextTime.add(const Duration(days: 1));
          }
        }
      }

      // Handle day of month constraints (parts[2])
      if (parts[2] != '*') {
        final targetDay = int.tryParse(parts[2]);
        if (targetDay != null && targetDay >= 1 && targetDay <= 31) {
          // Find next occurrence of the day
          while (nextTime.day != targetDay) {
            nextTime = nextTime.add(const Duration(days: 1));
          }
        }
      }

      return nextTime;
    } catch (e) {
      print('Error parsing cron: $e');
      return null;
    }
  }

  /// Parse weekday from cron expression
  /// 0 or 7 = Sunday, 1 = Monday, ..., 6 = Saturday
  static int? _parseWeekday(String weekdayStr) {
    if (weekdayStr == '*') return null;
    
    // Handle ranges like "1-5" (Monday to Friday)
    if (weekdayStr.contains('-')) {
      final range = weekdayStr.split('-');
      if (range.length == 2) {
        final start = int.tryParse(range[0]);
        final end = int.tryParse(range[1]);
        if (start != null && end != null) {
          final now = DateTime.now();
          final currentWeekday = now.weekday;
          // Return the next weekday in the range
          if (currentWeekday >= start && currentWeekday <= end) {
            return currentWeekday;
          } else if (currentWeekday < start) {
            return start;
          } else {
            return start; // Next week
          }
        }
      }
    }
    
    // Handle comma-separated values like "1,3,5"
    if (weekdayStr.contains(',')) {
      final weekdays = weekdayStr.split(',').map((e) => int.tryParse(e.trim())).whereType<int>().toList();
      if (weekdays.isNotEmpty) {
        final now = DateTime.now();
        final currentWeekday = now.weekday;
        // Find next weekday in the list
        for (var wd in weekdays) {
          if (wd >= currentWeekday) {
            return wd;
          }
        }
        return weekdays.first; // Next week
      }
    }
    
    final weekday = int.tryParse(weekdayStr);
    if (weekday != null && weekday >= 0 && weekday <= 7) {
      // Convert 0/7 (Sunday) to 7 for Dart DateTime
      return weekday == 0 ? 7 : weekday;
    }
    
    return null;
  }

  /// Get minutes until next scheduled time
  static int? getMinutesUntilNext(String cron) {
    final nextTime = getNextScheduledTime(cron);
    if (nextTime == null) return null;
    
    final now = DateTime.now();
    final difference = nextTime.difference(now);
    return difference.inMinutes;
  }

  /// Format next scheduled time as a readable string
  static String formatNextScheduledTime(String cron) {
    final nextTime = getNextScheduledTime(cron);
    if (nextTime == null) return 'Invalid schedule';
    
    final now = DateTime.now();
    final difference = nextTime.difference(now);
    
    if (difference.inDays > 0) {
      return '${nextTime.day}/${nextTime.month}/${nextTime.year} at ${nextTime.hour.toString().padLeft(2, '0')}:${nextTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inHours > 0) {
      return 'Today at ${nextTime.hour.toString().padLeft(2, '0')}:${nextTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${nextTime.hour.toString().padLeft(2, '0')}:${nextTime.minute.toString().padLeft(2, '0')}';
    }
  }
}



