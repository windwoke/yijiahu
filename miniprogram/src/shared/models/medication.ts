/**
 * 药品模型
 * 对应后端 Medication 实体
 */

/** 用药频率 */
export enum MedicationFrequency {
  DAILY = 'daily',
  WEEKLY = 'weekly',
  AS_NEEDED = 'as_needed',
}

export const MEDICATION_FREQUENCY_LABELS: Record<MedicationFrequency, string> = {
  [MedicationFrequency.DAILY]: '每日',
  [MedicationFrequency.WEEKLY]: '每周',
  [MedicationFrequency.AS_NEEDED]: '按需',
};

/** 用药打卡状态 */
export enum MedicationLogStatus {
  PENDING = 'pending',
  TAKEN = 'taken',
  SKIPPED = 'skipped',
  MISSED = 'missed',
}

/** 单次用药时间状态 */
export interface MedicationTimeStatus {
  status: MedicationLogStatus;
  takenBy: string | null;
  actualTime: string | null;
  photoUrl: string | null;
}

/** 今日药品打卡汇总（对齐 Flutter TodayMedicationSummary） */
export interface TodayMedicationSummary {
  recipientId: string;
  recipientName: string | null;
  recipientAvatar: string | null;
  date: string; // "yyyy-MM-dd"
  total: number;
  completed: number; // 等价于 taken
  pending: number;
  // 后端返回 items，对齐 Flutter 字段名
  items: MedicationLogItem[];
}

/** 单条药品打卡记录（对齐 Flutter MedicationLogItem） */
export interface MedicationLogItem {
  id: string;
  medicationId: string;
  medicationName: string;
  dosage: string;
  scheduledTime: string; // "HH:mm"
  status: MedicationLogStatus;
  canCheckIn: boolean;
  actualTime: string | null;
  takenBy: MedicationLogTaker | null;
  photoUrl: string | null;
}

/** 打卡人信息（对齐 Flutter MedicationLogTaker） */
export interface MedicationLogTaker {
  id: string;
  name: string;
  avatar: string | null;
}

/** 药品 */
export interface Medication {
  id: string;
  recipientId: string;
  name: string;
  realName: string | null;
  dosage: string;
  unit: string | null;
  frequency: MedicationFrequency;
  times: string[]; // ["08:00", "20:00"]
  instructions: string | null;
  startDate: string;
  endDate: string | null;
  prescribedBy: string | null;
  isActive: boolean;
  todayStatus: Record<string, MedicationTimeStatus> | null;
}

/** 用药打卡记录 */
export interface MedicationLog {
  id: string;
  medicationId: string;
  medicationName: string;
  recipientId: string;
  scheduledTime: string;
  status: MedicationLogStatus;
  actualTime: string | null;
  dosage: string;
  takenBy: {
    id: string;
    name: string;
    avatar: string | null;
  } | null;
  photoUrl: string | null;
  createdAt: string;
}
