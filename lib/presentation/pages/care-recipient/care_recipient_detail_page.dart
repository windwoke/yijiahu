/// 照护对象详情页
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';

class CareRecipientDetailPage extends ConsumerWidget {
  final CareRecipient recipient;

  const CareRecipientDetailPage({super.key, required this.recipient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(context, recipient),
          const SizedBox(height: 16),
          _buildBasicInfoCard(recipient),
          const SizedBox(height: 16),
          _buildHealthCard(recipient),
          const SizedBox(height: 16),
          _buildEmergencyCard(recipient),
          const SizedBox(height: 16),
          _buildHospitalCard(recipient),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, CareRecipient r) {
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
    if (!hasAllergies && !hasConditions) return const SizedBox.shrink();

    return _buildCard(
      title: '健康信息',
      icon: Icons.favorite_outline,
      children: [
        if (hasAllergies) ...[
          _buildSectionLabel('过敏史'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: r.allergies.map((a) => _buildChip(a, AppColors.coral.withValues(alpha: 0.1), AppColors.coral)).toList(),
          ),
        ],
        if (hasAllergies && hasConditions) const SizedBox(height: 16),
        if (hasConditions) ...[
          _buildSectionLabel('慢性病'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: r.chronicConditions.map((c) => _buildChip(c, AppColors.primary.withValues(alpha: 0.1), AppColors.primary)).toList(),
          ),
        ],
        if (r.medicalHistory != null && r.medicalHistory!.isNotEmpty) ...[
          const SizedBox(height: 16),
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

  Widget _buildCard({
    required String title,
    required IconData icon,
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
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
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
      case 'male':
        return '男';
      case 'female':
        return '女';
      default:
        return '未知';
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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
