/// 通知 Provider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notification.dart';
import '../../core/network/api_client.dart';

/// 通知列表
final notificationListProvider = FutureProvider.family<List<AppNotification>, int>(
  (ref, page) async {
    final dio = ref.read(dioProvider);
    try {
      final response = await dio.get('/notifications', queryParameters: {
        'page': page,
        'pageSize': 20,
      });
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return [];
      final list = data['list'] as List<dynamic>? ?? [];
      return list
          .map((e) {
            try { return AppNotification.fromJson(e as Map<String, dynamic>); }
            catch (_) { return null; }
          })
          .whereType<AppNotification>()
          .toList();
    } catch (_) {
      return [];
    }
  },
);

/// 未读数
final unreadCountProvider = FutureProvider<int>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('/notifications/unread-count');
    final data = response.data as Map<String, dynamic>?;
    return data?['count'] as int? ?? 0;
  } catch (_) {
    return 0;
  }
});

/// 标记单条已读
Future<void> markAsRead(WidgetRef ref, String notificationId) async {
  final dio = ref.read(dioProvider);
  try {
    await dio.put('/notifications/$notificationId/read');
    // 刷新未读数
    ref.invalidate(unreadCountProvider);
  } catch (_) {}
}

/// 全部已读
Future<void> markAllAsRead(WidgetRef ref) async {
  final dio = ref.read(dioProvider);
  try {
    await dio.put('/notifications/read-all');
    ref.invalidate(unreadCountProvider);
  } catch (_) {}
}

/// 删除通知
Future<void> deleteNotification(WidgetRef ref, String notificationId) async {
  final dio = ref.read(dioProvider);
  try {
    await dio.delete('/notifications/$notificationId');
    ref.invalidate(unreadCountProvider);
  } catch (_) {}
}
