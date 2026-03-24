// 一家护 - 色彩常量
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // 主色
  static const Color primary = Color(0xFF34C759);      // 温暖绿 - 用药完成、健康、安全感
  static const Color primaryLight = Color(0xFF5DD97A);
  static const Color primaryDark = Color(0xFF248A3D);

  // 辅助色
  static const Color coral = Color(0xFFFF6B6B);         // 珊瑚橙 - SOS、紧急、提醒
  static const Color coralLight = Color(0xFFFF8E8E);
  static const Color blue = Color(0xFF4A90D9);         // 静谧蓝 - 冷静、医疗、专业

  // 背景色
  static const Color background = Color(0xFFFAF9F7);     // 米白 - 温暖、不刺眼
  static const Color surface = Color(0xFFFFFFFF);       // 白色卡片
  static const Color surfaceGray = Color(0xFFF5F5F5);  // 灰色卡片

  // 文字色
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFFBDBDBD);

  // 状态色
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFFB800);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = Color(0xFF4A90D9);

  // 健康数据色
  static const Color bpHigh = Color(0xFFFF3B30);       // 血压高
  static const Color bpNormal = Color(0xFF34C759);     // 血压正常
  static const Color bpElevated = Color(0xFFFF9F0A);  // 血压偏高

  // 卡片阴影
  static const Color shadow = Color(0x0F000000);

  // 边框色
  static const Color border = Color(0xFFE5E5E5);
  static const Color borderLight = Color(0xFFF0F0F0);
}
