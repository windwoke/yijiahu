/// 复诊模型
class Appointment {
  final String id;
  final String recipientId;
  final CareRecipientMini? recipient;
  final String hospital;
  final String? department;
  final String? doctorName;
  final String? doctorPhone;
  final DateTime appointmentTime;
  final String? appointmentNo;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? fee;
  final String? purpose;
  final String status; // upcoming, completed, cancelled
  final String? assignedDriverId;
  final DriverMini? assignedDriver;
  final bool reminder48h;
  final bool reminder24h;
  final String? note;
  final DateTime createdAt;

  Appointment({
    required this.id,
    required this.recipientId,
    this.recipient,
    required this.hospital,
    this.department,
    this.doctorName,
    this.doctorPhone,
    required this.appointmentTime,
    this.appointmentNo,
    this.address,
    this.latitude,
    this.longitude,
    this.fee,
    this.purpose,
    required this.status,
    this.assignedDriverId,
    this.assignedDriver,
    this.reminder48h = true,
    this.reminder24h = true,
    this.note,
    required this.createdAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] ?? '',
      recipientId: json['recipientId'] ?? '',
      recipient: json['recipient'] != null
          ? CareRecipientMini.fromJson(json['recipient'])
          : null,
      hospital: json['hospital'] ?? '',
      department: json['department'],
      doctorName: json['doctorName'],
      doctorPhone: json['doctorPhone'],
      appointmentTime: json['appointmentTime'] != null
          ? (DateTime.tryParse(json['appointmentTime'].toString()) ?? DateTime.now())
          : DateTime.now(),
      appointmentNo: json['appointmentNo'],
      address: json['address'],
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      fee: _parseDouble(json['fee']),
      purpose: json['purpose'],
      status: json['status'] ?? 'upcoming',
      assignedDriverId: json['assignedDriverId'],
      assignedDriver: json['assignedDriver'] != null
          ? DriverMini.fromJson(json['assignedDriver'])
          : null,
      reminder48h: json['reminder48h'] ?? true,
      reminder24h: json['reminder24h'] ?? true,
      note: json['note'],
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  String get displayTime {
    final d = appointmentTime;
    return '${d.year}年${d.month}月${d.day}日 ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String get statusLabel {
    switch (status) {
      case 'completed':
        return '已完成';
      case 'cancelled':
        return '已取消';
      default:
        return '待复诊';
    }
  }

  bool get isUpcoming => status == 'upcoming';
}

/// 照护对象迷你（用于引用）
class CareRecipientMini {
  final String id;
  final String name;
  final String? avatarEmoji;
  final String? avatarUrl;

  CareRecipientMini({
    required this.id,
    required this.name,
    this.avatarEmoji,
    this.avatarUrl,
  });

  factory CareRecipientMini.fromJson(Map<String, dynamic> json) {
    return CareRecipientMini(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      avatarEmoji: json['avatarEmoji'],
      avatarUrl: json['avatarUrl'],
    );
  }
}

class DriverMini {
  final String id;
  final String name;

  DriverMini({required this.id, required this.name});

  factory DriverMini.fromJson(Map<String, dynamic> json) {
    return DriverMini(
      id: json['id'] ?? '',
      name: json['name'] ?? json['phone'] ?? '',
    );
  }
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
