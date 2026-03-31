/// 通知列表页
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/notification.dart';
import '../../providers/notification_provider.dart';

class NotificationListPage extends ConsumerStatefulWidget {
  const NotificationListPage({super.key});

  @override
  ConsumerState<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends ConsumerState<NotificationListPage> {
  final List<AppNotification> _notifications = [];
  bool _isLoading = false;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final dio = ref.read(dioProvider);
    try {
      final response = await dio.get('/notifications', queryParameters: {
        'page': _page,
        'pageSize': 20,
      });
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return;

      final list = data['list'] as List<dynamic>? ?? [];
      final newItems = list
          .map((e) {
            try { return AppNotification.fromJson(e as Map<String, dynamic>); }
            catch (_) { return null; }
          })
          .whereType<AppNotification>()
          .toList();

      setState(() {
        if (_page == 1) {
          _notifications.clear();
        }
        _notifications.addAll(newItems);
        _hasMore = newItems.length == 20;
        _page++;
      });
    } catch (_) {
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _page = 1;
      _hasMore = true;
    });
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '通知',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: () async {
                await markAllAsRead(ref);
                setState(() {
                  for (final n in _notifications) {
                    final idx = _notifications.indexOf(n);
                    _notifications[idx] = AppNotification(
                      id: n.id,
                      userId: n.userId,
                      familyId: n.familyId,
                      type: n.type,
                      title: n.title,
                      body: n.body,
                      level: n.level,
                      sourceType: n.sourceType,
                      sourceId: n.sourceId,
                      sourceUserId: n.sourceUserId,
                      isRead: true,
                      createdAt: n.createdAt,
                      dataJson: n.dataJson,
                    );
                  }
                });
              },
              child: const Text(
                '全部已读',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: _notifications.isEmpty && !_isLoading
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.primary,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _notifications.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _notifications.length) {
                    _loadNotifications();
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }
                  return _NotificationItem(
                    notification: _notifications[index],
                    onTap: () => _handleTap(_notifications[index]),
                    onDismissed: () => _dismiss(_notifications[index]),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.surface,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无通知',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '有新通知时会在这里显示',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap(AppNotification n) async {
    if (!n.isRead) {
      await markAsRead(ref, n.id);
      setState(() {
        final idx = _notifications.indexOf(n);
        _notifications[idx] = AppNotification(
          id: n.id,
          userId: n.userId,
          familyId: n.familyId,
          type: n.type,
          title: n.title,
          body: n.body,
          level: n.level,
          sourceType: n.sourceType,
          sourceId: n.sourceId,
          sourceUserId: n.sourceUserId,
          isRead: true,
          createdAt: n.createdAt,
          dataJson: n.dataJson,
        );
      });
    }
  }

  void _dismiss(AppNotification n) async {
    await deleteNotification(ref, n.id);
    setState(() => _notifications.remove(n));
  }

}

class _NotificationItem extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent = notification.level == NotificationLevel.urgent ||
        notification.type == NotificationType.sos;
    final isHigh = notification.level == NotificationLevel.high ||
        notification.type == NotificationType.missedDose ||
        notification.type == NotificationType.healthAlert;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) => onDismissed(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: notification.isRead
                  ? AppColors.surface
                  : (isUrgent
                      ? const Color(0xFFFFF5F3)
                      : isHigh
                          ? const Color(0xFFFFFDF5)
                          : AppColors.surface),
              border: Border(
                bottom: const BorderSide(
                  color: AppColors.borderLight,
                  width: 0.5,
                ),
                left: isUrgent
                    ? const BorderSide(color: AppColors.coral, width: 3)
                    : isHigh
                        ? const BorderSide(color: AppColors.warning, width: 3)
                        : BorderSide.none,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isUrgent
                        ? AppColors.coral.withValues(alpha: 0.1)
                        : isHigh
                            ? AppColors.warning.withValues(alpha: 0.1)
                            : AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      notification.type.emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 6),
                              decoration: const BoxDecoration(
                                color: AppColors.coral,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(notification.createdAt),
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }
}
