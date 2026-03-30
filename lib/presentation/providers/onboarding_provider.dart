import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'family_provider.dart';

/// 是否显示新用户引导弹层（家庭列表为空且数据加载完成时为 true）
final showOnboardingProvider = Provider<bool>((ref) {
  final familiesAsync = ref.watch(myFamiliesProvider);
  return familiesAsync.valueOrNull?.isEmpty ?? false;
});
