/// SOS 紧急求助页
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/constants.dart';
import '../../../core/env/env_config.dart';
import '../../../core/network/api_client.dart';
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
  bool _isDataLoading = true;
  SosAlert? _activeAlert;
  List<CareRecipient> _recipients = [];
  List<FamilyMember> _members = [];

  @override
  void initState() {
    super.initState();
    _loadActiveSos();
  }

  Future<void> _loadActiveSos() async {
    final family = ref.read(currentFamilyProvider);
    if (family == null) return;
    try {
      final dio = ref.read(dioProvider);

      // 三个并行请求，各自 try-catch 避免一个失败影响其他
      dynamic alertData;
      dynamic membersData;
      dynamic recipientsData;

      await Future(() async {
        try { alertData = (await dio.get('/sos-alerts/active', queryParameters: {'familyId': family.id})).data; } catch (_) {}
        try { membersData = (await dio.get('/families/${family.id}/members')).data; } catch (_) {}
        try { recipientsData = (await dio.get('/care-recipients', queryParameters: {'familyId': family.id})).data; } catch (_) {}
      });

      if (!mounted) return;

      // 解析 members
      if (membersData is List) {
        _members = (membersData as List)
            .map((e) => FamilyMember.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // 解析 recipients
      if (recipientsData is List) {
        _recipients = (recipientsData as List)
            .map((e) => CareRecipient.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (recipientsData is Map && (recipientsData as Map)['data'] is List) {
        _recipients = ((recipientsData as Map)['data'] as List)
            .map((e) => CareRecipient.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      setState(() => _isDataLoading = false);

      // 解析 active alert
      if (alertData is Map<String, dynamic>) {
        setState(() {
          _activeAlert = SosAlert.fromJson(alertData);
          _isTriggered = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isDataLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isTriggered ? Colors.white : AppColors.coral,
      body: SafeArea(
        child: _isDataLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : (_isTriggered ? _buildTriggeredView() : _buildPreTriggerView()),
      ),
    );
  }

  Widget _buildPreTriggerView() {
    // watch provider 触发加载并响应更新，fallback 到本地 state
    final providerRecipients = ref.watch(careRecipientsProvider).valueOrNull;
    final allRecipients = providerRecipients ?? _recipients;
    final recipient = allRecipients.isNotEmpty ? allRecipients.first : null;

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
              if (recipient.avatarUrl != null && recipient.avatarUrl!.isNotEmpty)
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(ApiConfig.avatarUrl(recipient.avatarUrl!) ?? ''),
                )
              else
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
            Row(
              children: [
                const Icon(Icons.medical_information_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '慢病：${conditions.join('、')}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (recipient.medicalHistory != null && recipient.medicalHistory!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.history_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '病史：${recipient.medicalHistory}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
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
    // watch provider 触发加载并响应更新，fallback 到本地 state
    final providerRecipients = ref.watch(careRecipientsProvider).valueOrNull;
    final family = ref.watch(currentFamilyProvider);
    final providerMembers = family != null
        ? ref.watch(familyMembersProvider(family.id)).valueOrNull
        : null;
    final allRecipients = providerRecipients ?? _recipients;
    final allMembers = providerMembers ?? _members;
    final recipient = _activeAlert?.recipientId != null
        ? allRecipients.where((r) => r.id == _activeAlert!.recipientId).firstOrNull
        : (allRecipients.isNotEmpty ? allRecipients.first : null);

    return Column(
      children: [
        const SizedBox(height: 16),
        // 顶部状态
        const Icon(Icons.warning_amber_rounded, color: AppColors.coral, size: 40),
        const SizedBox(height: 8),
        const Text(
          'SOS 已发出',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          '紧急求助已通知所有家人',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
                const Icon(Icons.location_on_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _activeAlert!.address!,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                  _buildCallButton('联系主治医生 · ${recipient?.doctorName ?? ''}', Icons.phone_rounded,
                      () => _call(recipient!.doctorPhone!)),
                ],
                if (recipient?.emergencyPhone != null) ...[
                  const SizedBox(height: 12),
                  _buildCallButton('紧急联系人${recipient?.emergencyContact != null ? ' · ${recipient!.emergencyContact}' : ''}', Icons.phone_rounded,
                      () => _call(recipient!.emergencyPhone!)),
                ],
                const SizedBox(height: 20),
                // 家庭成员确认状态
                if (allMembers.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '已通知家人',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...allMembers.map((m) => _buildMemberItem(m)),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
        // 底部悬浮取消按钮
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: SafeArea(
            top: false,
            child: TextButton.icon(
              onPressed: _isLoading ? null : () => _cancelSos(),
              icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
              label: const Text('取消 SOS', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
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
        color: const Color(0xFFF5EDD8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0C89A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (recipient.avatarUrl != null && recipient.avatarUrl!.isNotEmpty)
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(ApiConfig.avatarUrl(recipient.avatarUrl!) ?? ''),
                )
              else
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE8D8C0),
                  child: Text(recipient.displayAvatar, style: const TextStyle(fontSize: 18)),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  recipient.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              if (recipient.bloodType != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8D8C0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🩸 ${recipient.bloodType}型',
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ),
            ],
          ),
          if (hasAllergies) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.warning_rounded, size: 13, color: AppColors.coral),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '过敏：${recipient.allergies.join('、')}',
                    style: const TextStyle(fontSize: 12, color: AppColors.coral),
                  ),
                ),
              ],
            ),
          ],
          if (recipient.medicalHistory != null && recipient.medicalHistory!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.history_rounded, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '病史：${recipient.medicalHistory}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
          if (conditions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.medical_information_rounded, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '慢病：${conditions.join('、')}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
          if (recipient.hospital != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.local_hospital_rounded, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${recipient.hospital}${recipient.department != null ? ' · ${recipient.department}' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
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
          color: AppColors.coral,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberItem(FamilyMember member) {
    final avatar = member.avatarUrl != null && member.avatarUrl!.isNotEmpty
        ? NetworkImage(ApiConfig.avatarUrl(member.avatarUrl!) ?? '')
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EDD8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0C89A)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE8D8C0),
            backgroundImage: avatar,
            child: avatar == null
                ? Text(
                    member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              member.displayName,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Text(
            '已通知',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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

    // 获取位置（坐标存到 SOS 记录，地址由后端用国内服务反解）
    double? lat, lng;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(const Duration(seconds: 10));
          lat = pos.latitude;
          lng = pos.longitude;
        } catch (_) {}
      }
    } catch (_) {}

    try {
      final family = ref.read(currentFamilyProvider);
      if (family == null) return;
      final recipient = _recipients.isNotEmpty ? _recipients.first : null;
      final alert = await triggerSos(
        ref: ref,
        familyId: family.id,
        recipientId: recipient?.id,
        latitude: lat,
        longitude: lng,
      );
      if (mounted) {
        setState(() {
          _isTriggered = true;
          _activeAlert = alert;
        });
      }
    } catch (e) {
      debugPrint('[_triggerSos] error: $e');
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
    final canLaunch = await canLaunchUrl(uri);
    if (canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前设备不支持拨打电话')),
        );
      }
    }
  }

  String _maskPhone(String phone) {
    if (phone.length > 7) {
      return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
    }
    return phone;
  }
}
