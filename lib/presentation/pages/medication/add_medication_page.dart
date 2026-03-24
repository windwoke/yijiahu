/// 添加药品页
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';

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
  final List<TimeOfDay> _times = [const TimeOfDay(hour: 8, minute: 0)];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一个服药时间')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // TODO: 调用 API 保存药品
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        context.pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
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
            // 药品名称
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '${AppTexts.medicationName} *',
                hintText: '如：血压药、降糖药',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入药品名称';
                }
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
                if (value == null || value.isEmpty) {
                  return '请输入剂量';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
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
                  icon: const Icon(Icons.add),
                  label: const Text('添加时间'),
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      timeStr,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (_times.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: AppColors.error),
                        onPressed: () => _removeTime(index),
                      ),
                  ],
                ),
              );
            }),
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
            const SizedBox(height: 32),
            // 保存按钮
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(AppTexts.save),
            ),
          ],
        ),
      ),
    );
  }
}
