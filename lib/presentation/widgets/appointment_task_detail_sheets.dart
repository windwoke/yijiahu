/// 复诊详情弹层 & 任务详情弹层（可被首页/日历等复用）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/constants.dart';
import '../../data/models/models.dart';
import '../../core/network/api_client.dart';
import '../providers/providers.dart';

/// 详情行
class DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          SizedBox(
            width: 68,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// 弹层操作按钮
class SheetActBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const SheetActBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 18), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600))]),
      ),
    );
  }
}

/// 复诊详情弹层
class AppointmentDetailSheet extends StatelessWidget {
  final Appointment appointment;
  const AppointmentDetailSheet({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final r = appointment.recipient;
    final d = appointment.appointmentTime;
    const wd = ['一', '二', '三', '四', '五', '六', '日'];

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),

          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              children: [
                // 标题行
                Row(
                  children: [
                    Text(r?.avatarEmoji ?? '👤', style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r?.name ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                  child: const Text('复诊', style: TextStyle(fontSize: 12, color: AppColors.coral, fontWeight: FontWeight.w600))),
                              const SizedBox(width: 6),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Text(appointment.statusLabel, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: AppColors.borderLight, height: 1),

                DetailRow(icon: Icons.schedule_rounded, label: '复诊时间',
                    value: '${d.year}年${d.month}月${d.day}日（${wd[d.weekday - 1]}） ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'),

                DetailRow(icon: Icons.local_hospital_rounded, label: '就诊医院', value: appointment.hospital),

                if (appointment.department != null) DetailRow(icon: Icons.medical_services_rounded, label: '科室', value: appointment.department!),

                if (appointment.doctorName != null) DetailRow(icon: Icons.person_rounded, label: '主治医生', value: appointment.doctorName!),

                if (appointment.appointmentNo != null) DetailRow(icon: Icons.tag_rounded, label: '挂号序号', value: appointment.appointmentNo!),

                if (appointment.fee != null) DetailRow(icon: Icons.payments_rounded, label: '挂号费用', value: '¥${appointment.fee!.toStringAsFixed(2)}'),

                if (appointment.address != null) DetailRow(icon: Icons.location_on_rounded, label: '就诊地址', value: appointment.address!),

                if (appointment.purpose != null) DetailRow(icon: Icons.assignment_rounded, label: '就诊目的', value: appointment.purpose!),

                if (appointment.assignedDriver != null) DetailRow(icon: Icons.directions_car_rounded, label: '接送人', value: appointment.assignedDriver!.name),

                DetailRow(icon: Icons.notifications_rounded, label: '提醒设置',
                    value: [if (appointment.reminder48h) '48小时前', if (appointment.reminder24h) '24小时前'].join(' · ')),

                if (appointment.note != null) DetailRow(icon: Icons.note_rounded, label: '备注', value: appointment.note!),

                const SizedBox(height: 20),

                Row(
                  children: [
                    if (appointment.doctorPhone != null) Expanded(child: SheetActBtn(icon: Icons.phone_rounded, label: '联系医生', color: AppColors.primary,
                        onTap: () async { final u = Uri.parse('tel:${appointment.doctorPhone}'); if (await canLaunchUrl(u)) await launchUrl(u); })),
                    if (appointment.doctorPhone != null && appointment.address != null) const SizedBox(width: 10),
                    if (appointment.address != null) Expanded(child: SheetActBtn(icon: Icons.map_rounded, label: '导航', color: AppColors.blue,
                        onTap: () async { final addr = Uri.parse('https://maps.apple.com/?q=${Uri.encodeComponent(appointment.address!)}'); if (await canLaunchUrl(addr)) await launchUrl(addr, mode: LaunchMode.externalApplication); })),
                    const SizedBox(width: 10),
                    Expanded(child: SheetActBtn(icon: Icons.close_rounded, label: '关闭', color: AppColors.textTertiary, onTap: () => Navigator.pop(context))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 任务详情弹层
class TaskDetailSheet extends ConsumerStatefulWidget {
  final FamilyTask task;
  final String familyId;
  final VoidCallback? onComplete;
  final VoidCallback? onDeleted;
  const TaskDetailSheet({required this.task, required this.familyId, this.onComplete, this.onDeleted});

  @override
  ConsumerState<TaskDetailSheet> createState() => TaskDetailSheetState();
}

class TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  bool _completedLocally = false;
  bool get _canComplete {
    final role = ref.watch(currentFamilyProvider)?.myRole ?? FamilyMemberRole.guest;
    return role.canCompleteTask;
  }

  @override
  Widget build(BuildContext context) {
    final isPending = !_completedLocally && widget.task.isPending;
    final statusColor = isPending ? AppColors.primary : AppColors.textTertiary;
    final statusLabel = _completedLocally ? '已完成' : widget.task.statusLabel;
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];

    String dayLabel() {
      if (widget.task.scheduledDay == null || widget.task.scheduledDay!.isEmpty) return '';
      if (widget.task.frequency == 'weekly') {
        return widget.task.scheduledDay!.map((d) => '周${weekdays[d - 1]}').join('、');
      }
      return widget.task.scheduledDay!.map((d) => '$d日').join('、');
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),

          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              children: [
                Row(
                  children: [
                    Text(widget.task.recipient?.avatarEmoji ?? '👤', style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.task.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Text(widget.task.frequencyLabel, style: const TextStyle(fontSize: 12, color: AppColors.blue, fontWeight: FontWeight.w600))),
                              const SizedBox(width: 6),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Text(statusLabel, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: AppColors.borderLight, height: 1),

                if (widget.task.recipient != null) DetailRow(icon: Icons.people_rounded, label: '照护对象', value: widget.task.recipient!.name),
                DetailRow(icon: Icons.schedule_rounded, label: '执行时间', value: '${dayLabel()} ${widget.task.scheduledTime ?? ''}'.trim()),
                if (widget.task.nextDueAt != null) DetailRow(icon: Icons.event_rounded, label: '下次到期', value: widget.task.displayDueAt),
                if (widget.task.assignee != null) DetailRow(icon: Icons.person_rounded, label: '负责人', value: widget.task.assignee!.displayName),
                if (widget.task.description != null) DetailRow(icon: Icons.description_rounded, label: '任务描述', value: widget.task.description!),
                if (widget.task.note != null) DetailRow(icon: Icons.note_rounded, label: '备注', value: widget.task.note!),

                const SizedBox(height: 20),

                Row(
                  children: [
                    if (isPending && _canComplete) Expanded(child: SheetActBtn(icon: Icons.check_circle_rounded, label: '标记完成', color: AppColors.success, onTap: _complete)),
                    if (isPending) const SizedBox(width: 10),
                    Expanded(child: SheetActBtn(icon: Icons.close_rounded, label: '关闭', color: AppColors.textTertiary, onTap: () => Navigator.pop(context))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _complete() async {
    if (_completedLocally) return;
    setState(() => _completedLocally = true);
    try {
      final dio = ref.read(dioProvider);
      final dueDate = widget.task.nextDueAt;
      final scheduledDate = dueDate != null
          ? '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}'
          : null;
      await dio.post('/family-tasks/${widget.task.id}/complete',
          queryParameters: {'familyId': widget.familyId},
          data: scheduledDate != null ? {'scheduledDate': scheduledDate} : {});
      if (dueDate != null) {
        final instanceKey = '${widget.task.id}_$scheduledDate';
        ref.read(completedInstancesProvider.notifier).update((s) => {...s, instanceKey});
      }
      if (!mounted) return;
      widget.onComplete?.call();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('任务已完成')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _completedLocally = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }
}
