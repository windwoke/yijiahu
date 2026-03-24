/// 日期工具
library;

import 'package:intl/intl.dart';

class DateUtils {
  DateUtils._();

  static final _dateFormat = DateFormat('yyyy-MM-dd');
  static final _timeFormat = DateFormat('HH:mm');
  static final _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final _monthDayFormat = DateFormat('M月d日');
  static final _weekdayFormat = DateFormat('EEEE');

  /// 格式化日期 yyyy-MM-dd
  static String formatDate(DateTime date) => _dateFormat.format(date);

  /// 格式化时间 HH:mm
  static String formatTime(DateTime date) => _timeFormat.format(date);

  /// 格式化日期时间
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);

  /// 格式化月日 3月24日
  static String formatMonthDay(DateTime date) => _monthDayFormat.format(date);

  /// 格式化星期几
  static String formatWeekday(DateTime date) => _weekdayFormat.format(date);

  /// 获取今天是星期几
  static String get todayWeekday {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = DateTime.now().weekday;
    return weekdays[weekday - 1];
  }

  /// 判断是否是今天
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// 判断是否是昨天
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// 获取相对日期描述
  static String getRelativeDate(DateTime date) {
    if (isToday(date)) return '今天';
    if (isYesterday(date)) return '昨天';
    return formatMonthDay(date);
  }

  /// 计算年龄
  static int calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  /// 获取今天的日期字符串
  static String get todayDateStr => formatDate(DateTime.now());

  /// 获取当前时间字符串
  static String get nowTimeStr => formatTime(DateTime.now());
}
