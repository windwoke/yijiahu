export interface CaregiverRecord {
  id: string;
  careRecipientId: string;
  caregiverId: string;
  caregiverNickname?: string;
  caregiverAvatar?: string;
  periodStart: string;
  periodEnd?: string;
  note?: string;
  createdAt: string;
  /** 格式化为 "YYYY年MM月DD日 - YYYY年MM月DD日" 或进行中 */
  periodLabel?: string;
  isCurrent?: boolean;
}
