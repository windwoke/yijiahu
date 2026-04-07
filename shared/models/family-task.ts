/**
 * 家庭任务模型
 * 对应后端 FamilyTask 实体
 */

/** 任务频率 */
export type TaskFrequency = 'once' | 'daily' | 'weekly' | 'monthly';

export const TASK_FREQUENCY_LABELS: Record<TaskFrequency, string> = {
  once: '一次性',
  daily: '每日',
  weekly: '每周',
  monthly: '每月',
};

/** 任务状态 */
export type TaskStatus = 'pending' | 'completed' | 'cancelled';

/** 任务完成记录 */
export interface TaskCompletion {
  id: string;
  taskId: string;
  completedById: string;
  completedBy: {
    id: string;
    name: string;
    avatar: string | null;
  };
  completedAt: string;
  displayCompletedAt: string; // 本地化时间（UTC+8）
  note: string | null;
  scheduledDate?: string;
}

/** 任务指派人 */
export interface AssigneeMini {
  id: string;
  name: string;
  avatar: string | null;
}

/** 家庭任务 */
export interface FamilyTask {
  id: string;
  familyId: string;
  recipientId: string | null;
  recipient: {
    id: string;
    name: string;
    avatarEmoji: string | null;
    avatarUrl: string | null;
  } | null;
  title: string;
  description: string | null;
  frequency: TaskFrequency;
  scheduledTime: string | null; // "HH:mm"
  scheduledDay: number[] | null; // [1,3,5] 表示周一三五
  assigneeId: string;
  assignee: AssigneeMini;
  status: TaskStatus;
  nextDueAt: string | null;
  note: string | null;
  createdAt: string;
  // 前端派生
  frequencyLabel: string;
  statusLabel: string;
  isRecurring: boolean;
  isPending: boolean;
  displayDueAt: string | null;
}

/** 日历任务视图 */
export interface CalendarTask {
  id: string;
  title: string;
  scheduledDate: string; // "yyyy-MM-dd"
  scheduledTime: string | null;
  assignee: AssigneeMini;
  recipientName: string | null;
  status: TaskStatus;
  frequency: TaskFrequency;
}
