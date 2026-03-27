/// 家庭数据 Provider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart' as models;
import '../../data/models/care_log.dart';
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

  try {
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
  } catch (err) {
    return [];
  }
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
  try {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/medications', queryParameters: {
      'recipientId': recipientId,
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
            return models.Medication.fromJson(e as Map<String, dynamic>);
          } catch (err) {
            return null;
          }
        })
        .whereType<models.Medication>()
        .toList();
  } catch (err) {
    return [];
  }
});

/// 药品历史打卡记录（用于药品详情页）
final medicationHistoryProvider =
    FutureProvider.family<List<models.MedicationLog>, String>((ref, medicationId) async {
  try {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/medication-logs/timeline', queryParameters: {
      'medicationId': medicationId,
      'days': 7,
      'limit': 20,
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
            return models.MedicationLog.fromJson(e as Map<String, dynamic>);
          } catch (_) { return null; }
        })
        .whereType<models.MedicationLog>()
        .toList();
  } catch (_) {
    return [];
  }
});

/// 健康趋势（血压+血糖）
final healthTrendsProvider =
    FutureProvider.family<Map<String, List<models.HealthRecord>>, String>(
  (ref, recipientId) async {
  try {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/health-records/trends', queryParameters: {
      'recipientId': recipientId,
      'days': 7,
    });
    final data = response.data as Map<String, dynamic>;
    final bpList = (data['bloodPressure'] as List<dynamic>?)
            ?.map((e) {
              try {
                return models.HealthRecord.fromJson(e as Map<String, dynamic>);
              } catch (_) { return null; }
            })
            .whereType<models.HealthRecord>()
            .toList() ??
        [];
    final glucoseList = (data['bloodGlucose'] as List<dynamic>?)
            ?.map((e) {
              try {
                return models.HealthRecord.fromJson(e as Map<String, dynamic>);
              } catch (_) { return null; }
            })
            .whereType<models.HealthRecord>()
            .toList() ??
        [];
    return {
      'bloodPressure': bpList,
      'bloodGlucose': glucoseList,
    };
  } catch (err) {
    return {'bloodPressure': <models.HealthRecord>[], 'bloodGlucose': <models.HealthRecord>[]};
  }
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

/// 时间线条目（统一展示照护日志 + 用药打卡）
/// 支持分页加载：首次加载50条，滚动到底部自动加载更多
final timelineProvider =
    AsyncNotifierProvider.family<TimelineNotifier, List<models.TimelineEntry>, TimelineQuery>(
  TimelineNotifier.new,
);

class TimelineNotifier extends FamilyAsyncNotifier<List<models.TimelineEntry>, TimelineQuery> {
  static const _pageSize = 50;

  /// 防止并发重复加载
  bool _isLoadingMore = false;

  @override
  Future<List<models.TimelineEntry>> build(TimelineQuery query) async {
    return _fetchPage(null);
  }

  /// 加载更多（分页）
  Future<void> loadMore() async {
    // 防止并发调用
    if (_isLoadingMore) return;
    _isLoadingMore = true;

    try {
      final current = state.valueOrNull ?? [];
      if (current.isEmpty) return;

      final before = current.last.time;
      final newEntries = await _fetchPage(before);
      if (newEntries.isEmpty) return;

      // 追加时检查去重（防止并发返回相同数据）
      final existingIds = current.map((e) => e.id).toSet();
      final uniqueNew = newEntries.where((e) => !existingIds.contains(e.id)).toList();
      if (uniqueNew.isEmpty) return;

      state = AsyncData([...current, ...uniqueNew]);
    } finally {
      _isLoadingMore = false;
    }
  }

  /// 刷新（重新加载第一页）
  Future<void> refresh() async {
    _isLoadingMore = false;
    state = const AsyncLoading();
    state = AsyncData(await _fetchPage(null));
  }

  Future<List<models.TimelineEntry>> _fetchPage(DateTime? before) async {
    final dio = ref.read(dioProvider);
    final familyId = arg.familyId;
    final recipientId = arg.recipientId;

    final List<models.TimelineEntry> all = [];

    // 1. 照护日志
    try {
      final careLogsParams = <String, dynamic>{
        'familyId': familyId,
        'limit': _pageSize,
      };
      if (recipientId != null) careLogsParams['recipientId'] = recipientId;
      if (before != null) careLogsParams['before'] = before.toIso8601String();

      final careLogsResp = await dio.get('/care-logs', queryParameters: careLogsParams);
      final careLogsData = careLogsResp.data is List
          ? careLogsResp.data as List
          : (careLogsResp.data['data'] as List?) ?? [];
      all.addAll(careLogsData
          .map((e) => models.TimelineEntry.fromCareLog(Map<String, dynamic>.from(e))));
    } catch (_) {}

    // 2. 用药打卡
    try {
      final medParams = <String, dynamic>{'days': 45, 'limit': _pageSize};
      medParams['familyId'] = familyId;
      if (recipientId != null) medParams['recipientId'] = recipientId;
      if (before != null) medParams['before'] = before.toIso8601String();

      final medResp = await dio.get('/medication-logs/timeline', queryParameters: medParams);
      final medData = medResp.data is List
          ? medResp.data as List
          : (medResp.data['data'] as List?) ?? [];
      all.addAll(medData
          .map((e) => models.TimelineEntry.fromMedicationLog(Map<String, dynamic>.from(e))));
    } catch (_) {}

    // 3. 健康记录
    try {
      final hrParams = <String, dynamic>{'days': 45, 'limit': 20};
      hrParams['familyId'] = familyId;
      if (recipientId != null) hrParams['recipientId'] = recipientId;
      if (before != null) hrParams['before'] = before.toIso8601String();

      final hrResp = await dio.get('/health-records/recent', queryParameters: hrParams);
      final hrData = hrResp.data is List
          ? hrResp.data as List
          : (hrResp.data['data'] as List?) ?? [];
      all.addAll(hrData
          .map((e) => models.TimelineEntry.fromHealthRecord(Map<String, dynamic>.from(e))));
    } catch (_) {}

    // 4. 每日护理打卡（按 familyId 隔离）
    try {
      final checkinParams = <String, dynamic>{'limit': 30};
      if (recipientId != null) {
        checkinParams['careRecipientId'] = recipientId;
      } else if (familyId != null) {
        checkinParams['familyId'] = familyId;
      }

      final checkinResp = await dio.get(
        '/daily-care-checkins/by-recipient',
        queryParameters: checkinParams,
      );
      final checkinData = checkinResp.data is List
          ? checkinResp.data as List
          : (checkinResp.data['data'] as List?) ?? [];
      all.addAll(checkinData
          .map((e) => models.TimelineEntry.fromDailyCareCheckin(Map<String, dynamic>.from(e))));
    } catch (_) {}

    all.sort((a, b) => b.time.compareTo(a.time));
    return all;
  }
}

/// 用户所在的所有家庭列表
final myFamiliesProvider = FutureProvider<List<models.Family>>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('/users/me/families');
    final data = response.data as Map<String, dynamic>;
    final families = (data['families'] as List<dynamic>?) ?? [];
    return families
        .map((e) {
          try {
            final f = (e as Map<String, dynamic>)['family'];
            return models.Family.fromJson(f as Map<String, dynamic>);
          } catch (_) { return null; }
        })
        .whereType<models.Family>()
        .toList();
  } catch (_) {
    return [];
  }
});

/// 订阅状态
final subscriptionStatusProvider =
    FutureProvider.family<models.SubscriptionStatus, String>((ref, familyId) async {
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('/subscriptions/status', queryParameters: {
      'familyId': familyId,
    });
    return models.SubscriptionStatus.fromJson(response.data as Map<String, dynamic>);
  } catch (_) {
    // 兼容：订阅接口不可用时返回免费版状态
    return const models.SubscriptionStatus(
      plan: 'free',
      status: 'free',
      features: models.SubscriptionFeatures(
        maxRecipients: 1,
        maxMembers: 3,
        maxLogsPerMonth: 200,
        maxStorageMB: 500,
        healthReports: false,
        recurrenceReminders: false,
      ),
    );
  }
});

/// 更新家庭信息（头像、名称、描述）
Future<models.Family> updateFamily({
  required WidgetRef ref,
  required String familyId,
  String? name,
  String? avatarUrl,
  String? description,
}) async {
  final dio = ref.read(dioProvider);
  final body = <String, dynamic>{};
  if (name != null) body['name'] = name;
  if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
  if (description != null) body['description'] = description;

  final response = await dio.patch('/families/$familyId', data: body);
  final updated = models.Family.fromJson(response.data as Map<String, dynamic>);
  // 同步更新 currentFamilyProvider
  ref.read(currentFamilyProvider.notifier).state = updated;
  return updated;
}
