/**
 * 复诊预约模型
 * 对应后端 Appointment 实体
 */

/** 接送人 */
export interface DriverMini {
  id: string;
  name: string;
  phone: string;
  avatar: string | null;
}

/** 照护对象摘要 */
export interface CareRecipientMini {
  id: string;
  name: string;
  avatarEmoji: string | null;
  avatarUrl: string | null;
}

/** 复诊状态 */
export type AppointmentStatus = 'upcoming' | 'completed' | 'cancelled';

/** 复诊预约 */
export interface Appointment {
  id: string;
  recipientId: string;
  recipient: CareRecipientMini;
  hospital: string;
  department: string | null;
  doctorName: string | null;
  doctorPhone: string | null;
  appointmentTime: string; // ISO 8601
  appointmentNo: string | null;
  address: string | null;
  latitude: number | null;
  longitude: number | null;
  fee: number | null;
  purpose: string | null;
  status: AppointmentStatus;
  assignedDriverId: string | null;
  assignedDriver: DriverMini | null;
  reminder48h: boolean;
  reminder24h: boolean;
  note: string | null;
  createdAt: string;
  // 派生字段
  displayTime: string; // 本地化时间
  statusLabel: string;
  isUpcoming: boolean;
}
