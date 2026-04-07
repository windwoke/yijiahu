/**
 * 日期工具函数
 * 对应 Flutter 的 date_utils.dart
 */

/** 格式化日期为 "yyyy-MM-dd" */
export function formatDate(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/** 格式化时间为 "HH:mm" */
export function formatTime(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  const hours = String(d.getHours()).padStart(2, '0');
  const minutes = String(d.getMinutes()).padStart(2, '0');
  return `${hours}:${minutes}`;
}

/** 格式化完整时间为 "yyyy-MM-dd HH:mm" */
export function formatDateTime(date: Date | string): string {
  return `${formatDate(date)} ${formatTime(date)}`;
}

/** 北京时区偏移（UTC+8） */
const BEIJING_OFFSET = 8 * 60;

/**
 * 将 UTC 时间转换为北京时间显示
 * @param utcDate ISO 8601 UTC 时间字符串
 */
export function toBeijingTime(utcDate: string): string {
  const date = new Date(utcDate);
  // 转换为北京时间：UTC + 8小时
  const beijingDate = new Date(date.getTime() + BEIJING_OFFSET * 60 * 1000);
  return formatDateTime(beijingDate);
}

/**
 * 将北京时间字符串转为 UTC ISO 格式（用于 API 提交）
 * @param beijingTime 北京时间 "yyyy-MM-dd HH:mm"
 */
export function fromBeijingTime(beijingTime: string): string {
  const [datePart, timePart] = beijingTime.split(' ');
  const [year, month, day] = datePart.split('-').map(Number);
  const [hour, minute] = timePart.split(':').map(Number);
  // 北京时间转为 UTC：北京时间 - 8小时
  const utcDate = new Date(Date.UTC(year, month - 1, day, hour, minute) - BEIJING_OFFSET * 60 * 1000);
  return utcDate.toISOString();
}

/** 获取今天的日期字符串 "yyyy-MM-dd" */
export function today(): string {
  return formatDate(new Date());
}

/** 判断两个日期是否是同一天 */
export function isSameDay(date1: Date | string, date2: Date | string): boolean {
  return formatDate(date1) === formatDate(date2);
}

/** 获取日期的相对描述 */
export function getRelativeDate(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  const todayStr = today();
  const dateStr = formatDate(d);

  if (dateStr === todayStr) return '今天';
  const tomorrow = new Date(Date.now() + 86400000);
  if (formatDate(tomorrow) === dateStr) return '明天';
  const yesterday = new Date(Date.now() - 86400000);
  if (formatDate(yesterday) === dateStr) return '昨天';

  return dateStr;
}

/** 计算年龄 */
export function calculateAge(birthDate: string): number {
  const birth = new Date(birthDate);
  const today = new Date();
  let age = today.getFullYear() - birth.getFullYear();
  const monthDiff = today.getMonth() - birth.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) {
    age--;
  }
  return age;
}
