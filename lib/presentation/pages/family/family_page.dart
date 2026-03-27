/// 家庭成员页
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/constants.dart';
import '../../../core/env/env_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/models.dart' as models;
import '../../providers/providers.dart';

/// 照护贡献统计
class _ContributionCount {
  final String authorId;
  final String authorName;
  int careLogs = 0;
  int medCheckins = 0;
  int rank = 0;
  _ContributionCount({required this.authorId, required this.authorName});
  int get total => careLogs + medCheckins;
}

/// 家庭成员 + 照护对象合并数据
class FamilyMemberSection {
  final String id;
  final bool isRecipient;
  final models.FamilyMember? member;
  final models.CareRecipient? recipient;

  const FamilyMemberSection({
    required this.id,
    required this.isRecipient,
    this.member,
    this.recipient,
  });

  String get displayName {
    if (isRecipient) return recipient!.name;
    return member!.nickname;
  }

  String get displayAvatar {
    if (isRecipient) return recipient!.displayAvatar;
    final name = member!.nickname;
    return name.isNotEmpty ? name[0] : '?';
  }

  String? get avatarUrl {
    if (isRecipient) return recipient!.avatarUrl;
    return member!.avatarUrl;
  }

  String? get phone {
    if (isRecipient) return recipient!.emergencyPhone;
    return member!.phone;
  }

  bool get isOnline {
    if (isRecipient) return false;
    return member!.isOnline;
  }

  String get roleLabel {
    if (isRecipient) return '照护对象';
    return member!.roleLabel;
  }

  /// 成员是否为 owner/coordinator（用于样式标识）
  bool get isElevatedRole {
    if (isRecipient) return false;
    return member!.role == 'owner' || member!.role == 'coordinator';
  }
}

class FamilyPage extends ConsumerWidget {
  const FamilyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);

    if (family == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text(AppTexts.familyMembers)),
        body: const Center(child: Text('请先创建或加入家庭')),
      );
    }

    // 并行加载成员和照护对象
    final membersAsync = ref.watch(familyMembersProvider(family.id));
    final recipientsAsync = ref.watch(careRecipientsProvider);
    final myRole = family.myRole;
    final canManageFamily = myRole.canManageFamily;   // 家庭设置（仅 owner）
    final canManageMembers = myRole.canManageMembers; // 成员管理（owner + coordinator）

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '家庭成员',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          if (canManageFamily)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: AppColors.textPrimary),
              onPressed: () => _showEditFamilySheet(context, ref, family),
            ),
        ],
      ),
      body: membersAsync.when(
        data: (members) => recipientsAsync.when(
          data: (recipients) {
            final totalCount = members.length + recipients.length;
            final sections = _buildSections(members, recipients);
            return _buildBody(context, ref, family, totalCount, sections, canManageMembers);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) {
            final totalCount = members.length;
            return _buildBody(context, ref, family, totalCount, _buildSections(members, []), canManageMembers);
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  List<FamilyMemberSection> _buildSections(
    List<models.FamilyMember> members,
    List<models.CareRecipient> recipients,
  ) {
    final memberSections = members
        .where((m) => m.userId != null)
        .map((m) => FamilyMemberSection(
              id: m.id,
              isRecipient: false,
              member: m,
            ))
        .toList();

    final recipientSections = recipients
        .map((r) => FamilyMemberSection(
              id: r.id,
              isRecipient: true,
              recipient: r,
            ))
        .toList();

    return [...memberSections, ...recipientSections];
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    models.Family family,
    int memberCount,
    List<FamilyMemberSection> sections,
    bool canManageMembers,
  ) {
    return CustomScrollView(
      slivers: [
        // 家庭信息卡片（邀请码）
        SliverToBoxAdapter(
          child: _buildFamilyCard(context, family, memberCount),
        ),
        // 成员列表
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final section = sections[index];
                return _buildMemberCard(context, ref, family, section, canManageMembers);
              },
              childCount: sections.length,
            ),
          ),
        ),
        // 本月照护贡献统计
        SliverToBoxAdapter(
          child: _buildContributionStats(context, ref, family),
        ),
        // 底部间距 + 添加按钮
        if (canManageMembers)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              child: Column(
                children: [
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 16),
                  // 一行两按钮
                  Row(
                    children: [
                      Expanded(
                        child: _buildAddButton(
                          context,
                          icon: Icons.person_add_rounded,
                          label: '添加成员',
                          compact: true,
                          onTap: () => _showAddMemberSheet(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildAddButton(
                          context,
                          icon: Icons.elderly_rounded,
                          label: '添加照护对象',
                          compact: true,
                          onTap: () => context.push(AppRoutes.addCareRecipient),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildContributionStats(
    BuildContext context,
    WidgetRef ref,
    models.Family family,
  ) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    return FutureBuilder<List<models.TimelineEntry>>(
      future: _fetchMonthlyTimeline(ref, family.id),
      builder: (context, snapshot) {
        // 计算本月统计
        final entries = snapshot.data ?? [];
        final monthEntries = entries.where((e) => e.time.isAfter(monthStart)).toList();

        // 按 authorId 分组统计
        final Map<String, _ContributionCount> stats = {};
        for (final entry in monthEntries) {
          final authorId = entry.authorId ?? 'unknown';
          final authorName = entry.author;
          stats.putIfAbsent(authorId, () => _ContributionCount(authorId: authorId, authorName: authorName));
          if (entry.source == 'medication_log') {
            stats[authorId]!.medCheckins++;
          } else {
            stats[authorId]!.careLogs++;
          }
        }

        if (stats.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: _buildStatsCard(
              title: '本月照护贡献',
              subtitle: '${now.month}月',
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.bar_chart_rounded, size: 28, color: AppColors.primary),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '暂无本月数据',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // 按总贡献数排序并设置排名
        final sortedStats = stats.values.toList()
          ..sort((a, b) => b.total.compareTo(a.total));
        for (var i = 0; i < sortedStats.length; i++) {
          sortedStats[i].rank = i;
        }
        final maxTotal = sortedStats.isEmpty ? 1 : sortedStats.first.total;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: _buildStatsCard(
            title: '本月照护贡献',
            subtitle: '${now.month}月',
            child: Column(
              children: [
                ...sortedStats.take(6).map((s) => _buildBarChartRow(context, s, maxTotal)),
                if (sortedStats.length > 6)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '还有 ${sortedStats.length - 6} 位成员',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<models.TimelineEntry>> _fetchMonthlyTimeline(WidgetRef ref, String familyId) async {
    try {
      final dio = ref.read(dioProvider);
      final List<models.TimelineEntry> all = [];

      // 获取照护日志（本月限制100条）
      try {
        final careLogsResp = await dio.get('/care-logs', queryParameters: {
          'familyId': familyId,
          'limit': 100,
        });
        final careLogsData = careLogsResp.data is List
            ? careLogsResp.data as List
            : (careLogsResp.data['data'] as List?) ?? [];
        all.addAll(careLogsData.map((e) => models.TimelineEntry.fromCareLog(Map<String, dynamic>.from(e))));
      } catch (_) {}

      // 获取用药打卡（本月）
      try {
        final medResp = await dio.get('/medication-logs/timeline', queryParameters: {
          'familyId': familyId,
          'days': 45,
        });
        final medData = medResp.data is List
            ? medResp.data as List
            : (medResp.data['data'] as List?) ?? [];
        all.addAll(medData.map((e) => models.TimelineEntry.fromMedicationLog(Map<String, dynamic>.from(e))));
      } catch (_) {}

      return all;
    } catch (_) {
      return [];
    }
  }

  Widget _buildStatsCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.shadowSoft2,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.insights, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  /// 柱状图单行
  Widget _buildBarChartRow(BuildContext context, _ContributionCount stat, int maxTotal) {
    final fraction = maxTotal > 0 ? stat.total / maxTotal : 0.0;
    // 颜色按排名递减：第1名深色，后续渐淡
    final colors = [
      AppColors.primary,
      AppColors.primary.withValues(alpha: 0.7),
      AppColors.primary.withValues(alpha: 0.5),
      AppColors.primary.withValues(alpha: 0.35),
      AppColors.primary.withValues(alpha: 0.25),
      AppColors.primary.withValues(alpha: 0.15),
    ];
    final colorIdx = stat.rank < colors.length ? stat.rank : colors.length - 1;
    final barColor = colors[colorIdx];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                stat.authorName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${stat.total}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 10,
                  width: double.infinity,
                  color: AppColors.surfaceContainerLow,
                ),
                Container(
                  height: 10,
                  width: MediaQuery.of(context).size.width * fraction * 0.65,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${stat.careLogs}条日志 · ${stat.medCheckins}次打卡',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyCard(BuildContext context, models.Family family, int memberCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppColors.shadowSoft2,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 家庭 emoji + 名称
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: family.avatarUrl != null && family.avatarUrl!.isNotEmpty
                        ? Image.network(
                            ApiConfig.avatarUrl(family.avatarUrl!) ?? '',
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 28)),
                            ),
                          )
                        : const Center(
                            child: Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 28)),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        family.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (family.description != null && family.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          family.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$memberCount位成员',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 16),
            // 邀请码区域
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '邀请码',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        family.inviteCode,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _copyInviteCode(context, family.inviteCode),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.copy, size: 16, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          '复制邀请链接',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(
    BuildContext context,
    WidgetRef ref,
    models.Family family,
    FamilyMemberSection section,
    bool canManageMembers,
  ) {
    final currentUser = ref.watch(authStateProvider).user;
    final isCurrentUser = section.member?.userId == currentUser?.id;
    // 当前用户用 authState 中的手机号，其他成员用 member.phone
    final displayPhone = isCurrentUser
        ? currentUser?.phone
        : section.member?.phone;
    final memberRole = models.FamilyMemberRole.fromString(section.member?.role);
    final roleLabel = section.isRecipient ? '照护对象' : memberRole.label;
    final isElevated = !section.isRecipient && (section.member?.role == 'owner' || section.member?.role == 'coordinator');

    return GestureDetector(
      onTap: section.isRecipient
          ? () {
              if (section.recipient != null) {
                context.push(AppRoutes.careRecipientDetail, extra: section.recipient);
              }
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: AppColors.shadowSoft2,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // 头像
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: section.isRecipient
                    ? AppColors.coral.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Center(
                    child: section.avatarUrl != null && section.avatarUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              ApiConfig.avatarUrl(section.avatarUrl!) ?? '',
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => Text(
                                section.displayAvatar,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ),
                          )
                        : section.isRecipient
                            ? Text(section.displayAvatar, style: const TextStyle(fontSize: 24))
                            : Text(
                                section.displayAvatar,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                  ),
                  if (section.isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surfaceContainerLowest,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // 姓名 + 角色 + 电话
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        section.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: section.isRecipient
                              ? AppColors.coral.withValues(alpha: 0.1)
                              : (section.isElevatedRole
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : AppColors.surfaceContainerLow),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!section.isRecipient && isElevated)
                              const Icon(Icons.star,
                                  size: 12, color: AppColors.primary),
                            if (!section.isRecipient && isElevated)
                              const SizedBox(width: 3),
                            Text(
                              roleLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: section.isRecipient || section.isElevatedRole
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (displayPhone != null)
                    Row(
                      children: [
                        const Icon(Icons.phone_android,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _maskPhone(displayPhone),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  if (section.isRecipient)
                    Text(
                      '角色：被动用户（仅查看）',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  // 职责描述
                  const SizedBox(height: 6),
                  _buildResponsibilityTag(section),
                ],
              ),
            ),
            // 照护对象显示箭头，家庭成员显示编辑按钮
            if (section.isRecipient)
              const Icon(Icons.chevron_right, color: AppColors.textSecondary)
            else if (canManageMembers)
              GestureDetector(
                onTap: () => _showEditMemberSheet(context, ref, family, section, canManageMembers),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '编辑',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: compact ? 12 : 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: compact ? 18 : 20, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 14 : 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _maskPhone(String phone) {
    if (phone.length < 11) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }

  /// 根据成员角色生成职责描述标签
  Widget _buildResponsibilityTag(FamilyMemberSection section) {
    String text;
    Color bgColor;
    Color textColor;

    if (section.isRecipient) {
      text = '照护对象';
      bgColor = AppColors.coral.withValues(alpha: 0.08);
      textColor = AppColors.coral;
    } else {
      final role = models.FamilyMemberRole.fromString(section.member?.role);
      switch (role) {
        case models.FamilyMemberRole.owner:
          text = '家庭管理员，管理所有设置和成员';
          bgColor = AppColors.primary.withValues(alpha: 0.08);
          textColor = AppColors.primary;
        case models.FamilyMemberRole.coordinator:
          text = '协调管理，添加任务/复诊/成员';
          bgColor = AppColors.primary.withValues(alpha: 0.08);
          textColor = AppColors.primary;
        case models.FamilyMemberRole.caregiver:
          text = '照护记录，完成分配给自己的任务';
          bgColor = AppColors.success.withValues(alpha: 0.08);
          textColor = AppColors.success;
        case models.FamilyMemberRole.guest:
          text = '查看记录，添加照护日志';
          bgColor = AppColors.surfaceContainerLow;
          textColor = AppColors.textSecondary;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.book_rounded, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textColor),
          ),
        ],
      ),
    );
  }

  void _copyInviteCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('邀请码已复制到剪贴板'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showEditFamilySheet(BuildContext context, WidgetRef ref, models.Family family) {
    String name = family.name;
    String description = family.description ?? '';
    String? avatarUrl = family.avatarUrl;
    File? selectedAvatarFile;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40),
                    const Text(
                      '编辑家庭信息',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 头像
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    try {
                      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                      if (image != null) {
                        setState(() {
                          selectedAvatarFile = File(image.path);
                        });
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('无法访问相册，请检查权限设置'), behavior: SnackBarBehavior.floating),
                        );
                      }
                    }
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: selectedAvatarFile != null
                              ? Image.file(selectedAvatarFile!, width: 80, height: 80, fit: BoxFit.cover)
                              : (avatarUrl != null && avatarUrl.isNotEmpty
                                  ? Image.network(
                                      ApiConfig.avatarUrl(avatarUrl) ?? '',
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _buildFamilyEmoji(),
                                    )
                                  : _buildFamilyEmoji()),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '点击更换头像',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 20),

                // 家庭名称
                _buildInputField(
                  label: '家庭名称',
                  value: name,
                  hint: '例如：张氏大家庭',
                  maxLength: 30,
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 16),

                // 简介
                _buildInputField(
                  label: '一句话简介',
                  value: description,
                  hint: '描述一下您的家庭（选填）',
                  maxLength: 100,
                  maxLines: 2,
                  onChanged: (v) => description = v,
                ),
                const SizedBox(height: 24),

                // 保存按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    onPressed: isLoading
                        ? null
                        : () async {
                            if (name.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('家庭名称不能为空'), behavior: SnackBarBehavior.floating),
                              );
                              return;
                            }
                            setState(() => isLoading = true);
                            try {
                              String? newAvatarUrl = avatarUrl;

                              // 上传新头像
                              if (selectedAvatarFile != null) {
                                final dio = ref.read(dioProvider);
                                final formData = FormData.fromMap({
                                  'file': await MultipartFile.fromFile(selectedAvatarFile!.path),
                                });
                                final resp = await dio.post('/upload/avatar', data: formData);
                                newAvatarUrl = resp.data['avatarUrl'] as String;
                              }

                              await updateFamily(
                                ref: ref,
                                familyId: family.id,
                                name: name.trim(),
                                avatarUrl: newAvatarUrl,
                                description: description.trim().isEmpty ? null : description.trim(),
                              );

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('家庭信息已更新'), behavior: SnackBarBehavior.floating),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('更新失败: $e'), behavior: SnackBarBehavior.floating),
                                );
                              }
                            } finally {
                              if (ctx.mounted) {
                                setState(() => isLoading = false);
                              }
                            }
                          },
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('保存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(AppTexts.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFamilyEmoji() {
    return const Center(child: Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 36)));
  }

  Widget _buildInputField({
    required String label,
    required String value,
    required String hint,
    required int maxLength,
    int maxLines = 1,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: value,
          maxLength: maxLength,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _showEditMemberSheet(
    BuildContext context,
    WidgetRef ref,
    models.Family family,
    FamilyMemberSection section,
    bool canManageMembers,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '编辑成员',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              section.displayName,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            if (!section.isRecipient)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    // TODO: 修改成员分工
                  },
                  child: const Text('修改分工'),
                ),
              ),
            if (!section.isRecipient) const SizedBox(height: 12),
            if (canManageMembers && !section.isRecipient)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    // TODO: 设为管理员
                  },
                  child: const Text('设为管理员'),
                ),
              ),
            if (canManageMembers && !section.isRecipient)
              const SizedBox(height: 12),
            if (canManageMembers)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmRemoveMember(context, ref, family, section);
                  },
                  child: Text(
                    '移除${section.isRecipient ? "照护对象" : "成员"}',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              )
            else
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(AppTexts.cancel),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveMember(
    BuildContext context,
    WidgetRef ref,
    models.Family family,
    FamilyMemberSection section,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认移除'),
        content: Text('确定要将 ${section.displayName} 从家庭中移除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppTexts.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // TODO: 调用后端 API 移除成员
            },
            child: const Text(
              '移除',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMemberSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '添加成员',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '通过邀请码邀请家庭成员加入',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  // TODO: 显示邀请码
                },
                child: const Text('发送邀请链接'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(AppTexts.cancel),
            ),
          ],
        ),
      ),
    );
  }
}
