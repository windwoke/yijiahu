/// 添加药品页
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';

class AddMedicationPage extends ConsumerStatefulWidget {
  const AddMedicationPage({super.key});

  @override
  ConsumerState<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends ConsumerState<AddMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _prescribedByController = TextEditingController();

  MedicationFrequency _frequency = MedicationFrequency.daily;
  final List<TimeOfDay> _times = [const TimeOfDay(hour: 8, minute: 0)];
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    _prescribedByController.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );
    if (time != null) {
      setState(() {
        _times.add(time);
        _times.sort((a, b) {
          final aMin = a.hour * 60 + a.minute;
          final bMin = b.hour * 60 + b.minute;
          return aMin.compareTo(bMin);
        });
      });
    }
  }

  void _removeTime(int index) {
    if (_times.length > 1) {
      setState(() => _times.removeAt(index));
    }
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() => _startDate = date);
    }
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() => _endDate = date);
    }
  }

  String _frequencyLabel(MedicationFrequency f) {
    switch (f) {
      case MedicationFrequency.daily:
        return '每日';
      case MedicationFrequency.weekly:
        return '每周';
      case MedicationFrequency.asNeeded:
        return '按需';
    }
  }

  String _frequencyValue(MedicationFrequency f) {
    switch (f) {
      case MedicationFrequency.daily:
        return 'daily';
      case MedicationFrequency.weekly:
        return 'weekly';
      case MedicationFrequency.asNeeded:
        return 'as_needed';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_times.isEmpty) {
      setState(() => _errorMessage = '请至少添加一个服药时间');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final recipients = ref.read(careRecipientsProvider).valueOrNull ?? [];
      if (recipients.isEmpty) {
        setState(() => _errorMessage = '请先添加照护对象');
        return;
      }
      final recipientId = recipients.first.id;

      final times = _times.map((t) {
        return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      }).toList();

      final data = <String, dynamic>{
        'recipient_id': recipientId,
        'name': _nameController.text.trim(),
        'dosage': _dosageController.text.trim(),
        'frequency': _frequencyValue(_frequency),
        'times': times,
        'start_date': _startDate.toIso8601String().split('T').first,
      };

      if (_instructionsController.text.trim().isNotEmpty) {
        data['instructions'] = _instructionsController.text.trim();
      }
      if (_prescribedByController.text.trim().isNotEmpty) {
        data['prescribed_by'] = _prescribedByController.text.trim();
      }
      if (_endDate != null) {
        data['end_date'] = _endDate!.toIso8601String().split('T').first;
      }

      await dio.post('/medications', data: data);

      // 刷新药品列表
      ref.invalidate(medicationsProvider(recipientId));

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '保存失败，请重试');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipients = ref.watch(careRecipientsProvider);
    final recipient = recipients.valueOrNull?.firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(AppTexts.addMedication),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 照护对象提示
            if (recipient != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(recipient.displayAvatar, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      '为 ${recipient.name} 添加药品',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // 药品名称
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '${AppTexts.medicationName} *',
                hintText: '如：血压药、降糖药',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '请输入药品名称';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 剂量
            TextFormField(
              controller: _dosageController,
              decoration: const InputDecoration(
                labelText: '${AppTexts.dosage} *',
                hintText: '如：1颗、5mg',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '请输入剂量';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 用药频率
            Text(
              '用药频率',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: MedicationFrequency.values.map((f) {
                final selected = _frequency == f;
                return ChoiceChip(
                  label: Text(_frequencyLabel(f)),
                  selected: selected,
                  onSelected: (_) => setState(() => _frequency = f),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 服药时间
            Row(
              children: [
                Text(
                  AppTexts.takingTime,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addTime,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_times.length, (index) {
              final time = _times[index];
              final timeStr =
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(timeStr, style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (_times.length > 1)
                      GestureDetector(
                        onTap: () => _removeTime(index),
                        child: const Icon(Icons.remove_circle_outline,
                            color: AppColors.error, size: 20),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),

            // 日期范围
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: '开始日期',
                    value: _startDate,
                    onTap: _pickStartDate,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField(
                    label: '结束日期',
                    value: _endDate,
                    onTap: _pickEndDate,
                    hint: '长期服用',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 用药说明
            TextFormField(
              controller: _instructionsController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: AppTexts.instructions,
                hintText: '如：饭后服用、避免与柚子同食',
              ),
            ),
            const SizedBox(height: 16),

            // 开药医生
            TextFormField(
              controller: _prescribedByController,
              decoration: const InputDecoration(
                labelText: '开药医生',
                hintText: '如：王建国医生',
              ),
            ),
            const SizedBox(height: 16),

            // 错误提示
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 14),
                ),
              ),

            // 保存按钮
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(AppTexts.save),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    String hint = '',
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value != null
                  ? '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}'
                  : hint,
              style: TextStyle(
                fontSize: 15,
                color: value != null ? AppColors.textPrimary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
