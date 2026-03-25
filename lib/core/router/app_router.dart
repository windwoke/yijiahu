/// 路由配置
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/pages/auth/login_page.dart';
import '../../presentation/pages/home/home_page.dart';
import '../../presentation/pages/medication/medication_page.dart';
import '../../presentation/pages/medication/add_medication_page.dart';
import '../../presentation/pages/medication/medication_detail_page.dart';
import '../../presentation/pages/family/family_page.dart';
import '../../data/models/models.dart';
import '../../presentation/pages/care-log/care_log_page.dart';
import '../../presentation/pages/sos/sos_page.dart';
import '../../presentation/pages/settings/profile_page.dart';
import '../../presentation/pages/settings/password_change_page.dart';
import '../../presentation/pages/care-recipient/add_care_recipient_page.dart';
import '../../presentation/pages/care-recipient/care_recipient_detail_page.dart';
import '../../presentation/providers/auth_provider.dart';

/// 路由名称
class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/';
  static const String medication = '/medication';
  static const String addMedication = '/medication/add';
  static const String family = '/family';
  static const String careLog = '/care-log';
  static const String sos = '/sos';
  static const String profile = '/profile';
  static const String passwordChange = '/profile/password-change';
  static const String addCareRecipient = '/care-recipient/add';
  static const String careRecipientDetail = '/care-recipient/detail';
}

/// 路由配置
final routerProvider = Provider<GoRouter>((ref) {
  // 只监听 isLoggedIn，避免整个 authState 变化触发 router 重建
  final isLoggedIn = ref.watch(isLoggedInProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggingIn = state.matchedLocation == AppRoutes.login;

      // 未登录，跳转登录页
      if (!isLoggedIn && !isLoggingIn) {
        return AppRoutes.login;
      }

      // 已登录，在登录页，跳转首页
      if (isLoggedIn && isLoggingIn) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: AppRoutes.medication,
            builder: (context, state) => const MedicationPage(),
          ),
          GoRoute(
            path: AppRoutes.careLog,
            builder: (context, state) => const CareLogPage(),
          ),
          GoRoute(
            path: AppRoutes.family,
            builder: (context, state) => const FamilyPage(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.addMedication,
        builder: (context, state) {
          final recipientId = state.extra as String?;
          return AddMedicationPage(recipientId: recipientId);
        },
      ),
      GoRoute(
        path: '/medication/:id',
        builder: (context, state) {
          final medicationId = state.pathParameters['id']!;
          return MedicationDetailPage(medicationId: medicationId);
        },
      ),
      GoRoute(
        path: AppRoutes.sos,
        builder: (context, state) => const SosPage(),
      ),
      GoRoute(
        path: AppRoutes.addCareRecipient,
        builder: (context, state) {
          final recipient = state.extra as CareRecipient?;
          return AddCareRecipientPage(recipient: recipient);
        },
      ),
      GoRoute(
        path: AppRoutes.careRecipientDetail,
        builder: (context, state) {
          final r = state.extra as CareRecipient;
          return CareRecipientDetailPage(recipient: r);
        },
      ),
      GoRoute(
        path: AppRoutes.passwordChange,
        builder: (context, state) => const PasswordChangePage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('页面未找到: ${state.uri}'),
      ),
    ),
  );
});

/// 主页面脚手架（含底部导航）
class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const MainBottomNav(),
    );
  }
}

/// 底部导航栏（品牌化定制）
class MainBottomNav extends StatelessWidget {
  const MainBottomNav({super.key});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == AppRoutes.home || location == '/') return 0;
    if (location.startsWith(AppRoutes.medication)) return 1;
    if (location.startsWith(AppRoutes.careLog)) return 2;
    if (location.startsWith(AppRoutes.family)) return 3;
    if (location.startsWith(AppRoutes.profile)) return 4;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.medication);
        break;
      case 2:
        context.go(AppRoutes.careLog);
        break;
      case 3:
        context.go(AppRoutes.family);
        break;
      case 4:
        context.go(AppRoutes.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F7),
        border: const Border(
          top: BorderSide(color: Color(0xFFE8E6E2), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A000000),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
          BoxShadow(
            color: const Color(0x06000000),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: selectedIndex == 0
                    ? Icons.home_rounded
                    : Icons.home_outlined,
                label: '首页',
                isSelected: selectedIndex == 0,
                onTap: () => _onItemTapped(context, 0),
              ),
              _NavItem(
                icon: selectedIndex == 1
                    ? Icons.medication_rounded
                    : Icons.medication_outlined,
                label: '用药',
                isSelected: selectedIndex == 1,
                onTap: () => _onItemTapped(context, 1),
              ),
              _NavItem(
                icon: selectedIndex == 2
                    ? Icons.edit_note_rounded
                    : Icons.edit_note_outlined,
                label: '日志',
                isSelected: selectedIndex == 2,
                onTap: () => _onItemTapped(context, 2),
              ),
              _NavItem(
                icon: selectedIndex == 3
                    ? Icons.people_rounded
                    : Icons.people_outlined,
                label: '家庭',
                isSelected: selectedIndex == 3,
                onTap: () => _onItemTapped(context, 3),
              ),
              _NavItem(
                icon: selectedIndex == 4
                    ? Icons.person_rounded
                    : Icons.person_outlined,
                label: '我的',
                isSelected: selectedIndex == 4,
                onTap: () => _onItemTapped(context, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部导航单项
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const selectedColor = Color(0xFF7B9E87);   // 鼠尾草绿
    const unselectedColor = Color(0xFFB0ADAD); // 柔和灰

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 44 : 0,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedColor.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 24,
                  color: isSelected ? selectedColor : unselectedColor,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
