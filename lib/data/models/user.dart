/// 用户模型
library;

import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String phone;
  final String? name;
  final String? avatarUrl;
  final String region;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.phone,
    this.name,
    this.avatarUrl,
    this.region = 'CN',
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      region: json['region'] as String? ?? 'CN',
      createdAt: DateTime.parse(json['createdAt'] as String? ?? json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'avatar_url': avatarUrl,
      'region': region,
      'created_at': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? phone,
    String? name,
    String? avatarUrl,
    String? region,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      region: region ?? this.region,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, phone, name, avatarUrl, region, createdAt];
}
