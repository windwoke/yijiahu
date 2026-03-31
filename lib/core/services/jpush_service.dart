// JPush 推送服务
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:jpush_flutter/jpush_flutter.dart';
import 'package:jpush_flutter/jpush_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class JPushService {
  static final JPushService _instance = JPushService._internal();
  factory JPushService() => _instance;
  JPushService._internal();

  late final JPushFlutterInterface _jpush;
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 通知点击回调（App运行时点击推送触发）
  void Function(Map<String, dynamic> extra)? onNotificationTap;

  /// 从 .env 读取 JPush 配置
  String get _jpushAppKey => dotenv.env['JPUSH_APP_KEY'] ?? '';

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

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

    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // 获取 JPush 实例
    _jpush = JPush.newJPush();

    // 初始化（同步调用）
    _jpush.setup(
      appKey: _jpushAppKey,
      production: dotenv.env['FLUTTER_ENV'] == 'prod',
      channel: dotenv.env['FLUTTER_ENV'] == 'prod' ? 'production' : 'development',
      debug: dotenv.env['FLUTTER_ENV'] != 'prod',
    );

    // iOS 申请推送权限
    _jpush.applyPushAuthority();

    // 监听接收消息（EventHandler = Future<dynamic> Function(Map)）
    _jpush.addEventHandler(
      onReceiveNotification: _handleReceiveNotification,
      onOpenNotification: _handleOpenNotification,
      onReceiveMessage: _handleReceiveMessage,
    );

    // 延迟获取 registration ID（setup 后才能拿到）
    Future.delayed(const Duration(seconds: 3), _registerDevice);
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

    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
    );
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('[JPush] 本地通知点击: ${response.payload}');
  }

  /// 注册设备到后端
  Future<void> _registerDevice() async {
    try {
      final registrationId = await _jpush.getRegistrationID();
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
    try {
      await _jpush.setAlias(userId);
      debugPrint('[JPush] 设置别名成功: $userId');
    } catch (e) {
      debugPrint('[JPush] 设置别名失败: $e');
    }
  }

  /// 退出登录时清除别名
  Future<void> deleteAlias() async {
    try {
      await _jpush.deleteAlias();
      debugPrint('[JPush] 清除别名成功');
    } catch (_) {}
  }

  /// 清除 iOS badge
  Future<void> clearBadge() async {
    try {
      await _jpush.setBadge(0);
    } catch (_) {}
  }
}
