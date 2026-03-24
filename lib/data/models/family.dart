/// 家庭模型
library;

import 'package:equatable/equatable.dart';

enum SubscriptionPlan { free, premium, annual }

enum FamilyMemberRole { owner, admin, member, viewer }

/// 家庭
class Family extends Equatable {
  final String id;
  final String name;
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
      id: json['id'] as String,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String,
      role: json['role'] as String? ?? 'member',
      subscriptionPlan: _parsePlan(json['subscription_plan'] as String?),
      subscriptionExpiresAt: json['subscription_expires_at'] != null
          ? DateTime.parse(json['subscription_expires_at'] as String)
          : null,
      memberCount: json['member_count'] as int? ?? 0,
      recipientCount: json['recipient_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
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
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      nickname: json['nickname'] as String,
      role: json['role'] as String,
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
      joinedAt: DateTime.parse(json['joined_at'] as String),
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
