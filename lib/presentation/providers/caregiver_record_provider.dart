/// 照护记录 Provider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart' as models;
import '../../core/network/api_client.dart';
import 'family_provider.dart';

/// 照护记录列表
final caregiverRecordsProvider =
    FutureProvider.family<List<models.CaregiverRecord>, String>(
  (ref, careRecipientId) async {
    final dio = ref.read(dioProvider);
    final familyId = ref.watch(currentFamilyProvider)?.id;
    try {
      final response = await dio.get('/caregiver-records', queryParameters: {
        'careRecipientId': careRecipientId,
        'familyId': familyId,
      });
      final List<dynamic> data;
      if (response.data is List<dynamic>) {
        data = response.data as List<dynamic>;
      } else if (response.data is Map && (response.data as Map)['data'] is List) {
        data = (response.data as Map)['data'] as List<dynamic>;
      } else {
        return [];
      }
      return data
          .map((e) {
            try {
              return models.CaregiverRecord.fromJson(e as Map<String, dynamic>);
            } catch (_) { return null; }
          })
          .whereType<models.CaregiverRecord>()
          .toList();
    } catch (_) {
      return [];
    }
  },
);

/// 当前照护人
final currentCaregiverProvider =
    FutureProvider.family<models.CaregiverRecord?, String>(
  (ref, careRecipientId) async {
    final dio = ref.read(dioProvider);
    final familyId = ref.watch(currentFamilyProvider)?.id;
    try {
      final response = await dio.get('/caregiver-records/current', queryParameters: {
        'careRecipientId': careRecipientId,
        'familyId': familyId,
      });
      if (response.data == null) return null;
      return models.CaregiverRecord.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  },
);

/// 创建照护记录
Future<models.CaregiverRecord> createCaregiverRecord({
  required WidgetRef ref,
  required String careRecipientId,
  required String caregiverId,
  required String periodStart,
  String? note,
}) async {
  final dio = ref.read(dioProvider);
  final response = await dio.post('/caregiver-records', data: {
    'careRecipientId': careRecipientId,
    'caregiverId': caregiverId,
    'periodStart': periodStart,
    if (note != null && note.isNotEmpty) 'note': note,
  });
  return models.CaregiverRecord.fromJson(response.data as Map<String, dynamic>);
}

/// 删除照护记录
Future<void> deleteCaregiverRecord({
  required WidgetRef ref,
  required String id,
  required String familyId,
}) async {
  final dio = ref.read(dioProvider);
  await dio.delete('/caregiver-records/$id', queryParameters: {
    'familyId': familyId,
  });
}
