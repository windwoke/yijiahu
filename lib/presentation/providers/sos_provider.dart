/// SOS 紧急求助 Provider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart' as models;
import '../../core/network/api_client.dart';
import 'family_provider.dart';

/// 触发 SOS
Future<models.SosAlert> triggerSos({
  required WidgetRef ref,
  required String familyId,
  String? recipientId,
  double? latitude,
  double? longitude,
  String? address,
}) async {
  final dio = ref.read(dioProvider);
  final response = await dio.post('/sos-alerts', data: {
    'familyId': familyId,
    if (recipientId != null) 'recipientId': recipientId,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (address != null) 'address': address,
  });
  return models.SosAlert.fromJson(response.data as Map<String, dynamic>);
}

/// 查询当前家庭活跃 SOS
final activeSosProvider = FutureProvider.family<models.SosAlert?, String>(
  (ref, familyId) async {
    final dio = ref.read(dioProvider);
    try {
      final response = await dio.get('/sos-alerts/active', queryParameters: {
        'familyId': familyId,
      });
      if (response.data == null) return null;
      return models.SosAlert.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  },
);

/// SOS 历史记录
final sosHistoryProvider = FutureProvider.family<List<models.SosAlert>, String>(
  (ref, familyId) async {
    final dio = ref.read(dioProvider);
    try {
      final response = await dio.get('/sos-alerts', queryParameters: {
        'familyId': familyId,
      });
      final List<dynamic> data;
      if (response.data is List<dynamic>) {
        data = response.data as List<dynamic>;
      } else {
        return [];
      }
      return data
          .map((e) {
            try {
              return models.SosAlert.fromJson(e as Map<String, dynamic>);
            } catch (_) { return null; }
          })
          .whereType<models.SosAlert>()
          .toList();
    } catch (_) {
      return [];
    }
  },
);

/// 更新 SOS 状态
Future<void> updateSosStatus({
  required WidgetRef ref,
  required String alertId,
  required String familyId,
  required models.SosStatus status,
}) async {
  final dio = ref.read(dioProvider);
  await dio.patch('/sos-alerts/$alertId/status', queryParameters: {
    'familyId': familyId,
  }, data: {
    'status': status.value,
  });
}
