/// SOS 紧急求助记录
library;

import 'package:equatable/equatable.dart';

enum SosStatus {
  active('active', '进行中'),
  acknowledged('acknowledged', '已确认'),
  resolved('resolved', '已解决'),
  cancelled('cancelled', '已取消');

  const SosStatus(this.value, this.label);
  final String value;
  final String label;

  static SosStatus fromString(String? v) {
    return SosStatus.values.firstWhere(
      (s) => s.value == v,
      orElse: () => SosStatus.active,
    );
  }
}

class SosAlert extends Equatable {
  final String id;
  final String familyId;
  final String? recipientId;
  final String triggeredById;
  final double? latitude;
  final double? longitude;
  final String? address;
  final SosStatus status;
  final String? acknowledgedById;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;

  const SosAlert({
    required this.id,
    required this.familyId,
    this.recipientId,
    required this.triggeredById,
    this.latitude,
    this.longitude,
    this.address,
    required this.status,
    this.acknowledgedById,
    this.acknowledgedAt,
    this.resolvedAt,
    this.cancelledAt,
    required this.createdAt,
  });

  factory SosAlert.fromJson(Map<String, dynamic> json) {
    return SosAlert(
      id: json['id'] as String? ?? '',
      familyId: json['familyId'] as String? ?? json['family_id'] as String? ?? '',
      recipientId: json['recipientId'] as String? ?? json['recipient_id'] as String?,
      triggeredById: json['triggeredById'] as String? ?? json['triggered_by_id'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      status: SosStatus.fromString(json['status'] as String?),
      acknowledgedById: json['acknowledgedById'] as String? ?? json['acknowledged_by_id'] as String?,
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.tryParse(json['acknowledgedAt'].toString())
          : json['acknowledged_at'] != null
              ? DateTime.tryParse(json['acknowledged_at'].toString())
              : null,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'].toString())
          : json['resolved_at'] != null
              ? DateTime.tryParse(json['resolved_at'].toString())
              : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.tryParse(json['cancelledAt'].toString())
          : json['cancelled_at'] != null
              ? DateTime.tryParse(json['cancelled_at'].toString())
              : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, familyId, status, createdAt];
}
