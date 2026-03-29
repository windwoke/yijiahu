/// SOS 紧急求助页
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/constants.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';

class SosPage extends ConsumerStatefulWidget {
  const SosPage({super.key});

  @override
  ConsumerState<SosPage> createState() => _SosPageState();
}

class _SosPageState extends ConsumerState<SosPage> with SingleTickerProviderStateMixin {
  bool _isPressing = false;
  double _pressProgress = 0;
  bool _isTriggered = false;
  bool _isLoading = false;
  SosAlert? _activeAlert;

  @override
  void initState() {
    super.initState();
    _loadActiveSos();
  }

  Future<void> _loadActiveSos() async {
    final family = ref.read(currentFamilyProvider);
    if (family == null) return;
    final alert = await ref.read(activeSosProvider(family.id).future);
    if (alert != null && mounted) {
      setState(() {
        _activeAlert = alert;
        _isTriggered = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.coral,
      body: SafeArea(
        child: _isTriggered ? _buildTriggeredView() : _buildPreTriggerView(),
      ),
    );
  }

  Widget _buildPreTriggerView() {
    final recipients = ref.watch(careRecipientsProvider).valueOrNull ?? [];
    final recipient = recipients.isNotEmpty ? recipients.first : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // 顶部导航
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              const Spacer(),
            ],
          ),
          const Spacer(),
          // 标题
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          const Text(
            '紧急求助',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '长按下方按钮 3 秒\n将通知所有家人',
            style: TextStyle(fontSize: 15, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          // 长按 SOS 按钮
          GestureDetector(
            onLongPressStart: (_) => _startPress(),
            onLongPressEnd: (_) => _endPress(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: _isPressing ? 148 : 140,
              height: _isPressing ? 148 : 140,
              decoration: BoxDecoration(
                color: _isPressing ? Colors.white : AppColors.coral,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: _isPressing
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, spreadRadius: 2)]
                    : null,
              ),
              child: Center(
                child: Text(
                  'SOS',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: _isPressing ? AppColors.coral : Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 14,
              color: _isPressing ? Colors.white : Colors.white70,
              fontWeight: _isPressing ? FontWeight.w700 : FontWeight.normal,
            ),
            child: Text(
              _isPressing ? '保持按压中... ${(3 * _pressProgress).toInt()} 秒' : '长按 3 秒触发',
            ),
          ),
          const SizedBox(height: 8),
          if (_isPressing)
            SizedBox(
              width: 160,
              child: LinearProgressIndicator(
                value: _pressProgress,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          const Spacer(),
          // 紧急信息卡
          if (recipient != null) _buildEmergencyInfoCard(recipient),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEmergencyInfoCard(CareRecipient recipient) {
    final hasAllergies = recipient.allergies.isNotEmpty;
    final conditions = recipient.chronicConditions;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.coral.withValues(alpha: 0.1),
                child: Text(recipient.displayAvatar, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Text(
                recipient.name,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (recipient.bloodType != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🩸 ${recipient.bloodType}型',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error),
                  ),
                ),
            ],
          ),
          if (hasAllergies) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.warning_rounded, size: 14, color: AppColors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '过敏：${recipient.allergies.join('、')}',
                    style: const TextStyle(fontSize: 13, color: AppColors.error),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (conditions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '病史：${conditions.join('、')}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (recipient.hospital != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.local_hospital_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${recipient.hospital ?? ''}${recipient.department != null ? ' · ${recipient.department}' : ''}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (recipient.doctorName != null || recipient.doctorPhone != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '主治医生：${recipient.doctorName ?? ''}${recipient.doctorPhone != null ? ' ${_maskPhone(recipient.doctorPhone!)}' : ''}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (recipient.currentAddress != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    recipient.currentAddress!,
                    style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTriggeredView() {
    final family = ref.watch(currentFamilyProvider);
    final members = (family != null)
        ? ref.watch(familyMembersProvider(family.id)).valueOrNull ?? []
        : <FamilyMember>[];
    final recipients = ref.watch(careRecipientsProvider).valueOrNull ?? [];
    final recipient = _activeAlert?.recipientId != null
        ? recipients.where((r) => r.id == _activeAlert!.recipientId).firstOrNull
        : (recipients.isNotEmpty ? recipients.first : null);

    return Column(
      children: [
        const SizedBox(height: 16),
        // 顶部状态
        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 40),
        const SizedBox(height: 8),
        const Text(
          'SOS 已发出',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text(
          '紧急求助已通知所有家人',
          style: TextStyle(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 20),
        // 紧急信息卡
        if (recipient != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildTriggeredInfoCard(recipient),
          ),
        const SizedBox(height: 16),
        // 位置
        if (_activeAlert?.address != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _activeAlert!.address!,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        // 拨打按钮
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildCallButton('120 急救', Icons.local_hospital_rounded, () => _call('120')),
                const SizedBox(height: 12),
                _buildCallButton('110 报警', Icons.local_police_rounded, () => _call('110')),
                if (recipient?.doctorPhone != null) ...[
                  const SizedBox(height: 12),
                  _buildCallButton('联系主治医生 · ${recipient!.name}', Icons.phone_rounded,
                      () => _call(recipient.doctorPhone!)),
                ],
                if (recipient?.emergencyPhone != null) ...[
                  const SizedBox(height: 12),
                  _buildCallButton('紧急联系人', Icons.phone_rounded,
                      () => _call(recipient!.emergencyPhone!)),
                ],
                const SizedBox(height: 20),
                // 家庭成员确认状态
                if (members.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '已通知家人',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...members.map((m) => _buildMemberItem(m)),
                  const SizedBox(height: 20),
                ],
                // 取消按钮
                TextButton.icon(
                  onPressed: _isLoading ? null : () => _cancelSos(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  label: const Text('取消 SOS', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTriggeredInfoCard(CareRecipient recipient) {
    final hasAllergies = recipient.allergies.isNotEmpty;
    final conditions = recipient.chronicConditions;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(recipient.displayAvatar, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  recipient.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              if (recipient.bloodType != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🩸 ${recipient.bloodType}型',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          if (hasAllergies) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.warning_rounded, size: 13, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  '过敏：${recipient.allergies.join('、')}',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          ],
          if (conditions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '病史：${conditions.join('、')}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
          if (recipient.hospital != null) ...[
            const SizedBox(height: 4),
            Text(
              '🏥 ${recipient.hospital}${recipient.department != null ? ' · ${recipient.department}' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCallButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.coral, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.coral),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberItem(FamilyMember member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: member.avatarUrl != null
                ? null
                : Text(member.nickname.isNotEmpty ? member.nickname[0] : '?',
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              member.nickname,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
          const Text(
            '已通知',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  void _startPress() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isPressing = true;
      _pressProgress = 0;
    });
    _updateProgress();
  }

  void _updateProgress() {
    if (!_isPressing) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_isPressing) return;
      setState(() {
        _pressProgress += 0.033;
        if (_pressProgress >= 1) {
          _triggerSos();
        } else {
          _updateProgress();
        }
      });
    });
  }

  void _endPress() {
    HapticFeedback.lightImpact();
    setState(() {
      _isPressing = false;
      _pressProgress = 0;
    });
  }

  Future<void> _triggerSos() async {
    HapticFeedback.heavyImpact();
    setState(() => _isLoading = true);
    try {
      final family = ref.read(currentFamilyProvider);
      if (family == null) return;
      final recipients = ref.read(careRecipientsProvider).valueOrNull ?? [];
      final recipient = recipients.isNotEmpty ? recipients.first : null;
      final alert = await triggerSos(
        ref: ref,
        familyId: family.id,
        recipientId: recipient?.id,
      );
      if (mounted) {
        setState(() {
          _isTriggered = true;
          _activeAlert = alert;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SOS 触发失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelSos() async {
    if (_activeAlert == null || _isLoading) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认取消'),
        content: const Text('确定要取消此次 SOS 求助吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('取消 SOS', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final family = ref.read(currentFamilyProvider);
      if (family == null) return;
      await updateSosStatus(
        ref: ref,
        alertId: _activeAlert!.id,
        familyId: family.id,
        status: SosStatus.cancelled,
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取消失败: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _call(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String _maskPhone(String phone) {
    if (phone.length > 7) {
      return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
    }
    return phone;
  }
}
