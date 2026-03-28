import 'appointment.dart';

/// 家庭任务模型
class FamilyTask {
  final String id;
  final String familyId;
  final String? recipientId;
  final CareRecipientMini? recipient;
  final String title;
  final String? description;
  final String frequency; // once, daily, weekly, monthly
  final String? scheduledTime; // HH:mm
  final List<int>? scheduledDay;
  final String assigneeId;
  final AssigneeMini? assignee;
  final String status; // pending, completed, cancelled
  final DateTime? nextDueAt;
  final String? note;
  final DateTime createdAt;

  FamilyTask({
    required this.id,
    required this.familyId,
    this.recipientId,
    this.recipient,
    required this.title,
    this.description,
    required this.frequency,
    this.scheduledTime,
    this.scheduledDay,
    required this.assigneeId,
    this.assignee,
    required this.status,
    this.nextDueAt,
    this.note,
    required this.createdAt,
  });

  factory FamilyTask.fromJson(Map<String, dynamic> json) {
    return FamilyTask(
      id: json['id'] ?? '',
      familyId: json['familyId'] ?? '',
      recipientId: json['recipientId'],
      recipient: json['recipient'] != null
          ? CareRecipientMini.fromJson(json['recipient'])
          : null,
      title: json['title'] ?? '',
      description: json['description'],
      frequency: json['frequency'] ?? 'once',
      scheduledTime: json['scheduledTime'],
      scheduledDay: (json['scheduledDay'] as List<dynamic>?)
          ?.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
          .toList(),
      assigneeId: json['assigneeId'] ?? '',
      assignee: json['assignee'] != null
          ? AssigneeMini.fromJson(json['assignee'])
          : null,
      status: json['status'] ?? 'pending',
      nextDueAt: json['nextDueAt'] != null
          ? (DateTime.tryParse(json['nextDueAt'].toString()) ?? DateTime.now())
          : null,
      note: json['note'],
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  String get frequencyLabel {
    switch (frequency) {
      case 'daily':
        return '每日';
      case 'weekly':
        return '每周';
      case 'monthly':
        return '每月';
      default:
        return '单次';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'completed':
        return '已完成';
      case 'cancelled':
        return '已取消';
      default:
        return '待完成';
    }
  }

  bool get isRecurring => frequency != 'once';
  bool get isPending => status == 'pending';

  String get displayDueAt {
    if (nextDueAt == null) return '';
    final d = nextDueAt!;
    if (scheduledTime != null) {
      return '${d.month}月${d.day}日 $scheduledTime';
    }
    return '${d.year}年${d.month}月${d.day}日';
  }
}

class AssigneeMini {
  final String id;
  final String name; // 昵称（来自 FamilyMember.nickname）
  final String? avatarUrl;
  final String? nickname; // 备用（与 name 相同来源）

  AssigneeMini({required this.id, required this.name, this.avatarUrl, this.nickname});

  factory AssigneeMini.fromJson(Map<String, dynamic> json) {
    return AssigneeMini(
      id: json['id'] ?? '',
      name: json['nickname'] ?? json['name'] ?? json['phone'] ?? '',
      avatarUrl: json['avatarUrl'],
      nickname: json['nickname'] as String?,
    );
  }

  /// 显示名称：截断超长昵称
  String get displayName {
    if (name.length > 4) return '${name.substring(0, 4)}…';
    return name;
  }
}
