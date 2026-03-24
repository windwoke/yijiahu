/// 家庭数据 Provider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart' as models;
import '../../core/network/api_client.dart';

/// 当前选中的家庭
final currentFamilyProvider = StateProvider<models.Family?>((ref) => null);

/// 家庭成员列表
final familyMembersProvider = FutureProvider.family<List<models.FamilyMember>, String>(
  (ref, familyId) async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/families/$familyId/members');
    final data = response.data as List<dynamic>;
    return data
        .map((e) => models.FamilyMember.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

/// 照护对象列表
final careRecipientsProvider = FutureProvider<List<models.CareRecipient>>((ref) async {
  final dio = ref.read(dioProvider);
  final familyId = ref.watch(currentFamilyProvider)?.id;
  if (familyId == null) return [];

  final response = await dio.get('/care-recipients', queryParameters: {
    'familyId': familyId,
  });
  final data = response.data['data'] as List<dynamic>;
  return data
      .map((e) => models.CareRecipient.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// 今日用药状态
final todayMedicationProvider =
    FutureProvider.family<models.TodayMedicationSummary, String>(
  (ref, recipientId) async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/medication-logs/today', queryParameters: {
      'recipientId': recipientId,
    });
    return models.TodayMedicationSummary.fromJson(
        response.data as Map<String, dynamic>);
  },
);

/// 药品列表
final medicationsProvider =
    FutureProvider.family<List<models.Medication>, String>((ref, recipientId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/medications', queryParameters: {
    'recipientId': recipientId,
  });
  final data = response.data['data'] as List<dynamic>;
  return data
      .map((e) => models.Medication.fromJson(e as Map<String, dynamic>))
      .toList();
});
