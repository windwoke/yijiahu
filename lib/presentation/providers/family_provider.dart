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
  // 后端直接返回数组，不需要 data 包装
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
          return models.CareRecipient.fromJson(e as Map<String, dynamic>);
        } catch (err) {
          return null;
        }
      })
      .whereType<models.CareRecipient>()
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
  // 后端直接返回数组，不需要 data 包装
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
          return models.Medication.fromJson(e as Map<String, dynamic>);
        } catch (err) {
          return null;
        }
      })
      .whereType<models.Medication>()
      .toList();
});

/// 健康趋势（血压+血糖）
final healthTrendsProvider =
    FutureProvider.family<Map<String, List<models.HealthRecord>>, String>(
  (ref, recipientId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/health-records/trends', queryParameters: {
    'recipientId': recipientId,
    'days': 7,
  });
  final data = response.data as Map<String, dynamic>;
  final bpList = (data['bloodPressure'] as List<dynamic>?)
          ?.map((e) => models.HealthRecord.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [];
  final glucoseList = (data['bloodGlucose'] as List<dynamic>?)
          ?.map((e) => models.HealthRecord.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [];
  return {
    'bloodPressure': bpList,
    'bloodGlucose': glucoseList,
  };
},
);

/// 照护对象详情（按 ID 获取）
final careRecipientDetailProvider =
    FutureProvider.family<models.CareRecipient, String>((ref, recipientId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/care-recipients/$recipientId');
  return models.CareRecipient.fromJson(response.data as Map<String, dynamic>);
});

/// 药品详情（按 ID 获取）
final medicationDetailProvider =
    FutureProvider.family<models.Medication, String>((ref, medicationId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/medications/$medicationId');
  return models.Medication.fromJson(response.data as Map<String, dynamic>);
});
