/**
 * 图片 URL 工具
 * 后端返回 OSS 相对路径，需拼接 OSS 基础地址
 */

/** OSS 基础地址 */
const OSS_BASE = 'https://yijiahu.oss-cn-guangzhou.aliyuncs.com';

/**
 * 根据相对路径返回完整图片 URL
 * - null/undefined/空字符串 → ''
 * - 已经是 http/https 开头 → 直接返回
 * - 相对路径 → 拼接 OSS_BASE
 */
export function getImageUrl(path: string | null | undefined): string {
  if (!path) return '';
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  return `${OSS_BASE}/${path}`;
}
