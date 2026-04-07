/**
 * 每日护理打卡模型
 * 对应后端 DailyCareCheckin 实体
 */

/** 打卡状态 */
export enum CheckinStatus {
  NORMAL = 'normal',
  CONCERNING = 'concerning',
  POOR = 'poor',
  CRITICAL = 'critical',
}

export const CHECKIN_STATUS_LABELS: Record<CheckinStatus, string> = {
  [CheckinStatus.NORMAL]: '正常',
  [CheckinStatus.CONCERNING]: '需关注',
  [CheckinStatus.POOR]: '较差',
  [CheckinStatus.CRITICAL]: '危险',
};

export const CHECKIN_STATUS_EMOJIS: Record<CheckinStatus, string> = {
  [CheckinStatus.NORMAL]: '😊',
  [CheckinStatus.CONCERNING]: '😐',
  [CheckinStatus.POOR]: '😟',
  [CheckinStatus.CRITICAL]: '🆘',
};

/** 每日护理打卡 */
export interface DailyCareCheckin {
  id: string;
  careRecipientId: string;
  checkinDate: string; // "yyyy-MM-dd"
  status: CheckinStatus;
  medicationCompleted: number;
  medicationTotal: number;
  specialNote: string | null;
  checkedInBy: {
    id: string;
    name: string;
    avatar: string | null;
  } | null;
  createdAt: string;
  // 派生
  medicationLabel: string; // "3/5 已完成"
}
