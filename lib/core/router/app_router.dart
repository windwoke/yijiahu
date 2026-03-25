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
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const AddMedicationPage(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final med = state.extra as Medication;
                  return MedicationDetailPage(medication: med);
                },
              ),
            ],
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

/// 底部导航栏
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

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => _onItemTapped(context, index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: '首页',
        ),
        NavigationDestination(
          icon: Icon(Icons.medication_outlined),
          selectedIcon: Icon(Icons.medication),
          label: '用药',
        ),
        NavigationDestination(
          icon: Icon(Icons.edit_note_outlined),
          selectedIcon: Icon(Icons.edit_note),
          label: '日志',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outlined),
          selectedIcon: Icon(Icons.people),
          label: '家庭',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outlined),
          selectedIcon: Icon(Icons.person),
          label: '我的',
        ),
      ],
    );
  }
}
