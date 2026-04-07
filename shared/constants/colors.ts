/**
 * 品牌色彩常量
 * 对应 Flutter 的 AppColors.dart
 * 转为 CSS 变量供小程序使用，同时保留 TS 常量供逻辑判断
 */

/* ============================
   品牌主色：鼠尾草绿
   ============================ */
export const PRIMARY = '#7B9E87';
export const PRIMARY_LIGHT = '#A3BDA6';
export const PRIMARY_DARK = '#5C8268';

/* ============================
   辅助色：暖杏/珊瑚
   ============================ */
export const CORAL = '#E07B5D';
export const CORAL_LIGHT = '#F09A7E';

/* ============================
   静谧蓝（图表/数据）
   ============================ */
export const BLUE = '#4A90D9';

/* ============================
   背景色
   ============================ */
export const BACKGROUND = '#FAF9F7';
export const SURFACE = '#FFFFFF';
export const SURFACE_GRAY = '#F5F5F5';

/* ============================
   文字色
   ============================ */
export const TEXT_PRIMARY = '#2C2C2C';
export const TEXT_SECONDARY = '#6B6B6B';
export const TEXT_TERTIARY = '#B0ADAD';

/* ============================
   状态色
   ============================ */
export const SUCCESS = '#6BA07E';
export const WARNING = '#D4A855';
export const ERROR = '#E07B5D';
export const INFO = '#4A90D9';

/* ============================
   健康数据色
   ============================ */
export const BP_HIGH = '#E07B5D';
export const BP_NORMAL = '#6BA07E';
export const BP_ELEVATED = '#D4A855';

/* ============================
   边框/分隔
   ============================ */
export const BORDER = '#E8E6E2';
export const BORDER_LIGHT = '#F0EEEB';

/* ============================
   CSS 变量字符串（可注入小程序的 app.scss）
   ============================ */
export const CSS_VARS = `
:root {
  --color-primary: ${PRIMARY};
  --color-primary-light: ${PRIMARY_LIGHT};
  --color-primary-dark: ${PRIMARY_DARK};
  --color-coral: ${CORAL};
  --color-coral-light: ${CORAL_LIGHT};
  --color-blue: ${BLUE};
  --color-background: ${BACKGROUND};
  --color-surface: ${SURFACE};
  --color-surface-gray: ${SURFACE_GRAY};
  --color-text-primary: ${TEXT_PRIMARY};
  --color-text-secondary: ${TEXT_SECONDARY};
  --color-text-tertiary: ${TEXT_TERTIARY};
  --color-success: ${SUCCESS};
  --color-warning: ${WARNING};
  --color-error: ${ERROR};
  --color-info: ${INFO};
  --color-bp-high: ${BP_HIGH};
  --color-bp-normal: ${BP_NORMAL};
  --color-bp-elevated: ${BP_ELEVATED};
  --color-border: ${BORDER};
  --color-border-light: ${BORDER_LIGHT};
}
`.trim();

/** 药品打卡状态对应的颜色 */
export const MEDICATION_STATUS_COLORS: Record<string, string> = {
  pending: TEXT_TERTIARY,
  taken: SUCCESS,
  skipped: WARNING,
  missed: ERROR,
};

/** 打卡状态对应的颜色 */
export const CHECKIN_STATUS_COLORS: Record<string, string> = {
  normal: SUCCESS,
  concerning: WARNING,
  poor: CORAL,
  critical: ERROR,
};
