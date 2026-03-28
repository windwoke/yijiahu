/// 家庭模型
library;

import 'package:equatable/equatable.dart';

enum SubscriptionPlan { free, premium, annual }

/// 家庭成员角色枚举
/// - owner: 家庭管理员（最高权限，不能降级自己）
/// - coordinator: 协调管理员（日常管理）
/// - caregiver: 照护人（记录日志+完成任务）
/// - guest: 访客（只读+记录日志）
enum FamilyMemberRole {
  owner,
  coordinator,
  caregiver,
  guest;

  String get label {
    switch (this) {
      case FamilyMemberRole.owner:
        return '管理员';
      case FamilyMemberRole.coordinator:
        return '协调管理员';
      case FamilyMemberRole.caregiver:
        return '照护人';
      case FamilyMemberRole.guest:
        return '访客';
    }
  }

  /// 是否能管理家庭设置（仅 owner）
  bool get canManageFamily => this == FamilyMemberRole.owner;

  /// 是否能管理成员（owner + coordinator）
  bool get canManageMembers =>
      this == FamilyMemberRole.owner || this == FamilyMemberRole.coordinator;

  /// 是否能管理照护对象（owner + coordinator）
  bool get canManageRecipients =>
      this == FamilyMemberRole.owner || this == FamilyMemberRole.coordinator;

  /// 是否能创建复诊（owner + coordinator）
  bool get canCreateAppointment =>
      this == FamilyMemberRole.owner || this == FamilyMemberRole.coordinator;

  /// 是否能创建/编辑任务（owner + coordinator）
  bool get canManageTask =>
      this == FamilyMemberRole.owner || this == FamilyMemberRole.coordinator;

  /// 是否能完成任务（包括自己的任务）
  /// - owner/coordinator: 任何任务
  /// - caregiver: 分配给自己的任务
  /// - guest: 不能完成任务
  bool get canCompleteTask =>
      this == FamilyMemberRole.owner ||
      this == FamilyMemberRole.coordinator ||
      this == FamilyMemberRole.caregiver;

  /// 是否能记录照护日志（所有角色）
  bool get canRecordCareLog => true;

  /// 是否能添加健康记录（owner + coordinator + caregiver，不含 guest）
  bool get canAddHealthRecord =>
      this == FamilyMemberRole.owner ||
      this == FamilyMemberRole.coordinator ||
      this == FamilyMemberRole.caregiver;

  /// 是否能做每日护理打卡（owner + coordinator + caregiver，不含 guest）
  bool get canCheckin =>
      this == FamilyMemberRole.owner ||
      this == FamilyMemberRole.coordinator ||
      this == FamilyMemberRole.caregiver;

  static FamilyMemberRole fromString(String? s) {
    switch (s) {
      case 'owner':
        return FamilyMemberRole.owner;
      case 'coordinator':
        return FamilyMemberRole.coordinator;
      case 'caregiver':
        return FamilyMemberRole.caregiver;
      case 'guest':
        return FamilyMemberRole.guest;
      default:
        return FamilyMemberRole.guest;
    }
  }
}

/// 家庭
class Family extends Equatable {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? description;
  final String inviteCode;
  final String role; // owner/admin/member/viewer
  final SubscriptionPlan subscriptionPlan;
  final DateTime? subscriptionExpiresAt;
  final int memberCount;
  final int recipientCount;
  final DateTime createdAt;

  const Family({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.description,
    required this.inviteCode,
    required this.role,
    this.subscriptionPlan = SubscriptionPlan.free,
    this.subscriptionExpiresAt,
    this.memberCount = 0,
    this.recipientCount = 0,
    required this.createdAt,
  });

  factory Family.fromJson(Map<String, dynamic> json) {
    return Family(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      description: json['description'] as String?,
      inviteCode: json['inviteCode'] as String? ?? json['invite_code'] as String? ?? '',
      role: json['myRole'] as String? ?? json['role'] as String? ?? 'coordinator',
      subscriptionPlan: _parsePlan(json['subscriptionPlan'] as String? ?? json['subscription_plan'] as String?),
      subscriptionExpiresAt: json['subscriptionExpiresAt'] != null
          ? DateTime.parse(json['subscriptionExpiresAt'] as String)
          : (json['subscription_expires_at'] != null
              ? DateTime.parse(json['subscription_expires_at'] as String)
              : null),
      memberCount: json['memberCount'] as int? ?? json['member_count'] as int? ?? 0,
      recipientCount: json['recipientCount'] as int? ?? json['recipient_count'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  static SubscriptionPlan _parsePlan(String? plan) {
    switch (plan) {
      case 'premium':
        return SubscriptionPlan.premium;
      case 'annual':
        return SubscriptionPlan.annual;
      default:
        return SubscriptionPlan.free;
    }
  }

  bool get isPremium =>
      subscriptionPlan != SubscriptionPlan.free &&
      (subscriptionExpiresAt?.isAfter(DateTime.now()) ?? false);

  /// 当前用户在此家庭中的角色
  FamilyMemberRole get myRole => FamilyMemberRole.fromString(role);

  @override
  List<Object?> get props => [
        id,
        name,
        avatarUrl,
        description,
        inviteCode,
        role,
        subscriptionPlan,
        subscriptionExpiresAt,
      ];
}

/// 家庭成员
class FamilyMember extends Equatable {
  final String id;
  final String? userId;
  final String nickname;
  final String role;
  final String? avatarUrl;
  final String? phone;
  final bool isOnline;
  final DateTime joinedAt;
  final String? userName; // 真实姓名（来自 User.name）

  const FamilyMember({
    required this.id,
    this.userId,
    required this.nickname,
    required this.role,
    this.avatarUrl,
    this.phone,
    this.isOnline = false,
    required this.joinedAt,
    this.userName,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String?,
      nickname: json['nickname'] as String? ?? '',
      role: json['role'] as String? ?? 'coordinator',
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      isOnline: json['isOnline'] as bool? ?? json['is_online'] as bool? ?? false,
      joinedAt: DateTime.tryParse(json['joinedAt'] as String? ?? json['joined_at'] as String? ?? '') ?? DateTime.now(),
      userName: json['userName'] as String?,
    );
  }

  String get roleLabel {
    return FamilyMemberRole.fromString(role).label;
  }

  /// 截断超长文本
  static String _truncate(String s, int max) => s.length > max ? '${s.substring(0, max)}…' : s;

  /// 显示名称：昵称（用户名），相同则只显示一个，超长截断（合计最多10字）
  String get displayName {
    if (userName != null && userName!.isNotEmpty && userName != nickname) {
      return _truncate('$nickname（$userName）', 10);
    }
    return _truncate(nickname, 10);
  }

  @override
  List<Object?> get props => [id, userId, nickname, role, isOnline];
}

/// 订阅状态
class SubscriptionStatus extends Equatable {
  final String plan; // free / premium / annual
  final String status; // active / expired / free
  final String? expiresAt;
  final SubscriptionFeatures features;

  const SubscriptionStatus({
    required this.plan,
    required this.status,
    this.expiresAt,
    required this.features,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      plan: json['plan'] as String? ?? 'free',
      status: json['status'] as String? ?? 'free',
      expiresAt: json['expiresAt'] as String?,
      features: SubscriptionFeatures.fromJson(
        json['features'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  String get planLabel {
    switch (plan) {
      case 'premium':
        return '月度会员';
      case 'annual':
        return '年度会员';
      default:
        return '基础版';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return '生效中';
      case 'expired':
        return '已过期';
      default:
        return '基础版';
    }
  }

  bool get isPremium => plan != 'free' && status == 'active';

  @override
  List<Object?> get props => [plan, status, expiresAt, features];
}

/// 套餐功能
class SubscriptionFeatures extends Equatable {
  final int maxRecipients;
  final int maxMembers;
  final int maxLogsPerMonth;
  final int maxStorageMB; // MB，-1 表示不限
  final bool healthReports;
  final bool recurrenceReminders;

  const SubscriptionFeatures({
    required this.maxRecipients,
    required this.maxMembers,
    required this.maxLogsPerMonth,
    required this.maxStorageMB,
    required this.healthReports,
    required this.recurrenceReminders,
  });

  factory SubscriptionFeatures.fromJson(Map<String, dynamic> json) {
    return SubscriptionFeatures(
      maxRecipients: json['maxRecipients'] as int? ?? 1,
      maxMembers: json['maxMembers'] as int? ?? 3,
      maxLogsPerMonth: json['maxLogsPerMonth'] as int? ?? 200,
      maxStorageMB: json['maxStorageMB'] as int? ?? 500,
      healthReports: json['healthReports'] as bool? ?? false,
      recurrenceReminders: json['recurrenceReminders'] as bool? ?? false,
    );
  }

  String get storageLabel {
    if (maxStorageMB == -1) return '不限';
    if (maxStorageMB >= 1024) return '${(maxStorageMB / 1024).toStringAsFixed(0)}GB';
    return '${maxStorageMB}MB';
  }

  @override
  List<Object?> get props =>
      [maxRecipients, maxMembers, maxLogsPerMonth, maxStorageMB, healthReports, recurrenceReminders];
}
