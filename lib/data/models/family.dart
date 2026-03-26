/// 家庭模型
library;

import 'package:equatable/equatable.dart';

enum SubscriptionPlan { free, premium, annual }

enum FamilyMemberRole { owner, admin, member, viewer }

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
      role: json['myRole'] as String? ?? json['role'] as String? ?? 'member',
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

  const FamilyMember({
    required this.id,
    this.userId,
    required this.nickname,
    required this.role,
    this.avatarUrl,
    this.phone,
    this.isOnline = false,
    required this.joinedAt,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String?,
      nickname: json['nickname'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      isOnline: json['isOnline'] as bool? ?? json['is_online'] as bool? ?? false,
      joinedAt: DateTime.tryParse(json['joinedAt'] as String? ?? json['joined_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String get roleLabel {
    switch (role) {
      case 'owner':
        return '管理员';
      case 'admin':
        return '协管员';
      case 'member':
        return '成员';
      case 'viewer':
        return '查看者';
      default:
        return role;
    }
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
