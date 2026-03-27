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

  String get _timeLabel {
    final h = _scheduledTime.hour.toString().padLeft(2, '0');
    final m = _scheduledTime.minute.toString().padLeft(2, '0');
    switch (_frequency) {
      case 'daily':
        return '每天 $h:$m';
      case 'weekly':
        return '每周 $h:$m';
      case 'monthly':
        return '每月 $h:$m';
      default:
        return '$h:$m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipientsAsync = ref.watch(careRecipientsProvider);
    final membersAsync = ref.watch(
      familyMembersProvider(ref.watch(currentFamilyProvider)?.id ?? ''),
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
                  // === 任务信息 ===
                  _SectionTitle('任务信息'),
                  _buildTextField(
                    _titleController,
                    '任务标题 *',
                    validator: (v) =>
                        v == null || v.isEmpty ? '请输入任务标题' : null,
                  ),
                  _buildTextField(_descriptionController, '任务描述（选填）',
                      maxLines: 3),
                  const SizedBox(height: 20),

                  // === 关联照护对象 ===
                  _SectionTitle('关联照护对象（选填）'),
                  const _SectionHint('关联后可在照护对象详情页查看此任务'),
                  _buildRecipientSelector(recipients),
                  const SizedBox(height: 20),

                  // === 重复频率 ===
                  _SectionTitle('重复频率'),
                  _buildFrequencySelector(),
                  const SizedBox(height: 16),

                  // === 时间 & 周期日（周期任务）===
                  if (_frequency != 'once') ...[
                    _SectionTitle('执行时间'),
                    _buildTimePicker(),
                    const SizedBox(height: 12),
                    if (_frequency == 'weekly') ...[
                      _buildWeekdaySelector(),
                    ],
                    if (_frequency == 'monthly') ...[
                      _buildDaySelector(),
                    ],
                    // 未选日期警告（仅 weekly/monthly 需要选日期）
                    if (_frequency != 'once' && _scheduledDays.isEmpty && _frequency != 'daily')
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 14, color: AppColors.coral),
                            const SizedBox(width: 6),
                            Text(
                              _frequency == 'weekly'
                                  ? '请选择要执行的星期'
                                  : '请选择要执行的日期',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.coral),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],

                  // === 负责人 ===
                  _SectionTitle('负责人 *'),
                  membersAsync.when(
                    data: (members) => _buildAssigneeSelector(members),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, st) => const Text('无法加载家庭成员'),
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(_noteController, '备注（选填）', maxLines: 3),
                  const SizedBox(height: 32),

                  // 提交按钮
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
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
                                const Icon(Icons.task_alt_rounded, size: 18),
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
          icon: const Icon(Icons.arrow_drop_down_rounded),
          hint: const Text('不关联'),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('不关联', style: TextStyle(color: AppColors.textTertiary)),
            ),
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
      ('once', '单次', Icons.looks_one_rounded),
      ('daily', '每日', Icons.repeat_rounded),
      ('weekly', '每周', Icons.date_range_rounded),
      ('monthly', '每月', Icons.calendar_month_rounded),
    ];
    return Row(
      children: options.map((opt) {
        final selected = _frequency == opt.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _frequency = opt.$1;
              _scheduledDays = [];
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(
                  right: opt.$1 != 'monthly' ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.blue.withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AppColors.blue.withValues(alpha: 0.4)
                      : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    opt.$3,
                    size: 20,
                    color: selected ? AppColors.blue : AppColors.textTertiary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    opt.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color:
                          selected ? AppColors.blue : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.schedule_rounded,
                  color: AppColors.blue, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              _timeLabel,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: 20),
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
          runSpacing: 6,
          children: List.generate(7, (i) {
            final day = i + 1;
            final selected = _scheduledDays.contains(day);
            return _WeekdayChip(
              label: weekdays[i],
              selected: selected,
              onTap: () {
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
        SizedBox(
          height: 76,
          child: GridView.builder(
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.1,
            ),
            itemCount: 31,
            itemBuilder: (context, i) {
              final day = i + 1;
              final selected = _scheduledDays.contains(day);
              return _DayChip(
                day: day,
                selected: selected,
                onTap: () {
                  setState(() {
                    if (selected) {
                      _scheduledDays.remove(day);
                    } else {
                      _scheduledDays.add(day);
                    }
                  });
                },
              );
            },
          ),
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
          icon: const Icon(Icons.arrow_drop_down_rounded),
          items: members.map((m) {
            return DropdownMenuItem(
              value: m,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.blue.withValues(alpha: 0.1),
                    child: Text(
                      m.nickname.isNotEmpty ? m.nickname[0] : '?',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.blue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(m.nickname)),
                ],
              ),
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
      padding: const EdgeInsets.only(bottom: 10),
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
    if (_selectedAssignee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择负责人')),
      );
      return;
    }
    if (_frequency != 'once' && _frequency != 'daily' && _scheduledDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_frequency == 'weekly' ? '请选择要执行的星期' : '请选择要执行的日期')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);
      final familyId = ref.read(currentFamilyProvider)?.id;
      final h = _scheduledTime.hour.toString().padLeft(2, '0');
      final m = _scheduledTime.minute.toString().padLeft(2, '0');

      await dio.post('/family-tasks', data: {
        'familyId': familyId,
        'recipientId': _selectedRecipient?.id,
        'title': _titleController.text,
        'description': _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        'frequency': _frequency,
        'scheduledTime': _frequency != 'once' ? '$h:$m' : null,
        'scheduledDay':
            _scheduledDays.isNotEmpty ? _scheduledDays : null,
        'assigneeId': _selectedAssignee!.userId,
        'note':
            _noteController.text.isNotEmpty ? _noteController.text : null,
      });

      // 刷新日历数据
      final now = DateTime.now();
      ref.invalidate(calendarEventsProvider(CalendarQuery(
        familyId: familyId ?? '',
        year: now.year,
        month: now.month,
      )));
      ref.invalidate(familyTasksProvider(familyId ?? ''));
      ref.invalidate(upcomingTasksProvider(familyId ?? ''));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('任务已添加')),
        );
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

/// 星期选择 Chip
class _WeekdayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _WeekdayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: selected ? AppColors.blue.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.blue.withValues(alpha: 0.4)
                : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? AppColors.blue : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 日期选择 Chip（紧凑）
class _DayChip extends StatelessWidget {
  final int day;
  final bool selected;
  final VoidCallback onTap;
  const _DayChip({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 36,
        decoration: BoxDecoration(
          color:
              selected ? AppColors.blue.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.blue.withValues(alpha: 0.4)
                : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? AppColors.blue : AppColors.textSecondary,
            ),
          ),
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
