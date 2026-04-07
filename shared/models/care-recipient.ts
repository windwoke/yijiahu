/**
 * 照护对象模型
 * 对应后端 CareRecipient 实体
 */

/** 用药进度状态 */
export interface TodayMedicationStatus {
  total: number;
  taken: number;
  progress: number; // 0-100
}

/** 健康记录 */
export interface HealthRecord {
  id: string;
  recipientId: string;
  type: 'blood_pressure' | 'blood_glucose' | 'weight' | 'temperature' | 'heart_rate' | 'oxygen_saturation';
  value: string; // 如 "120/80"
  recordedAt: string;
  note?: string;
  recordedBy?: {
    id: string;
    name: string;
  };
}

/** 照护对象 */
export interface CareRecipient {
  id: string;
  name: string;
  avatarEmoji: string | null;
  avatarUrl: string | null;
  phone: string | null;
  birthDate: string | null;
  age: number | null;
  gender: 'male' | 'female' | 'other' | null;
  bloodType: string | null;
  allergies: string[];
  chronicConditions: string[];
  medicalHistory: string | null;
  emergencyContact: string | null;
  emergencyPhone: string | null;
  hospital: string | null;
  department: string | null;
  doctorName: string | null;
  doctorPhone: string | null;
  currentAddress: string | null;
  latitude: number | null;
  longitude: number | null;
  isActive: boolean;
  todayMedicationStatus: TodayMedicationStatus | null;
}

/** 照护对象摘要（用于下拉选择） */
export interface CareRecipientMini {
  id: string;
  name: string;
  avatarEmoji: string | null;
  avatarUrl: string | null;
}
