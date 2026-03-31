/// 通知设置页
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/notification_provider.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends ConsumerState<NotificationSettingsPage> {
  bool _isLoading = true;
  late NotificationPreference _pref;
  final Map<String, dynamic> _pendingChanges = {};
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final pref = await ref.read(notificationPreferenceProvider.future);
    if (mounted) {
      setState(() {
        _pref = pref;
        _isLoading = false;
      });
    }
  }

  void _onToggle(String key, bool value) {
    setState(() {
      _pendingChanges[key] = value;
      _hasChanges = true;
    });
    _savePreference({key: value});
  }

  void _onIntChange(String key, int value) {
    setState(() {
      _pendingChanges[key] = value;
      _hasChanges = true;
    });
    _savePreference({key: value});
  }

  Future<void> _savePreference(Map<String, dynamic> updates) async {
    try {
      await updateNotificationPreference(ref, updates);
    } catch (_) {}
  }

  bool _getValue(String key, bool defaultVal) {
    return _pendingChanges[key] ?? _pref != null ? _getPrefValue(key, defaultVal) : defaultVal;
  }

  bool _getPrefValue(String key, bool defaultVal) {
    switch (key) {
      case 'medicationReminder': return _pref.medicationReminder;
      case 'missedDose': return _pref.missedDose;
      case 'appointmentReminder': return _pref.appointmentReminder;
      case 'taskReminder': return _pref.taskReminder;
      case 'dailyCheckin': return _pref.dailyCheckin;
      case 'healthAlert': return _pref.healthAlert;
      case 'sosEnabled': return _pref.sosEnabled;
      case 'dndEnabled': return _pref.dndEnabled;
      case 'soundEnabled': return _pref.soundEnabled;
      case 'vibrationEnabled': return _pref.vibrationEnabled;
      default: return defaultVal;
    }
  }

  int _getIntValue(String key, int defaultVal) {
    if (_pendingChanges.containsKey(key)) return _pendingChanges[key] as int;
    if (_pref != null) {
      switch (key) {
        case 'medicationLeadMinutes': return _pref.medicationLeadMinutes;
        case 'appointmentLeadHours': return _pref.appointmentLeadHours;
      }
    }
    return defaultVal;
  }

  String _getStrValue(String key, String defaultVal) {
    if (_pendingChanges.containsKey(key)) return _pendingChanges[key] as String;
    if (_pref != null) {
      switch (key) {
        case 'dndStart': return _pref.dndStart;
        case 'dndEnd': return _pref.dndEnd;
      }
    }
    return defaultVal;
  }

  @override
  Widget build(BuildContext context) {
    final prefAsync = ref.watch(notificationPreferenceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '通知设置',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : prefAsync.when(
              data: (_) => _buildContent(),
              loading: () => _buildContent(),
              error: (_, __) => _buildContent(),
            ),
    );
  }

  Widget _buildContent() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        _buildSectionHeader('通知开关'),
        _buildCard([
          _buildSwitchItem(
            icon: Icons.medication_outlined,
            title: '用药提醒',
            subtitle: '药品服用时间前发送提醒',
            value: _getValue('medicationReminder', true),
            onChanged: (v) => _onToggle('medicationReminder', v),
          ),
          _buildDivider(),
          _buildSwitchItem(
            icon: Icons.warning_amber_rounded,
            title: '漏服通知',
            subtitle: '服药时间超过30分钟未打卡时通知',
            value: _getValue('missedDose', true),
            onChanged: (v) => _onToggle('missedDose', v),
          ),
          _buildDivider(),
          _buildSwitchItem(
            icon: Icons.event_outlined,
            title: '复诊提醒',
            subtitle: '复诊前24小时发送提醒',
            value: _getValue('appointmentReminder', true),
            onChanged: (v) => _onToggle('appointmentReminder', v),
          ),
          _buildDivider(),
          _buildSwitchItem(
            icon: Icons.task_alt_outlined,
            title: '任务提醒',
            subtitle: '家庭任务到期前15分钟通知',
            value: _getValue('taskReminder', true),
            onChanged: (v) => _onToggle('taskReminder', v),
          ),
          _buildDivider(),
          _buildSwitchItem(
            icon: Icons.edit_calendar_outlined,
            title: '每日打卡提醒',
            subtitle: '前一日未打卡时09:00发送提醒',
            value: _getValue('dailyCheckin', true),
            onChanged: (v) => _onToggle('dailyCheckin', v),
          ),
          _buildDivider(),
          _buildSwitchItem(
            icon: Icons.favorite_outline,
            title: '健康告警',
            subtitle: '血压/血糖超出正常范围时通知',
            value: _getValue('healthAlert', true),
            onChanged: (v) => _onToggle('healthAlert', v),
          ),
          _buildDivider(),
          _buildSwitchItem(
            icon: Icons.emergency_outlined,
            title: '紧急求助（SOS）',
            subtitle: '家庭成员触发SOS时通知（强制推送）',
            value: _getValue('sosEnabled', true),
            onChanged: (v) => _onToggle('sosEnabled', v),
          ),
        ]),

        const SizedBox(height: 16),

        _buildSectionHeader('提醒时间'),
        _buildCard([
          _buildPickerItem(
            icon: Icons.schedule_outlined,
            title: '用药提醒提前',
            value: '${_getIntValue('medicationLeadMinutes', 5)} 分钟',
            onTap: () => _showMedicationLeadPicker(),
          ),
          _buildDivider(),
          _buildPickerItem(
            icon: Icons.event_outlined,
            title: '复诊提醒提前',
            value: _appointmentHoursLabel(_getIntValue('appointmentLeadHours', 24)),
            onTap: () => _showAppointmentLeadPicker(),
          ),
        ]),

        const SizedBox(height: 16),

        _buildSectionHeader('免打扰'),
        _buildCard([
          _buildSwitchItem(
            icon: Icons.do_not_disturb_on_outlined,
            title: '免打扰时段',
            subtitle: '开启后在设定时段内不发送普通通知',
            value: _getValue('dndEnabled', false),
            onChanged: (v) => _onToggle('dndEnabled', v),
          ),
          if (_getValue('dndEnabled', false)) ...[
            _buildDivider(),
            _buildPickerItem(
              icon: Icons.bedtime_outlined,
              title: '开始时间',
              value: _getStrValue('dndStart', '22:00'),
              onTap: () => _showTimePicker('dndStart', '22:00'),
            ),
            _buildDivider(),
            _buildPickerItem(
              icon: Icons.wb_sunny_outlined,
              title: '结束时间',
              value: _getStrValue('dndEnd', '07:00'),
              onTap: () => _showTimePicker('dndEnd', '07:00'),
            ),
          ],
        ]),

        const SizedBox(height: 16),

        _buildSectionHeader('推送方式'),
        _buildCard([
          _buildSwitchItem(
            icon: Icons.volume_up_rounded,
            title: '声音',
            subtitle: '收到通知时播放提示音',
            value: _getValue('soundEnabled', true),
            onChanged: (v) => _onToggle('soundEnabled', v),
          ),
          _buildDivider(),
          _buildSwitchItem(
            icon: Icons.vibration_outlined,
            title: '振动',
            subtitle: '收到通知时振动提醒',
            value: _getValue('vibrationEnabled', true),
            onChanged: (v) => _onToggle('vibrationEnabled', v),
          ),
        ]),

        const SizedBox(height: 32),
      ],
    );
  }

  String _appointmentHoursLabel(int hours) {
    if (hours >= 72) return '3 天';
    if (hours >= 48) return '2 天';
    if (hours >= 24) return '1 天';
    return '$hours 小时';
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 2)),
          BoxShadow(color: AppColors.shadowSoft2, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 56, color: AppColors.borderLight);
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildPickerItem({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              ),
            ),
            Text(
              value,
              style: const TextStyle(color: AppColors.primary, fontSize: 14),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  void _showMedicationLeadPicker() {
    final options = [5, 10, 15, 30, 60];
    final current = _getIntValue('medicationLeadMinutes', 5);
    _showPicker(
      title: '用药提醒提前',
      options: options.map((o) => '$o 分钟').toList(),
      currentIndex: options.indexOf(current).clamp(0, options.length - 1),
      onSelect: (idx) => _onIntChange('medicationLeadMinutes', options[idx]),
    );
  }

  void _showAppointmentLeadPicker() {
    final options = [1, 2, 3, 6, 12, 24, 48, 72];
    final current = _getIntValue('appointmentLeadHours', 24);
    String label(int h) {
      if (h >= 72) return '3 天';
      if (h >= 48) return '2 天';
      if (h >= 24) return '1 天';
      return '$h 小时';
    }
    _showPicker(
      title: '复诊提醒提前',
      options: options.map(label).toList(),
      currentIndex: options.indexOf(current).clamp(0, options.length - 1),
      onSelect: (idx) => _onIntChange('appointmentLeadHours', options[idx]),
    );
  }

  void _showPicker({
    required String title,
    required List<String> options,
    required int currentIndex,
    required ValueChanged<int> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...List.generate(options.length, (i) {
                final isSelected = i == currentIndex;
                return ListTile(
                  title: Text(
                    options[i],
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded, color: AppColors.primary)
                      : null,
                  onTap: () {
                    onSelect(i);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showTimePicker(String key, String defaultVal) async {
    final parts = _getStrValue(key, defaultVal).split(':');
    final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final val = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() => _pendingChanges[key] = val);
      _savePreference({key: val});
    }
  }
}
