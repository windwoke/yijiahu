/// 路由配置
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/pages/auth/login_page.dart';
import '../../presentation/pages/home/home_page.dart';
import '../../presentation/pages/calendar/calendar_page.dart';
import '../../presentation/pages/calendar/add_appointment_page.dart';
import '../../presentation/pages/calendar/add_task_page.dart';
import '../../presentation/pages/calendar/family_tasks_page.dart';
import '../../presentation/pages/calendar/calendar_management_page.dart';
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
import '../../presentation/pages/daily-care/daily_care_page.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/providers.dart';

/// 路由名称
class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/';
  static const String calendar = '/calendar';
  static const String addAppointment = '/calendar/appointment/add';
  static const String addTask = '/calendar/task/add';
  static const String familyTasks = '/calendar/tasks';
  static const String calendarManagement = '/calendar/management';
  static const String addMedication = '/medication/add';
  static const String family = '/family';
  static const String careLog = '/care-log';
  static const String sos = '/sos';
  static const String profile = '/profile';
  static const String passwordChange = '/profile/password-change';
  static const String addCareRecipient = '/care-recipient/add';
  static const String careRecipientDetail = '/care-recipient/detail';
  static const String dailyCare = '/daily-care';
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
            path: AppRoutes.calendar,
            builder: (context, state) => const CalendarPage(),
          ),
          GoRoute(
            path: AppRoutes.familyTasks,
            builder: (context, state) => const FamilyTasksPage(),
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
        path: AppRoutes.addAppointment,
        builder: (context, state) => const AddAppointmentPage(),
      ),
      GoRoute(
        path: AppRoutes.addTask,
        builder: (context, state) {
          final task = state.extra as FamilyTask?;
          return AddTaskPage(task: task);
        },
      ),
      GoRoute(
        path: AppRoutes.calendarManagement,
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'] ?? 'appointments';
          return CalendarManagementPage(initialTab: tab);
        },
      ),
      GoRoute(
        path: AppRoutes.addMedication,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Medication) {
            return AddMedicationPage(medication: extra);
          }
          return AddMedicationPage(recipientId: extra as String?);
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
      GoRoute(
        path: AppRoutes.dailyCare,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return DailyCarePage(
            recipientId: extra['recipientId'] as String,
            recipient: extra['recipient'] as CareRecipient,
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('页面未找到: ${state.uri}'),
      ),
    ),
  );
});

/// 主页面脚手架（含底部导航，切换家庭后自动修复路由）
class MainScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    // 监听家庭切换，切换后验证当前路由是否对新角色有效
    // 注意：listener 在 initState 时会立即触发一次，用 _listening 过滤首次
    ref.listen(currentFamilyProvider, (prev, next) {
      if (!_listening) { _listening = true; return; } // 跳过首次触发
      if (prev?.id == next?.id) return;
      final isCaregiver = next?.myRole == FamilyMemberRole.caregiver;
      final location = GoRouterState.of(context).uri.path;
      final validRoutes = isCaregiver
          ? {AppRoutes.home, AppRoutes.careLog, AppRoutes.profile}
          : {AppRoutes.home, AppRoutes.calendar, AppRoutes.careLog, AppRoutes.family, AppRoutes.profile};
      if (!validRoutes.contains(location)) {
        context.go(AppRoutes.home);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: const MainBottomNav(),
    );
  }
}

/// 底部导航栏（品牌化定制，动态适配保姆模式）
class MainBottomNav extends ConsumerWidget {
  const MainBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);
    final isCaregiver = family?.myRole == FamilyMemberRole.caregiver;

    // 保姆模式只有首页/日志/我的 3个Tab
    final navItems = isCaregiver
        ? [
            _NavItemData(AppRoutes.home, '首页', Icons.home_rounded, Icons.home_outlined),
            _NavItemData(AppRoutes.careLog, '日志', Icons.edit_note_rounded, Icons.edit_note_outlined),
            _NavItemData(AppRoutes.profile, '我的', Icons.person_rounded, Icons.person_outlined),
          ]
        : [
            _NavItemData(AppRoutes.home, '首页', Icons.home_rounded, Icons.home_outlined),
            _NavItemData(AppRoutes.calendar, '日历', Icons.calendar_today_rounded, Icons.calendar_today_outlined),
            _NavItemData(AppRoutes.careLog, '日志', Icons.edit_note_rounded, Icons.edit_note_outlined),
            _NavItemData(AppRoutes.family, '家庭', Icons.people_rounded, Icons.people_outlined),
            _NavItemData(AppRoutes.profile, '我的', Icons.person_rounded, Icons.person_outlined),
          ];

    final selectedIndex = _calculateSelectedIndex(context, isCaregiver);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
          BoxShadow(
            color: AppColors.shadowSoft2,
            blurRadius: 4,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (i) {
              final item = navItems[i];
              return _NavItem(
                icon: selectedIndex == i ? item.iconSelected : item.icon,
                label: item.label,
                isSelected: selectedIndex == i,
                onTap: () => context.go(item.route),
              );
            }),
          ),
        ),
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context, bool isCaregiver) {
    final location = GoRouterState.of(context).uri.path;
    if (location == AppRoutes.home || location == '/') return 0;
    if (location.startsWith(AppRoutes.calendar)) return isCaregiver ? -1 : 1;
    if (location.startsWith(AppRoutes.careLog)) return isCaregiver ? 1 : 2;
    if (location.startsWith(AppRoutes.family)) return isCaregiver ? -1 : 3;
    if (location.startsWith(AppRoutes.profile)) return isCaregiver ? 2 : 4;
    return 0;
  }
}

/// 导航项数据
class _NavItemData {
  final String route;
  final String label;
  final IconData iconSelected;
  final IconData icon;
  const _NavItemData(this.route, this.label, this.iconSelected, this.icon);
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
    const selectedColor = AppColors.primary;
    const unselectedColor = AppColors.textTertiary;

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
