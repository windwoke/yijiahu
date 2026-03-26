/// 添加任务页
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';

class AddTaskPage extends ConsumerStatefulWidget {
  const AddTaskPage({super.key});

  @override
  ConsumerState<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends ConsumerState<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();

  CareRecipient? _selectedRecipient;
  String _frequency = 'once';
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 9, minute: 0);
  List<int> _scheduledDays = [];
  FamilyMember? _selectedAssignee;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
        title: const Text('添加任务'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: recipientsAsync.when(
        data: (recipients) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 任务标题
                _SectionTitle('任务信息'),
                _buildTextField(_titleController, '任务标题 *', validator: (v) =>
                  v == null || v.isEmpty ? '请输入任务标题' : null),
                _buildTextField(_descriptionController, '任务描述', maxLines: 3),
                const SizedBox(height: 20),

                // 照护对象（可选）
                _SectionTitle('关联照护对象（可选）'),
                _buildRecipientSelector(recipients),
                const SizedBox(height: 20),

                // 频率
                _SectionTitle('重复频率'),
                _buildFrequencySelector(),
                const SizedBox(height: 20),

                // 时间（仅周期任务）
                if (_frequency != 'once') ...[
                  _SectionTitle('执行时间'),
                  _buildTimePicker(),
                  const SizedBox(height: 8),
                  if (_frequency == 'weekly') _buildWeekdaySelector(),
                  if (_frequency == 'monthly') _buildDaySelector(),
                  const SizedBox(height: 20),
                ],

                // 负责人
                _SectionTitle('负责人'),
                membersAsync.when(
                  data: (members) => _buildAssigneeSelector(members),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('无法加载家庭成员'),
                ),
                const SizedBox(height: 20),

                _buildTextField(_noteController, '备注', maxLines: 3),
                const SizedBox(height: 32),

                // 提交
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24, height: 24,
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
        child: DropdownButton<CareRecipient?>(
          value: _selectedRecipient,
          isExpanded: true,
          hint: const Text('不关联'),
          items: [
            const DropdownMenuItem(value: null, child: Text('不关联')),
            ...recipients.map((r) {
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
            }),
          ],
          onChanged: (v) => setState(() => _selectedRecipient = v),
        ),
      ),
    );
  }

  Widget _buildFrequencySelector() {
    final options = [
      ('once', '单次'),
      ('daily', '每日'),
      ('weekly', '每周'),
      ('monthly', '每月'),
    ];
    return Wrap(
      spacing: 8,
      children: options.map((opt) {
        final selected = _frequency == opt.$1;
        return ChoiceChip(
          label: Text(opt.$2),
          selected: selected,
          selectedColor: AppColors.blue.withValues(alpha: 0.2),
          labelStyle: TextStyle(
            color: selected ? AppColors.blue : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
          onSelected: (_) => setState(() {
            _frequency = opt.$1;
            _scheduledDays = [];
          }),
        );
      }).toList(),
    );
  }

  Widget _buildTimePicker() {
    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: _scheduledTime,
        );
        if (time != null && mounted) {
          setState(() => _scheduledTime = time);
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
              '${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdaySelector() {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('选择星期'),
        Wrap(
          spacing: 6,
          children: List.generate(7, (i) {
            final day = i + 1;
            final selected = _scheduledDays.contains(day);
            return FilterChip(
              label: Text(weekdays[i]),
              selected: selected,
              selectedColor: AppColors.blue.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: selected ? AppColors.blue : AppColors.textSecondary,
                fontSize: 13,
              ),
              onSelected: (_) {
                setState(() {
                  if (selected) {
                    _scheduledDays.remove(day);
                  } else {
                    _scheduledDays.add(day);
                  }
                });
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('选择日期（每月）'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(31, (i) {
            final day = i + 1;
            final selected = _scheduledDays.contains(day);
            return FilterChip(
              label: Text('$day'),
              selected: selected,
              selectedColor: AppColors.blue.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: selected ? AppColors.blue : AppColors.textSecondary,
                fontSize: 13,
              ),
              onSelected: (_) {
                setState(() {
                  if (selected) {
                    _scheduledDays.remove(day);
                  } else {
                    _scheduledDays.add(day);
                  }
                });
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildAssigneeSelector(List<FamilyMember> members) {
    if (members.isEmpty) {
      return const Text('家庭中暂无其他成员');
    }
    _selectedAssignee ??= members.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<FamilyMember>(
          value: _selectedAssignee,
          isExpanded: true,
          items: members.map((m) {
            return DropdownMenuItem(
              value: m,
              child: Text(m.nickname),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedAssignee = v),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAssignee == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择负责人')));
      return;
    }
    if (_frequency != 'once' && _scheduledDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择执行日期')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);
      final familyId = ref.read(currentFamilyProvider)?.id;

      await dio.post('/family-tasks', data: {
        'familyId': familyId,
        'recipientId': _selectedRecipient?.id,
        'title': _titleController.text,
        'description': _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        'frequency': _frequency,
        'scheduledTime': _frequency != 'once'
            ? '${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}'
            : null,
        'scheduledDay': _scheduledDays.isNotEmpty ? _scheduledDays : null,
        'assigneeId': _selectedAssignee!.userId,
        'note': _noteController.text.isNotEmpty ? _noteController.text : null,
      });

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('任务已添加')));
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
