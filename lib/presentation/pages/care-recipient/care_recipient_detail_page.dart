/// 照护对象详情页
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/models.dart';
import '../../providers/family_provider.dart';

class CareRecipientDetailPage extends ConsumerWidget {
  final CareRecipient recipient;

  const CareRecipientDetailPage({super.key, required this.recipient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicationsAsync = ref.watch(medicationsProvider(recipient.id));
    final healthTrendsAsync = ref.watch(healthTrendsProvider(recipient.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(recipient.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: () => context.push(AppRoutes.addCareRecipient, extra: recipient),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(recipient),
          const SizedBox(height: 16),
          _buildBasicInfoCard(recipient),
          const SizedBox(height: 16),
          _buildHealthCard(recipient),
          const SizedBox(height: 16),
          // 健康趋势
          healthTrendsAsync.when(
            data: (trends) => _buildHealthTrendsSection(trends),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          _buildEmergencyCard(recipient),
          const SizedBox(height: 16),
          _buildHospitalCard(recipient),
          const SizedBox(height: 16),
          // 药品管理
          _buildMedicationSection(context, ref, medicationsAsync),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(CareRecipient r) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(r.displayAvatar, style: const TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (r.age != null) _buildTag('${r.age}岁', AppColors.surfaceContainerLow),
                    if (r.gender != null && r.gender!.isNotEmpty)
                      _buildTag(_genderLabel(r.gender!), AppColors.surfaceContainerLow),
                    if (r.bloodType != null && r.bloodType!.isNotEmpty)
                      _buildTag('${r.bloodType!}型', AppColors.coral.withValues(alpha: 0.1)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard(CareRecipient r) {
    final items = <_InfoItem>[];
    if (r.birthDate != null) {
      items.add(_InfoItem('出生日期', _formatDate(r.birthDate!)));
    }
    if (r.gender != null && r.gender!.isNotEmpty) {
      items.add(_InfoItem('性别', _genderLabel(r.gender!)));
    }
    if (r.bloodType != null && r.bloodType!.isNotEmpty) {
      items.add(_InfoItem('血型', '${r.bloodType!}型'));
    }
    if (r.currentAddress != null && r.currentAddress!.isNotEmpty) {
      items.add(_InfoItem('家庭住址', r.currentAddress!));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return _buildCard(
      title: '基本信息',
      icon: Icons.person_outline,
      children: items.map((item) => _buildInfoRow(item.label, item.value)).toList(),
    );
  }

  Widget _buildHealthCard(CareRecipient r) {
    final hasAllergies = r.allergies.isNotEmpty;
    final hasConditions = r.chronicConditions.isNotEmpty;
    if (!hasAllergies && !hasConditions && (r.medicalHistory == null || r.medicalHistory!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return _buildCard(
      title: '健康信息',
      icon: Icons.favorite_outline,
      children: [
        if (hasAllergies) ...[
          _buildSectionLabel('过敏药物'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: r.allergies
                .map((a) => _buildChip(a, AppColors.coral.withValues(alpha: 0.1), AppColors.coral))
                .toList(),
          ),
        ],
        if (hasAllergies && hasConditions) const SizedBox(height: 16),
        if (hasConditions) ...[
          _buildSectionLabel('慢性病'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: r.chronicConditions
                .map((c) => _buildChip(c, AppColors.primary.withValues(alpha: 0.1), AppColors.primary))
                .toList(),
          ),
        ],
        if (r.medicalHistory != null && r.medicalHistory!.isNotEmpty) ...[
          if (hasAllergies || hasConditions) const SizedBox(height: 16),
          _buildSectionLabel('病史'),
          const SizedBox(height: 8),
          Text(
            r.medicalHistory!,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5),
          ),
        ],
      ],
    );
  }

  Widget _buildHealthTrendsSection(Map<String, List<HealthRecord>> trends) {
    final bpList = trends['bloodPressure'] ?? [];
    final glucoseList = trends['bloodGlucose'] ?? [];

    if (bpList.isEmpty && glucoseList.isEmpty) {
      return _buildCard(
        title: '近期健康趋势',
        icon: Icons.show_chart,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(Icons.timeline_outlined, size: 36, color: AppColors.textTertiary),
                  const SizedBox(height: 8),
                  Text('暂无健康记录', style: TextStyle(color: AppColors.textTertiary)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return _buildCard(
      title: '近期健康趋势',
      icon: Icons.show_chart,
      children: [
        if (bpList.isNotEmpty) ...[
          _buildBpTrendCard(bpList),
          if (glucoseList.isNotEmpty) const SizedBox(height: 16),
        ],
        if (glucoseList.isNotEmpty) _buildGlucoseTrendCard(glucoseList),
      ],
    );
  }

  Widget _buildBpTrendCard(List<HealthRecord> records) {
    final latest = records.isNotEmpty ? records.first : null;
    final avgSystolic = records.isEmpty ? 0 : (records.map((r) => r.systolic ?? 0).reduce((a, b) => a + b) / records.length).round();
    final avgDiastolic = records.isEmpty ? 0 : (records.map((r) => r.diastolic ?? 0).reduce((a, b) => a + b) / records.length).round();

    final trend = _getBpTrend(records);
    final trendIcon = trend > 0 ? '📈' : (trend < 0 ? '📉' : '📊');
    final trendLabel = _bpTrendLabel(trend);
    final trendColor = trend > 0 ? AppColors.coral : (trend < 0 ? AppColors.success : AppColors.textSecondary);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, size: 16, color: AppColors.coral),
              const SizedBox(width: 6),
              const Text('血压', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          if (latest != null && latest.systolic != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${latest.systolic}/${latest.diastolic}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: _bpColor(latest.systolic!, latest.diastolic!),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'mmHg',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text('$trendIcon $trendLabel', style: TextStyle(fontSize: 13, color: trendColor, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // 最近记录
          ...records.take(3).map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text(_formatDateShort(r.recordedAt), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                Text(
                  '${r.systolic}/${r.diastolic}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _bpColor(r.systolic ?? 0, r.diastolic ?? 0)),
                ),
              ],
            ),
          )),
          const SizedBox(height: 8),
          Text('近7日均值 $avgSystolic/$avgDiastolic', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildGlucoseTrendCard(List<HealthRecord> records) {
    final latest = records.isNotEmpty ? records.first : null;
    final avgValue = records.isEmpty ? 0.0 : (records.map((r) => r.glucoseValue ?? 0).reduce((a, b) => a + b) / records.length);
    final type = latest?.glucoseType ?? 'fasting';
    final typeLabel = type == 'fasting' ? '空腹' : '餐后';

    final trend = _getGlucoseTrend(records);
    final trendIcon = trend > 0 ? '📈' : (trend < 0 ? '📉' : '📊');
    final trendLabel = _glucoseTrendLabel(trend);
    final trendColor = trend > 0 ? AppColors.warning : (trend < 0 ? AppColors.success : AppColors.textSecondary);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('血糖（${typeLabel}）', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          if (latest != null && latest.glucoseValue != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  latest.glucoseValue!.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: _glucoseColor(latest.glucoseValue!),
                  ),
                ),
                const SizedBox(width: 4),
                Text('mmol/L', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                Text(_glucoseStatus(latest.glucoseValue!), style: TextStyle(fontSize: 12, color: _glucoseColor(latest.glucoseValue!))),
                const Spacer(),
                Text('$trendIcon $trendLabel', style: TextStyle(fontSize: 13, color: trendColor, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          ...records.take(3).map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text(_formatDateShort(r.recordedAt), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                Text(
                  r.glucoseValue!.toStringAsFixed(1),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _glucoseColor(r.glucoseValue!)),
                ),
                const SizedBox(width: 4),
                Text(r.glucoseType == 'fasting' ? '空腹' : '餐后', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          )),
          const SizedBox(height: 8),
          Text('近7日均值 ${avgValue.toStringAsFixed(1)}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard(CareRecipient r) {
    if ((r.emergencyContact == null || r.emergencyContact!.isEmpty) &&
        (r.emergencyPhone == null || r.emergencyPhone!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return _buildCard(
      title: '紧急联系人',
      icon: Icons.emergency_outlined,
      children: [
        if (r.emergencyContact != null && r.emergencyContact!.isNotEmpty)
          _buildInfoRow('联系人', r.emergencyContact!),
        if (r.emergencyPhone != null && r.emergencyPhone!.isNotEmpty)
          _buildInfoRow('联系电话', r.emergencyPhone!),
      ],
    );
  }

  Widget _buildHospitalCard(CareRecipient r) {
    final hasHospital = (r.hospital != null && r.hospital!.isNotEmpty);
    final hasDoctor = (r.doctorName != null && r.doctorName!.isNotEmpty);
    if (!hasHospital && !hasDoctor) return const SizedBox.shrink();

    return _buildCard(
      title: '就医信息',
      icon: Icons.local_hospital_outlined,
      children: [
        if (hasHospital) _buildInfoRow('就诊医院', r.hospital!),
        if (r.department != null && r.department!.isNotEmpty)
          _buildInfoRow('科室', r.department!),
        if (hasDoctor) _buildInfoRow('主治医生', r.doctorName!),
        if (r.doctorPhone != null && r.doctorPhone!.isNotEmpty)
          _buildInfoRow('医生电话', r.doctorPhone!),
      ],
    );
  }

  Widget _buildMedicationSection(BuildContext context, WidgetRef ref, AsyncValue<List<Medication>> medicationsAsync) {
    return _buildCard(
      title: '药品管理',
      icon: Icons.medication_outlined,
      trailing: IconButton(
        icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 22),
        onPressed: () => context.push('/medication/add'),
      ),
      children: [
        medicationsAsync.when(
          data: (meds) {
            final active = meds.where((m) => m.isActive).toList();
            if (active.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.medication_outlined, size: 36, color: AppColors.textTertiary),
                      const SizedBox(height: 8),
                      Text('暂无药品', style: TextStyle(color: AppColors.textTertiary)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => context.push('/medication/add'),
                        child: Text(
                          '+ 添加第一个药品',
                          style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: [
                ...active.map((med) => _buildMedicationRow(context, med)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => context.push('/medication/add'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '添加新药品',
                          style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('加载失败: $e', style: TextStyle(color: AppColors.error))),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationRow(BuildContext context, Medication med) {
    return InkWell(
      onTap: () => context.push('/medication/${med.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.medication, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    med.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (med.times.isNotEmpty)
                    Text(
                      med.times.join(' / '),
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildChip(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _genderLabel(String gender) {
    switch (gender) {
      case 'male': return '男';
      case 'female': return '女';
      default: return '未知';
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _formatDateShort(DateTime d) {
    return '${d.month}/${d.day}';
  }

  // 血压状态颜色
  Color _bpColor(int sys, int dia) {
    if (sys >= 140 || dia >= 90) return AppColors.coral;       // 高
    if (sys < 90 || dia < 60) return AppColors.warning;         // 低
    return AppColors.success;                                     // 正常
  }

  // 血糖状态颜色
  Color _glucoseColor(double val) {
    if (val > 7.0 || val < 3.9) return AppColors.coral;
    if (val > 6.1) return AppColors.warning;
    return AppColors.success;
  }

  String _glucoseStatus(double val) {
    if (val > 7.0) return '偏高';
    if (val < 3.9) return '偏低';
    return '正常';
  }

  // 计算血压趋势: 1=升高, -1=降低, 0=平稳
  int _getBpTrend(List<HealthRecord> records) {
    if (records.length < 2) return 0;
    final latest = records[0].systolic ?? 0;
    final older = records[records.length > 1 ? 1 : 0].systolic ?? 0;
    if (latest > older + 5) return 1;
    if (latest < older - 5) return -1;
    return 0;
  }

  int _getGlucoseTrend(List<HealthRecord> records) {
    if (records.length < 2) return 0;
    final latest = records[0].glucoseValue ?? 0;
    final older = records[records.length > 1 ? 1 : 0].glucoseValue ?? 0;
    if (latest > older + 0.5) return 1;
    if (latest < older - 0.5) return -1;
    return 0;
  }

  String _bpTrendLabel(int trend) {
    if (trend > 0) return '轻微升高';
    if (trend < 0) return '轻微下降';
    return '稳定';
  }

  String _glucoseTrendLabel(int trend) {
    if (trend > 0) return '轻微升高';
    if (trend < 0) return '轻微下降';
    return '稳定';
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"${recipient.name}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppTexts.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final dio = ref.read(dioProvider);
              await dio.delete('/care-recipients/${recipient.id}');
              ref.invalidate(careRecipientsProvider);
              ref.invalidate(currentFamilyProvider);
              if (context.mounted) context.pop();
            },
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  _InfoItem(this.label, this.value);
}
