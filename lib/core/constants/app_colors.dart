// 一家护 - 色彩常量（温润关怀型）
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════
  // 主色：鼠尾草绿
  // 温和、生命力、自然感，不撞 iOS/Android 系统色
  // ═══════════════════════════════════════════════
  static const Color primary = Color(0xFF7B9E87);
  static const Color primaryLight = Color(0xFFA3BDA6);
  static const Color primaryDark = Color(0xFF5C8268);

  // ═══════════════════════════════════════════════
  // 辅助色：暖杏/陶土
  // SOS 紧急、温馨提醒（柔和不刺眼）
  // ═══════════════════════════════════════════════
  static const Color coral = Color(0xFFE07B5D);
  static const Color coralLight = Color(0xFFF09A7E);

  // 静谧蓝：冷静、医疗、专业（用于图表/数据）
  static const Color blue = Color(0xFF4A90D9);

  // ═══════════════════════════════════════════════
  // 背景色
  // ═══════════════════════════════════════════════
  static const Color background = Color(0xFFFAF9F7);   // 米白 - 温暖不刺眼
  static const Color surface = Color(0xFFFFFFFF);        // 白色卡片
  static const Color surfaceGray = Color(0xFFF5F5F5);   // 灰色卡片

  // ═══════════════════════════════════════════════
  // 文字色
  // ═══════════════════════════════════════════════
  static const Color textPrimary = Color(0xFF2C2C2C);   // 接近黑但不刺眼
  static const Color textSecondary = Color(0xFF6B6B6B);  // 柔和灰
  static const Color textTertiary = Color(0xFFB0ADAD);  // 更淡的灰

  // ═══════════════════════════════════════════════
  // 状态色（与主色调协调）
  // ═══════════════════════════════════════════════
  static const Color success = Color(0xFF6BA07E);        // 鼠尾草绿系
  static const Color warning = Color(0xFFD4A855);        // 暖琥珀
  static const Color error = Color(0xFFE07B5D);          // 与 coral 同色系
  static const Color info = Color(0xFF4A90D9);           // 静谧蓝

  // ═══════════════════════════════════════════════
  // 健康数据色
  // ═══════════════════════════════════════════════
  static const Color bpHigh = Color(0xFFE07B5D);        // 血压高
  static const Color bpNormal = Color(0xFF6BA07E);       // 血压正常
  static const Color bpElevated = Color(0xFFD4A855);     // 血压偏高

  // ═══════════════════════════════════════════════
  // 层级背景
  // ═══════════════════════════════════════════════
  static const Color surfaceContainerLow = Color(0xFFF4F3F1);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color glassSurface = Color(0xCCFFFFFF);

  // ═══════════════════════════════════════════════
  // 边框/分隔（暖灰色系）
  // ═══════════════════════════════════════════════
  static const Color border = Color(0xFFE8E6E2);       // 暖灰边框
  static const Color borderLight = Color(0xFFF0EEEB);

  // ═══════════════════════════════════════════════
  // 卡片阴影（多层叠加，柔和层次感）
  // 用法示例（2层）:
  //   BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 2)),
  //   BoxShadow(color: AppColors.shadowSoft2, blurRadius: 4, offset: Offset(0, 1)),
  // ═══════════════════════════════════════════════
  static const Color shadowSoft = Color(0x0A000000);    // 4% 黑
  static const Color shadowSoft2 = Color(0x06000000);   // 2.4% 黑

  // 单层阴影（兼容旧代码）
  static const Color shadow = Color(0x08000000);

  // ═══════════════════════════════════════════════
  // 灰度色
  // ═══════════════════════════════════════════════
  static const Color grey50  = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  // ═══════════════════════════════════════════════
  // 密码强度色
  // ═══════════════════════════════════════════════
  static const Color strengthWeak = Color(0xFFE07B5D);
  static const Color strengthMedium = Color(0xFFD4A855);
  static const Color strengthStrong = Color(0xFF6BA07E);

  // ═══════════════════════════════════════════════
  // 药品状态色
  // ═══════════════════════════════════════════════
  static const Color medicationDone = Color(0xFF5C8268); // 主色深一度
}
