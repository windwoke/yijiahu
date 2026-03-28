/// 添加复诊页
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';

class AddAppointmentPage extends ConsumerStatefulWidget {
  const AddAppointmentPage({super.key});

  @override
  ConsumerState<AddAppointmentPage> createState() => _AddAppointmentPageState();
}

class _AddAppointmentPageState extends ConsumerState<AddAppointmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _hospitalController = TextEditingController();
  final _departmentController = TextEditingController();
  final _doctorNameController = TextEditingController();
  final _doctorPhoneController = TextEditingController();
  final _appointmentNoController = TextEditingController();
  final _addressController = TextEditingController();
  final _feeController = TextEditingController();
  final _purposeController = TextEditingController();
  final _noteController = TextEditingController();

  CareRecipient? _selectedRecipient;
  DateTime _appointmentTime = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _appointmentTimeOfDay = TimeOfDay(hour: 9, minute: 0);
  String? _selectedDriverId;
  bool _reminder48h = true;
  bool _reminder24h = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 默认时间：明天 9:00
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _appointmentTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
  }

  @override
  void dispose() {
    _hospitalController.dispose();
    _departmentController.dispose();
    _doctorNameController.dispose();
    _doctorPhoneController.dispose();
    _appointmentNoController.dispose();
    _addressController.dispose();
    _feeController.dispose();
    _purposeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String get _displayDate {
    return '${_appointmentTime.year}年${_appointmentTime.month}月${_appointmentTime.day}日';
  }

  String get _displayTime {
    return '${_appointmentTimeOfDay.hour.toString().padLeft(2, '0')}:${_appointmentTimeOfDay.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // 权限守卫：只有 owner/coordinator 可以添加复诊
    if (!(ref.watch(currentFamilyProvider)?.myRole.canCreateAppointment ?? false)) {
      return Scaffold(
        appBar: AppBar(title: const Text('添加复诊')),
        body: const Center(child: Text('您没有权限添加复诊')),
      );
    }
    final recipientsAsync = ref.watch(careRecipientsProvider);
    final membersAsync = ref.watch(
      familyMembersProvider(ref.watch(currentFamilyProvider)?.id ?? ''),
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('添加复诊'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: recipientsAsync.when(
          data: (recipients) {
            if (recipients.isEmpty) {
              return const Center(child: Text('请先添加照护对象'));
            }
            _selectedRecipient ??= recipients.first;

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // === 必填 ===
                  _SectionTitle('必填信息'),
                  _buildRecipientSelector(recipients),
                  const SizedBox(height: 12),
                  _buildTextField(
                    _hospitalController,
                    '医院名称 *',
                    validator: (v) =>
                        v == null || v.isEmpty ? '请输入医院名称' : null,
                  ),
                  const SizedBox(height: 20),

                  // === 复诊时间 ===
                  _SectionTitle('复诊时间'),
                  _buildDateTimePreview(),
                  const SizedBox(height: 20),

                  // === 选填：医生信息 ===
                  _SectionTitle('医生信息（选填）'),
                  const _SectionHint('填写后可在复诊卡片直接联系医生'),
                  _buildTextField(_departmentController, '科室'),
                  _buildTextField(_doctorNameController, '医生姓名'),
                  _buildTextField(
                    _doctorPhoneController,
                    '医生电话',
                    keyboardType: TextInputType.phone,
                  ),
                  _buildTextField(_purposeController, '就诊目的'),
                  const SizedBox(height: 16),

                  // 分隔
                  const _SectionDivider(),
                  const SizedBox(height: 16),

                  // === 附加信息 ===
                  _SectionTitle('附加信息（选填）'),
                  _buildTextField(_appointmentNoController, '挂号序号'),
                  _buildTextField(
                    _feeController,
                    '挂号费（元）',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  _buildTextField(_addressController, '医院地址'),
                  const SizedBox(height: 16),

                  const _SectionDivider(),
                  const SizedBox(height: 16),

                  // === 接送安排 ===
                  _SectionTitle('接送安排'),
                  membersAsync.when(
                    data: (members) => _buildDriverSelector(members),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('无法加载家庭成员'),
                  ),
                  const SizedBox(height: 16),

                  const _SectionDivider(),
                  const SizedBox(height: 16),

                  // === 提醒设置 ===
                  _SectionTitle('提醒设置'),
                  const SizedBox(height: 8),
                  _buildReminderChips(),
                  const SizedBox(height: 16),

                  _buildTextField(_noteController, '备注', maxLines: 3),
                  const SizedBox(height: 32),

                  // 提交按钮
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  '保存',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.check_rounded, size: 18),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e')),
        ),
      ),
    );
  }

  Widget _buildDateTimePreview() {
    return Column(
      children: [
        // 日期选择
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_today_rounded,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '就诊日期',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _displayDate,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // 时间选择
        InkWell(
          onTap: _pickTime,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.schedule_rounded,
                      color: AppColors.coral, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '就诊时间',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _displayTime,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textTertiary, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _appointmentTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      setState(() {
        _appointmentTime = DateTime(
          date.year,
          date.month,
          date.day,
          _appointmentTimeOfDay.hour,
          _appointmentTimeOfDay.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _appointmentTimeOfDay,
    );
    if (time != null && mounted) {
      setState(() {
        _appointmentTimeOfDay = time;
        _appointmentTime = DateTime(
          _appointmentTime.year,
          _appointmentTime.month,
          _appointmentTime.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  Widget _buildReminderChips() {
    return Row(
      children: [
        Expanded(
          child: _ReminderChip(
            label: '48小时前提醒',
            icon: Icons.notifications_active_rounded,
            selected: _reminder48h,
            onTap: () => setState(() => _reminder48h = !_reminder48h),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ReminderChip(
            label: '24小时前提醒',
            icon: Icons.alarm_rounded,
            selected: _reminder24h,
            onTap: () => setState(() => _reminder24h = !_reminder24h),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientSelector(List<CareRecipient> recipients) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CareRecipient>(
          value: _selectedRecipient,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded),
          items: recipients.map((r) {
            return DropdownMenuItem(
              value: r,
              child: Row(
                children: [
                  Text(r.displayAvatar, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(r.name),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedRecipient = v),
        ),
      ),
    );
  }

  Widget _buildDriverSelector(List<FamilyMember> members) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedDriverId,
          isExpanded: true,
          hint: const Text('不指定接送人'),
          icon: const Icon(Icons.arrow_drop_down_rounded),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.person_off_outlined,
                      color: AppColors.textTertiary, size: 18),
                  SizedBox(width: 8),
                  Text('不指定接送人',
                      style: TextStyle(color: AppColors.textTertiary)),
                ],
              ),
            ),
            ...members.map((m) {
              return DropdownMenuItem(
                value: m.userId,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        m.nickname[0],
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(m.nickname),
                  ],
                ),
              );
            }),
          ],
          onChanged: (v) => setState(() => _selectedDriverId = v),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRecipient == null) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);
      final familyId = ref.read(currentFamilyProvider)?.id;
      await dio.post(
        '/appointments',
        data: {
          'recipientId': _selectedRecipient!.id,
          'hospital': _hospitalController.text,
          'department':
              _departmentController.text.isNotEmpty ? _departmentController.text : null,
          'doctorName':
              _doctorNameController.text.isNotEmpty ? _doctorNameController.text : null,
          'doctorPhone': _doctorPhoneController.text.isNotEmpty
              ? _doctorPhoneController.text
              : null,
          'appointmentTime': _appointmentTime.toUtc().toIso8601String(),
          'appointmentNo': _appointmentNoController.text.isNotEmpty
              ? _appointmentNoController.text
              : null,
          'address':
              _addressController.text.isNotEmpty ? _addressController.text : null,
          'fee': _feeController.text.isNotEmpty
              ? double.tryParse(_feeController.text)
              : null,
          'purpose':
              _purposeController.text.isNotEmpty ? _purposeController.text : null,
          'assignedDriverId': _selectedDriverId,
          'reminder48h': _reminder48h,
          'reminder24h': _reminder24h,
          'note': _noteController.text.isNotEmpty ? _noteController.text : null,
        },
        queryParameters: {'familyId': familyId},
      );

      // 递增刷新计数器，CalendarPage 的 calendarEventsProvider 会自动重新拉取
      ref.read(calendarRefreshProvider.notifier).update((s) => s + 1);
      // 刷新首页复诊数据和日历页数据
      final now = DateTime.now();
      final query = CalendarQuery(
        familyId: familyId ?? '',
        year: now.year,
        month: now.month,
      );
      ref.invalidate(calendarEventsProvider(query));
      ref.invalidate(calendarAppointmentsProvider(query));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('复诊已添加到 ${_appointmentTime.month}月${_appointmentTime.day}日')),
        );
        // 稍等 snackbar 显示后再返回
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }
}

/// 提醒 Chip
class _ReminderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ReminderChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              size: 14,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SectionHint extends StatelessWidget {
  final String text;
  const _SectionHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '可选',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}
