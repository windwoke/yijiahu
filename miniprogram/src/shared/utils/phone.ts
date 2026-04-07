/**
 * 手机号工具函数
 */

/** 验证中国大陆手机号格式 */
export function isValidPhone(phone: string): boolean {
  return /^1[3-9]\d{9}$/.test(phone);
}

/** 手机号脱敏：138****5678 */
export function maskPhone(phone: string): string {
  if (phone.length !== 11) return phone;
  return phone.replace(/(\d{3})\d{4}(\d{4})/, '$1****$2');
}

/** 格式化手机号显示：138 5678 5678 */
export function formatPhone(phone: string): string {
  if (phone.length !== 11) return phone;
  return phone.replace(/(\d{3})(\d{4})(\d{4})/, '$1 $2 $3');
}
