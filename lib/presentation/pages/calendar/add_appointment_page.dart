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
  String? _selectedDriverId;
  bool _reminder48h = true;
  bool _reminder24h = true;
  bool _isLoading = false;

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

  @override
  Widget build(BuildContext context) {
    final recipientsAsync = ref.watch(careRecipientsProvider);
    final membersAsync = ref.watch(
      familyMembersProvider(ref.watch(currentFamilyProvider)?.id ?? ''),
    );

    return Scaffold(
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
                // 照护对象选择
                _SectionTitle('照护对象'),
                _buildRecipientSelector(recipients),
                const SizedBox(height: 20),

                // 基本信息
                _SectionTitle('复诊信息'),
                _buildTextField(_hospitalController, '医院名称 *', validator: (v) =>
                  v == null || v.isEmpty ? '请输入医院名称' : null),
                _buildTextField(_departmentController, '科室'),
                _buildTextField(_doctorNameController, '医生姓名'),
                _buildTextField(_doctorPhoneController, '医生电话', keyboardType: TextInputType.phone),
                const SizedBox(height: 20),

                // 时间
                _SectionTitle('复诊时间'),
                _buildDateTimePicker(),
                const SizedBox(height: 20),

                // 其他信息
                _buildTextField(_appointmentNoController, '挂号序号'),
                _buildTextField(_addressController, '地址'),
                _buildTextField(_feeController, '挂号费（元）', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                _buildTextField(_purposeController, '就诊目的'),
                const SizedBox(height: 20),

                // 接送人
                _SectionTitle('接送安排'),
                membersAsync.when(
                  data: (members) => _buildDriverSelector(members),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('无法加载家庭成员'),
                ),
                const SizedBox(height: 20),

                // 提醒
                _SectionTitle('提醒设置'),
                _buildReminderSwitch('48小时前提醒', _reminder48h, (v) => setState(() => _reminder48h = v)),
                _buildReminderSwitch('24小时前提醒', _reminder24h, (v) => setState(() => _reminder24h = v)),
                const SizedBox(height: 20),

                _buildTextField(_noteController, '备注', maxLines: 3),
                const SizedBox(height: 32),

                // 提交
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('保存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
          hint: const Text('选择接送人（可选）'),
          items: [
            const DropdownMenuItem(value: null, child: Text('不指定')),
            ...members.map((m) {
              return DropdownMenuItem(
                value: m.userId,
                child: Text(m.nickname),
              );
            }),
          ],
          onChanged: (v) => setState(() => _selectedDriverId = v),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _appointmentTime,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null && mounted) {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(_appointmentTime),
          );
          if (time != null && mounted) {
            setState(() {
              _appointmentTime = DateTime(
                date.year, date.month, date.day, time.hour, time.minute,
              );
            });
          }
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 10),
            Text(
              '${_appointmentTime.year}年${_appointmentTime.month}月${_appointmentTime.day}日 '
              '${_appointmentTime.hour.toString().padLeft(2, '0')}:${_appointmentTime.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            ),
          ],
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
      padding: const EdgeInsets.only(bottom: 12),
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
        ),
      ),
    );
  }

  Widget _buildReminderSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRecipient == null) return;

    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);
      final familyId = ref.read(currentFamilyProvider)?.id;
      await dio.post('/appointments', data: {
        'recipientId': _selectedRecipient!.id,
        'hospital': _hospitalController.text,
        'department': _departmentController.text.isNotEmpty ? _departmentController.text : null,
        'doctorName': _doctorNameController.text.isNotEmpty ? _doctorNameController.text : null,
        'doctorPhone': _doctorPhoneController.text.isNotEmpty ? _doctorPhoneController.text : null,
        'appointmentTime': _appointmentTime.toUtc().toIso8601String(),
        'appointmentNo': _appointmentNoController.text.isNotEmpty ? _appointmentNoController.text : null,
        'address': _addressController.text.isNotEmpty ? _addressController.text : null,
        'fee': _feeController.text.isNotEmpty ? double.tryParse(_feeController.text) : null,
        'purpose': _purposeController.text.isNotEmpty ? _purposeController.text : null,
        'assignedDriverId': _selectedDriverId,
        'reminder48h': _reminder48h,
        'reminder24h': _reminder24h,
        'note': _noteController.text.isNotEmpty ? _noteController.text : null,
      }, queryParameters: {'familyId': familyId});

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('复诊已添加')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
