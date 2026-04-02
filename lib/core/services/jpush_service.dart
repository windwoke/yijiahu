// JPush 推送服务
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:jpush_flutter/jpush_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:jpush_flutter/jpush_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JPushService {
  static final JPushService _instance = JPushService._internal();
  factory JPushService() => _instance;
  JPushService._internal();

  JPushFlutterInterface? _jpush;
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _supported = false;
  bool _tzInitialized = false;

  /// 通知点击回调（App运行时点击推送触发）
  void Function(Map<String, dynamic> extra)? onNotificationTap;

  /// 从 --dart-define 读取 JPush 配置
  String get _jpushAppKey => const String.fromEnvironment('JPUSH_APP_KEY', defaultValue: '');

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 初始化时区（用于 zonedSchedule）
    if (!_tzInitialized) {
      try {
        tz_data.initializeTimeZones();
        _tzInitialized = true;
      } catch (e) {
        debugPrint('[JPush] 时区初始化失败: $e');
      }
    }

    // 未配置 AppKey 时跳过
    if (_jpushAppKey.isEmpty) {
      debugPrint('[JPush] 未配置 JPUSH_APP_KEY，跳过初始化');
      return;
    }

    // 初始化本地通知（用于展示收到的推送）
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _localNotif.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );
    } catch (e) {
      debugPrint('[JPush] 本地通知初始化失败: $e');
    }

    try {
      // 获取 JPush 实例
      _jpush = JPush.newJPush();

      // 初始化（同步调用）
      _jpush!.setup(
        appKey: _jpushAppKey,
        production: const String.fromEnvironment('FLUTTER_ENV', defaultValue: 'dev') == 'prod',
        channel: const String.fromEnvironment('FLUTTER_ENV', defaultValue: 'dev') == 'prod' ? 'production' : 'development',
        debug: const String.fromEnvironment('FLUTTER_ENV', defaultValue: 'dev') != 'prod',
      );

      // iOS 申请推送权限
      _jpush!.applyPushAuthority();

      // 监听接收消息（EventHandler = Future<dynamic> Function(Map)）
      _jpush!.addEventHandler(
        onReceiveNotification: _handleReceiveNotification,
        onOpenNotification: _handleOpenNotification,
        onReceiveMessage: _handleReceiveMessage,
      );

      _supported = true;
      debugPrint('[JPush] 初始化成功');

      // 延迟获取 registration ID（setup 后才能拿到）
      Future.delayed(const Duration(seconds: 3), _registerDevice);
    } catch (e) {
      debugPrint('[JPush] 初始化失败（可能是模拟器或平台不支持）: $e');
      _supported = false;
    }
  }

  Future<dynamic> _handleReceiveNotification(Map<String, dynamic> message) async {
    debugPrint('[JPush] 收到通知: $message');
    final title = (message['title'] ?? '').toString();
    final content = (message['content'] ?? '').toString();
    final extras = (message['extras'] as Map<String, dynamic>?) ?? {};
    await _showLocalNotification(title, content, extras);
  }

  Future<dynamic> _handleOpenNotification(Map<String, dynamic> message) async {
    debugPrint('[JPush] 点击通知: $message');
    final extras = (message['extras'] as Map<String, dynamic>?) ?? {};
    onNotificationTap?.call(extras);
  }

  Future<dynamic> _handleReceiveMessage(Map<String, dynamic> message) async {
    debugPrint('[JPush] 收到透传消息: $message');
  }

  Future<void> _showLocalNotification(
    String title,
    String body,
    Map<String, dynamic> extras,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'yijiahu_default',
      '默认通知',
      channelDescription: '一家护默认推送通道',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _localNotif.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        details,
      );
    } catch (_) {}
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('[JPush] 本地通知点击: ${response.payload}');
  }

  /// 注册设备到后端
  Future<void> _registerDevice() async {
    if (!_supported || _jpush == null) return;

    try {
      final registrationId = await _jpush!.getRegistrationID();
      if (registrationId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final lastRegId = prefs.getString('jpush_registration_id');
      if (lastRegId == registrationId) return;

      await prefs.setString('jpush_registration_id', registrationId);
      debugPrint('[JPush] 设备注册 ID: $registrationId');
    } catch (e) {
      debugPrint('[JPush] 注册设备失败: $e');
    }
  }

  /// 登录成功后调用，上报设备 Token 给后端
  static Future<void> registerToken(dynamic dio) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final registrationId = prefs.getString('jpush_registration_id');
      if (registrationId == null || registrationId.isEmpty) return;

      await dio.patch('/users/me/push-token', data: {'pushToken': registrationId});
      debugPrint('[JPush] 上报 Token 成功: $registrationId');
    } catch (e) {
      debugPrint('[JPush] 上报 Token 失败: $e');
    }
  }

  /// 登录后关联别名
  Future<void> setAlias(String userId) async {
    if (!_supported || _jpush == null) return;

    try {
      await _jpush!.setAlias(userId);
      debugPrint('[JPush] 设置别名成功: $userId');
    } catch (e) {
      debugPrint('[JPush] 设置别名失败: $e');
    }
  }

  /// 退出登录时清除别名
  Future<void> deleteAlias() async {
    if (!_supported || _jpush == null) return;

    try {
      await _jpush!.deleteAlias();
      debugPrint('[JPush] 清除别名成功');
    } catch (_) {}
  }

  /// 清除 iOS badge
  Future<void> clearBadge() async {
    if (!_supported || _jpush == null) return;

    try {
      await _jpush!.setBadge(0);
    } catch (_) {}
  }

  /// 北京时间 TZDateTime
  tz.TZDateTime get _local =>
      tz.TZDateTime.now(tz.local);

  /// 安排本地提醒通知（稍后X分钟提醒服药）
  Future<void> scheduleReminder({
    required int minutes,
    required String medicationName,
    required String dosage,
  }) async {
    try {
      // 取消已有的该药品提醒（避免重复）
      await cancelReminder(medicationName);

      const androidDetails = AndroidNotificationDetails(
        'yijiahu_medication_reminder',
        '用药提醒',
        channelDescription: '用药打卡本地提醒',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      // 用药品名做 notificationId，保证唯一性
      final notificationId = medicationName.hashCode.abs() % 100000;
      final delay = Duration(minutes: minutes);

      // 使用 zonedSchedule 安排定时通知（支持后台）
      await _localNotif.zonedSchedule(
        notificationId,
        '⏰ 该服药了',
        '$medicationName${dosage.isNotEmpty ? ' · $dosage' : ''}',
        // 目标时间 = 现在 + delay
        _local.add(delay),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'medication_reminder:$notificationId',
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('[JPush] 已安排 ${minutes}分钟后提醒: $medicationName');
    } catch (e) {
      debugPrint('[JPush] 安排提醒失败: $e');
    }
  }

  /// 取消指定药品的提醒
  Future<void> cancelReminder(String medicationName) async {
    try {
      final notificationId = medicationName.hashCode.abs() % 100000;
      await _localNotif.cancel(notificationId);
    } catch (_) {}
  }
}
