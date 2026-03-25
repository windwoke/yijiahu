/// 一家护 - 主入口
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/env/env_config.dart';

Future<void> main() async {
  // 加载环境变量（找不到 .env 时使用默认值）
  await dotenv.load(fileName: '.env', isOptional: true);

  // 打印当前环境
  debugPrint('🚀 启动环境: ${AppEnv.current.label}');
  debugPrint('📡 API: ${ApiConfig.baseUrl}');

  WidgetsFlutterBinding.ensureInitialized();

  // 预缓存品牌字体（Nunito）
  // 首次加载后自动缓存到本地，后续无网络也可用
  GoogleFonts.getFont('Nunito');

  // 设置状态栏样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 竖屏锁定
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    const ProviderScope(
      child: YijiahuApp(),
    ),
  );
}

class YijiahuApp extends ConsumerWidget {
  const YijiahuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '一家护',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    );
  }
}
