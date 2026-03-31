/// 每日护理打卡 Provider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart' as models;
import '../../core/network/api_client.dart';
import 'family_provider.dart';

/// 今日打卡状态（首页横幅用，按照护对象 ID 索引）
/// 用 familyId 作为稳定 key，避免 List<String> 每次 build 新建引用导致重复加载
/// 内部 watch careRecipientsProvider 获取 recipientIds（不外部传递，避免引用不稳定）
/// 外部通过 ref.invalidate(todayCheckinsProvider(...)) 主动刷新
final todayCheckinsProvider =
    FutureProvider.family<Map<String, models.DailyCareCheckin>, String>(
  (ref, familyId) async {
    if (familyId.isEmpty) return {};
    // watch careRecipientsProvider 获取当前 recipient 列表
    // 注意：这里 watch 的是 FutureProvider，只有数据实际变化时才触发重新加载
    final recipients = await ref.watch(careRecipientsProvider.future);
    if (recipients.isEmpty) return {};
    final recipientIds = recipients.map((r) => r.id).toList();

    final dio = ref.read(dioProvider);
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    try {
      final response = await dio.get('/daily-care-checkins/today', queryParameters: {
        'recipientIds': recipientIds.join(','),
        'todayDate': todayStr,
        'familyId': familyId,
      });
      final List<dynamic> data;
      if (response.data is List<dynamic>) {
        data = response.data as List<dynamic>;
      } else {
        return {};
      }
      final map = <String, models.DailyCareCheckin>{};
      for (final e in data) {
        try {
          final checkin = models.DailyCareCheckin.fromJson(e as Map<String, dynamic>);
          map[checkin.careRecipientId] = checkin;
        } catch (_) {}
      }
      return map;
    } catch (_) {
      return {};
    }
  },
);

/// 照护对象打卡历史（用于时间线）
final checkinHistoryProvider =
    FutureProvider.family<List<models.DailyCareCheckin>, String>(
  (ref, careRecipientId) async {
    final dio = ref.read(dioProvider);
    try {
      final response = await dio.get('/daily-care-checkins/by-recipient', queryParameters: {
        'careRecipientId': careRecipientId,
        'limit': 30,
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
              return models.DailyCareCheckin.fromJson(e as Map<String, dynamic>);
            } catch (_) { return null; }
          })
          .whereType<models.DailyCareCheckin>()
          .toList();
    } catch (_) {
      return [];
    }
  },
);

/// 提交打卡
Future<models.DailyCareCheckin> submitCheckin({
  required WidgetRef ref,
  required String careRecipientId,
  required models.CheckinStatus status,
  int? medicationCompleted,
  int? medicationTotal,
  String? specialNote,
}) async {
  final dio = ref.read(dioProvider);
  final familyId = ref.read(currentFamilyProvider)?.id;
  final today = DateTime.now();
  final todayStr =
      '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  final response = await dio.post('/daily-care-checkins', data: {
    'familyId': familyId,
    'careRecipientId': careRecipientId,
    'checkinDate': todayStr,
    'status': status.name,
    if (medicationCompleted != null) 'medicationCompleted': medicationCompleted,
    if (medicationTotal != null) 'medicationTotal': medicationTotal,
    if (specialNote != null && specialNote.isNotEmpty) 'specialNote': specialNote,
  });
  return models.DailyCareCheckin.fromJson(response.data as Map<String, dynamic>);
}
