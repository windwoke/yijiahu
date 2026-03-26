/// 照护对象详情页
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/env/env_config.dart' show ApiConfig;
import '../../../data/models/models.dart' hide Family;
import '../../providers/family_provider.dart';

class CareRecipientDetailPage extends ConsumerStatefulWidget {
  final CareRecipient recipient;

  const CareRecipientDetailPage({super.key, required this.recipient});

  @override
  ConsumerState<CareRecipientDetailPage> createState() => _CareRecipientDetailPageState();
}

class _CareRecipientDetailPageState extends ConsumerState<CareRecipientDetailPage> {
  /// 健康趋势视图模式：列表 / 图表
  bool _healthChartMode = false;

  @override
  Widget build(BuildContext context) {
    final recipientAsync = ref.watch(careRecipientDetailProvider(widget.recipient.id));
    final medicationsAsync = ref.watch(medicationsProvider(widget.recipient.id));
    final healthTrendsAsync = ref.watch(healthTrendsProvider(widget.recipient.id));

    // 拿最新数据用于展示，过渡期用 widget.recipient兜底
    final recipient = recipientAsync.valueOrNull ?? widget.recipient;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(recipient.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
            onPressed: () async {
              await context.push(AppRoutes.addCareRecipient, extra: recipient);
              // 编辑返回后刷新数据
              ref.invalidate(careRecipientDetailProvider(widget.recipient.id));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: recipientAsync.when(
        loading: () => _buildBody(recipient, medicationsAsync, healthTrendsAsync),
        data: (_) => _buildBody(recipient, medicationsAsync, healthTrendsAsync),
        error: (_, __) => _buildBody(recipient, medicationsAsync, healthTrendsAsync),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/medication/add', extra: widget.recipient.id);
          ref.invalidate(medicationsProvider(widget.recipient.id));
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('添加药品', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildBody(
    CareRecipient recipient,
    AsyncValue<List<Medication>> medicationsAsync,
    AsyncValue<Map<String, List<HealthRecord>>> healthTrendsAsync,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderCard(recipient),
        const SizedBox(height: 16),
        _buildBasicInfoCard(recipient),
        const SizedBox(height: 16),
        _buildHealthCard(recipient),
        const SizedBox(height: 16),
        healthTrendsAsync.when(
          data: (trends) => _buildHealthTrendsSection(trends),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        _buildEmergencyCard(recipient),
        const SizedBox(height: 16),
        _buildHospitalCard(recipient),
        const SizedBox(height: 16),
        _buildMedicationSection(medicationsAsync),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildHeaderCard(CareRecipient r) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: AppColors.shadowSoft2, blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: (r.avatarUrl != null && r.avatarUrl!.isNotEmpty)
                  ? Image.network(
                      r.avatarUrl!.startsWith('http') ? r.avatarUrl! : '${ApiConfig.staticRoot}/${r.avatarUrl}',
                      fit: BoxFit.cover,
                      width: 72,
                      height: 72,
                      errorBuilder: (_, __, ___) => Text(r.displayAvatar, style: const TextStyle(fontSize: 40)),
                    )
                  : Center(
                      child: Text(r.displayAvatar, style: const TextStyle(fontSize: 40)),
                    ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (r.age != null) _buildTag('${r.age}岁', AppColors.surfaceContainerLow),
                    if (r.gender != null && r.gender!.isNotEmpty)
                      _buildTag(_genderLabel(r.gender!), AppColors.surfaceContainerLow),
                    if (r.bloodType != null && r.bloodType!.isNotEmpty)
                      _buildTag('${r.bloodType!}型', AppColors.coral.withValues(alpha: 0.1)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard(CareRecipient r) {
    final items = <_InfoItem>[];
    if (r.birthDate != null) items.add(_InfoItem('出生日期', _formatDate(r.birthDate!)));
    if (r.gender != null && r.gender!.isNotEmpty) items.add(_InfoItem('性别', _genderLabel(r.gender!)));
    if (r.bloodType != null && r.bloodType!.isNotEmpty) items.add(_InfoItem('血型', '${r.bloodType!}型'));
    if (r.phone != null && r.phone!.isNotEmpty) items.add(_InfoItem('手机', r.phone!));
    if (r.currentAddress != null && r.currentAddress!.isNotEmpty) {
      items.add(_InfoItem('家庭住址', r.currentAddress!));
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return _buildCard(
      title: '基本信息',
      icon: Icons.person_outline,
      children: items.map((item) => _buildInfoRow(item.label, item.value)).toList(),
    );
  }

  Widget _buildHealthCard(CareRecipient r) {
    final hasAllergies = r.allergies.isNotEmpty;
    final hasConditions = r.chronicConditions.isNotEmpty;
    if (!hasAllergies && !hasConditions && (r.medicalHistory == null || r.medicalHistory!.isEmpty)) {
      return const SizedBox.shrink();
    }
    return _buildCard(
      title: '健康信息',
      icon: Icons.favorite_outline,
      children: [
        if (hasAllergies) ...[
          _buildSectionLabel('过敏药物'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: r.allergies
                .map((a) => _buildChip(a, AppColors.coral.withValues(alpha: 0.1), AppColors.coral))
                .toList(),
          ),
        ],
        if (hasAllergies && hasConditions) const SizedBox(height: 16),
        if (hasConditions) ...[
          _buildSectionLabel('慢性病'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: r.chronicConditions
                .map((c) => _buildChip(c, AppColors.primary.withValues(alpha: 0.1), AppColors.primary))
                .toList(),
          ),
        ],
        if (r.medicalHistory != null && r.medicalHistory!.isNotEmpty) ...[
          if (hasAllergies || hasConditions) const SizedBox(height: 16),
          _buildSectionLabel('病史'),
          const SizedBox(height: 8),
          Text(r.medicalHistory!, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5)),
        ],
      ],
    );
  }

  Widget _buildHealthTrendsSection(Map<String, List<HealthRecord>> trends) {
    final bpList = trends['bloodPressure'] ?? [];
    final glucoseList = trends['bloodGlucose'] ?? [];
    final hasData = bpList.isNotEmpty || glucoseList.isNotEmpty;

    return _buildCard(
      title: '近期健康趋势',
      icon: Icons.show_chart,
      headerAction: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewToggle(),
          const SizedBox(width: 8),
          _buildQuickRecordButton(),
        ],
      ),
      children: [
        if (!hasData)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(Icons.timeline_rounded, size: 36, color: AppColors.textTertiary),
                  const SizedBox(height: 8),
                  Text('暂无健康记录', style: TextStyle(color: AppColors.textTertiary)),
                  const SizedBox(height: 16),
                  _buildQuickRecordButton(),
                ],
              ),
            ),
          )
        else if (_healthChartMode)
          _buildChartView(bpList, glucoseList)
        else
          Column(
            children: [
              if (bpList.isNotEmpty) ...[
                _buildBpTrendCard(bpList),
                if (glucoseList.isNotEmpty) const SizedBox(height: 16),
              ],
              if (glucoseList.isNotEmpty) _buildGlucoseTrendCard(glucoseList),
            ],
          ),
      ],
    );
  }

  Widget _buildViewToggle() {
    return GestureDetector(
      onTap: () => setState(() => _healthChartMode = !_healthChartMode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _healthChartMode ? Icons.view_list_rounded : Icons.show_chart_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              _healthChartMode ? '列表' : '图表',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartView(List<HealthRecord> bpList, List<HealthRecord> glucoseList) {
    return Column(
      children: [
        if (bpList.isNotEmpty) ...[
          _buildBpChart(bpList),
          if (glucoseList.isNotEmpty) const SizedBox(height: 20),
        ],
        if (glucoseList.isNotEmpty) _buildGlucoseChart(glucoseList),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBpChart(List<HealthRecord> records) {
    // 最多取最近7条，按时间正序排列
    final sorted = List<HealthRecord>.from(records)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt))
      ..removeRange(0, records.length > 7 ? records.length - 7 : 0);

    final sysSpots = <FlSpot>[];
    final diaSpots = <FlSpot>[];
    for (var i = 0; i < sorted.length; i++) {
      final r = sorted[i];
      if (r.systolic != null) sysSpots.add(FlSpot(i.toDouble(), r.systolic!.toDouble()));
      if (r.diastolic != null) diaSpots.add(FlSpot(i.toDouble(), r.diastolic!.toDouble()));
    }

    final allVals = [...sysSpots.map((s) => s.y), ...diaSpots.map((s) => s.y)];
    if (allVals.isEmpty) return const SizedBox.shrink();
    final minY = (allVals.reduce((a, b) => a < b ? a : b) - 20).clamp(40.0, 200.0).toDouble();
    final maxY = (allVals.reduce((a, b) => a > b ? a : b) + 20).clamp(80.0, 220.0).toDouble();
    final pointCount = sorted.length;
    final labelInterval = pointCount <= 5 ? 1.0 : 2.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, size: 16, color: AppColors.coral),
              const SizedBox(width: 6),
              const Text('血压趋势', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _chartLegend('收缩压', AppColors.coral),
              const SizedBox(width: 16),
              _chartLegend('舒张压', AppColors.primary),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 30,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: AppColors.borderLight,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: labelInterval,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= sorted.length || idx % labelInterval.toInt() != 0) {
                          return const SizedBox();
                        }
                        final d = sorted[idx].recordedAt;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${d.month}/${d.day}',
                            style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 30,
                      getTitlesWidget: (val, meta) => Text(
                        val.toInt().toString(),
                        style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (sorted.length - 1).toDouble().clamp(0, double.infinity),
                minY: minY,
                maxY: maxY,
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    // 正常范围线
                    HorizontalLine(y: 90, color: AppColors.success.withValues(alpha: 0.5), strokeWidth: 1, dashArray: [4, 4]),
                    HorizontalLine(y: 140, color: AppColors.success.withValues(alpha: 0.5), strokeWidth: 1, dashArray: [4, 4]),
                  ],
                ),
                lineBarsData: [
                  // 收缩压
                  LineChartBarData(
                    spots: sysSpots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.coral,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                        radius: 3.5,
                        color: AppColors.coral,
                        strokeWidth: 1.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.coral.withValues(alpha: 0.08),
                    ),
                  ),
                  // 舒张压
                  LineChartBarData(
                    spots: diaSpots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                        radius: 3.5,
                        color: AppColors.primary,
                        strokeWidth: 1.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => AppColors.textPrimary.withValues(alpha: 0.9),
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final label = spot.barIndex == 0 ? '收缩压' : '舒张压';
                        return LineTooltipItem(
                          '$label ${spot.y.toInt()}',
                          const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlucoseChart(List<HealthRecord> records) {
    // 最多取最近7条，按时间正序排列
    final sorted = List<HealthRecord>.from(records)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt))
      ..removeRange(0, records.length > 7 ? records.length - 7 : 0);

    final spots = <FlSpot>[];
    for (var i = 0; i < sorted.length; i++) {
      final r = sorted[i];
      if (r.glucoseValue != null) {
        // 截断显示值在 0~20 范围内，tooltip 显示真实值
        final displayY = r.glucoseValue!.clamp(0.0, 20.0);
        spots.add(FlSpot(i.toDouble(), displayY));
      }
    }

    if (spots.isEmpty) return const SizedBox.shrink();

    final pointCount = sorted.length;
    final labelInterval = pointCount <= 5 ? 1.0 : 2.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text('血糖趋势', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          _chartLegend('血糖值', AppColors.primary),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 4,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: AppColors.borderLight,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: labelInterval,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= sorted.length || idx % labelInterval.toInt() != 0) {
                          return const SizedBox();
                        }
                        final d = sorted[idx].recordedAt;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${d.month}/${d.day}',
                            style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 4,
                      getTitlesWidget: (val, meta) => Text(
                        val.toInt().toString(),
                        style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (sorted.length - 1).toDouble(),
                minY: 0,
                maxY: 20,
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(y: 6.1, color: AppColors.success.withValues(alpha: 0.5), strokeWidth: 1, dashArray: [4, 4]),
                    HorizontalLine(y: 3.9, color: AppColors.success.withValues(alpha: 0.5), strokeWidth: 1, dashArray: [4, 4]),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        // 用原始数据判断是否超范围
                        final originalVal = sorted[index].glucoseValue ?? 0;
                        final color = originalVal > 7.0 || originalVal < 3.9 ? AppColors.coral : AppColors.primary;
                        return FlDotCirclePainter(
                          radius: 3.5,
                          color: color,
                          strokeWidth: 1.5,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => AppColors.textPrimary.withValues(alpha: 0.9),
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final realVal = idx < sorted.length ? (sorted[idx].glucoseValue?.toStringAsFixed(1) ?? '-') : '-';
                        return LineTooltipItem(
                          '血糖 $realVal',
                          const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildBpTrendCard(List<HealthRecord> records) {
    final latest = records.isNotEmpty ? records.first : null;
    final avgS = records.isEmpty ? 0 : (records.map((r) => r.systolic ?? 0).reduce((a, b) => a + b) / records.length).round();
    final avgD = records.isEmpty ? 0 : (records.map((r) => r.diastolic ?? 0).reduce((a, b) => a + b) / records.length).round();
    final trend = records.length < 2 ? 0 : ((records[0].systolic ?? 0) > (records[1].systolic ?? 0) + 5 ? 1 : ((records[0].systolic ?? 0) < (records[1].systolic ?? 0) - 5 ? -1 : 0));
    final trendIcon = trend > 0 ? '📈' : (trend < 0 ? '📉' : '📊');
    final trendColor = trend > 0 ? AppColors.coral : (trend < 0 ? AppColors.success : AppColors.textSecondary);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, size: 16, color: AppColors.coral),
              const SizedBox(width: 6),
              const Text('血压', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          if (latest != null && latest.systolic != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${latest.systolic}/${latest.diastolic}',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: _bpColor(latest.systolic!, latest.diastolic!)),
                ),
                const SizedBox(width: 4),
                Text('mmHg', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const Spacer(),
                Text('$trendIcon ${_bpTrendLabel(trend)}', style: TextStyle(fontSize: 13, color: trendColor, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          ...records.take(3).map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text(_formatDateShort(r.recordedAt), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                Text(
                  '${r.systolic}/${r.diastolic}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _bpColor(r.systolic ?? 0, r.diastolic ?? 0)),
                ),
              ],
            ),
          )),
          const SizedBox(height: 8),
          Text('近7日均值 $avgS/$avgD', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildGlucoseTrendCard(List<HealthRecord> records) {
    final latest = records.isNotEmpty ? records.first : null;
    final avg = records.isEmpty ? 0.0 : (records.map((r) => r.glucoseValue ?? 0).reduce((a, b) => a + b) / records.length);
    final type = latest?.glucoseType ?? 'fasting';
    final trend = records.length < 2 ? 0 : ((records[0].glucoseValue ?? 0) > (records[1].glucoseValue ?? 0) + 0.5 ? 1 : ((records[0].glucoseValue ?? 0) < (records[1].glucoseValue ?? 0) - 0.5 ? -1 : 0));
    final trendIcon = trend > 0 ? '📈' : (trend < 0 ? '📉' : '📊');
    final trendColor = trend > 0 ? AppColors.warning : (trend < 0 ? AppColors.success : AppColors.textSecondary);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('血糖（${type == 'fasting' ? '空腹' : '餐后'}）', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          if (latest != null && latest.glucoseValue != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  latest.glucoseValue!.toStringAsFixed(1),
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: _glucoseColor(latest.glucoseValue!)),
                ),
                const SizedBox(width: 4),
                Text('mmol/L', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                Text(_glucoseStatus(latest.glucoseValue!), style: TextStyle(fontSize: 12, color: _glucoseColor(latest.glucoseValue!))),
                const Spacer(),
                Text('$trendIcon ${_glucoseTrendLabel(trend)}', style: TextStyle(fontSize: 13, color: trendColor, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          ...records.take(3).map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text(_formatDateShort(r.recordedAt), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                Text(
                  r.glucoseValue!.toStringAsFixed(1),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _glucoseColor(r.glucoseValue!)),
                ),
                const SizedBox(width: 4),
                Text(r.glucoseType == 'fasting' ? '空腹' : '餐后', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          )),
          const SizedBox(height: 8),
          Text('近7日均值 ${avg.toStringAsFixed(1)}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard(CareRecipient r) {
    if ((r.emergencyContact == null || r.emergencyContact!.isEmpty) &&
        (r.emergencyPhone == null || r.emergencyPhone!.isEmpty)) {
      return const SizedBox.shrink();
    }
    return _buildCard(
      title: '紧急联系人',
      icon: Icons.emergency_rounded,
      children: [
        if (r.emergencyContact != null && r.emergencyContact!.isNotEmpty)
          _buildInfoRow('联系人', r.emergencyContact!),
        if (r.emergencyPhone != null && r.emergencyPhone!.isNotEmpty)
          _buildInfoRow('联系电话', r.emergencyPhone!),
      ],
    );
  }

  Widget _buildHospitalCard(CareRecipient r) {
    final hasHospital = (r.hospital != null && r.hospital!.isNotEmpty);
    final hasDoctor = (r.doctorName != null && r.doctorName!.isNotEmpty);
    if (!hasHospital && !hasDoctor) return const SizedBox.shrink();
    return _buildCard(
      title: '就医信息',
      icon: Icons.local_hospital_rounded,
      children: [
        if (hasHospital) _buildInfoRow('就诊医院', r.hospital!),
        if (r.department != null && r.department!.isNotEmpty)
          _buildInfoRow('科室', r.department!),
        if (hasDoctor) _buildInfoRow('主治医生', r.doctorName!),
        if (r.doctorPhone != null && r.doctorPhone!.isNotEmpty)
          _buildInfoRow('医生电话', r.doctorPhone!),
      ],
    );
  }

  Widget _buildMedicationSection(AsyncValue<List<Medication>> medicationsAsync) {
    return _buildCard(
      title: '药品管理',
      icon: Icons.medication_rounded,
      children: [
        medicationsAsync.when(
          data: (meds) {
            final active = meds.where((m) => m.isActive).toList();
            if (active.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.medication_rounded, size: 36, color: AppColors.textTertiary),
                      const SizedBox(height: 8),
                      Text('暂无药品，点击下方按钮添加', style: TextStyle(color: AppColors.textTertiary)),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: active.map((med) => _buildMedicationRow(med)).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('加载失败: $e', style: TextStyle(color: AppColors.error))),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationRow(Medication med) {
    return InkWell(
      onTap: () => context.push('/medication/${med.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.medication, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    med.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (med.times.isNotEmpty)
                    Text(med.times.join(' / '), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, Widget? headerAction, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: const Offset(0, 2)),
          BoxShadow(color: AppColors.shadowSoft2, blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const Spacer(),
              if (headerAction != null) headerAction,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary));
  }

  Widget _buildChip(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w500)),
    );
  }

  String _genderLabel(String gender) {
    switch (gender) {
      case 'male': return '男';
      case 'female': return '女';
      default: return gender;
    }
  }

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _formatDateShort(DateTime d) => '${d.month}/${d.day}';

  Color _bpColor(int sys, int dia) {
    if (sys >= 140 || dia >= 90) return AppColors.coral;
    if (sys < 90 || dia < 60) return AppColors.warning;
    return AppColors.success;
  }

  Color _glucoseColor(double val) {
    if (val > 7.0 || val < 3.9) return AppColors.coral;
    if (val > 6.1) return AppColors.warning;
    return AppColors.success;
  }

  String _glucoseStatus(double val) {
    if (val > 7.0) return '偏高';
    if (val < 3.9) return '偏低';
    return '正常';
  }

  String _bpTrendLabel(int trend) => trend > 0 ? '轻微升高' : (trend < 0 ? '轻微下降' : '稳定');
  String _glucoseTrendLabel(int trend) => trend > 0 ? '轻微升高' : (trend < 0 ? '轻微下降' : '稳定');

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"${widget.recipient.name}"吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(AppTexts.cancel)),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final dio = ref.read(dioProvider);
              final familyId = ref.read(currentFamilyProvider)?.id ?? '';
              await dio.delete('/care-recipients/${widget.recipient.id}', queryParameters: {'familyId': familyId});
              ref.invalidate(careRecipientsProvider);
              ref.invalidate(currentFamilyProvider);
              if (context.mounted) context.pop();
            },
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickRecordButton() {
    return GestureDetector(
      onTap: _showHealthRecordSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              '记一笔',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHealthRecordSheet() {
    HealthMetricType? selectedMetric;
    final bpSysController = TextEditingController();
    final bpDiaController = TextEditingController();
    final glucoseController = TextEditingController();
    String glucoseType = 'fasting';
    final weightController = TextEditingController();
    String weightUnit = 'kg';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: EdgeInsets.fromLTRB(
              24, 24, 24,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.grey200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text(
                        '记录健康数据',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.recipient.name,
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),

                  // 指标选择
                  const Text(
                    '选择指标',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: HealthMetricType.values.map((metric) {
                      final isSelected = metric == selectedMetric;
                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedMetric = metric),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(metric.emoji, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                metric.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // 正常范围提示
                  if (selectedMetric != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            '参考范围：${selectedMetric!.normalRange}',
                            style: TextStyle(fontSize: 12, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // 健康指标输入
                  if (selectedMetric != null)
                    _buildHealthInputSheet(
                      selectedMetric!,
                      bpSysController,
                      bpDiaController,
                      glucoseController,
                      glucoseType,
                      weightController,
                      weightUnit,
                      (type) => setSheetState(() => glucoseType = type),
                      (unit) => setSheetState(() => weightUnit = unit),
                    ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedMetric == null) return;

                        bool isValid = false;
                        if (selectedMetric == HealthMetricType.bloodPressure) {
                          isValid = bpSysController.text.isNotEmpty && bpDiaController.text.isNotEmpty;
                        } else if (selectedMetric == HealthMetricType.bloodGlucose) {
                          isValid = glucoseController.text.isNotEmpty;
                        } else {
                          isValid = weightController.text.isNotEmpty;
                        }
                        if (!isValid) return;

                        Navigator.pop(ctx);

                        try {
                          final dio = ref.read(dioProvider);
                          final value = <String, dynamic>{};
                          if (selectedMetric == HealthMetricType.bloodPressure) {
                            value['systolic'] = int.tryParse(bpSysController.text) ?? 0;
                            value['diastolic'] = int.tryParse(bpDiaController.text) ?? 0;
                          } else if (selectedMetric == HealthMetricType.bloodGlucose) {
                            value['value'] = double.tryParse(glucoseController.text) ?? 0.0;
                            value['type'] = glucoseType;
                          } else {
                            value['value'] = double.tryParse(weightController.text) ?? 0.0;
                            value['unit'] = weightUnit;
                          }

                          await dio.post('/health-records', data: {
                            'recipientId': widget.recipient.id,
                            'recordType': selectedMetric!.recordType,
                            'value': value,
                          });

                          await Future.delayed(Duration.zero);
                          ref.invalidate(healthTrendsProvider(widget.recipient.id));
                          // 同时刷新时间线
                          final familyId = ref.read(currentFamilyProvider)?.id;
                          if (familyId != null) {
                            ref.read(timelineProvider(
                              TimelineQuery(familyId: familyId, recipientId: widget.recipient.id),
                            ).notifier).refresh();
                          }

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('已记录健康数据'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        } catch (err) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('保存失败: $err'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      child: const Text(
                        '保存记录',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHealthInputSheet(
    HealthMetricType metric,
    TextEditingController bpSys,
    TextEditingController bpDia,
    TextEditingController glucose,
    String glucoseType,
    TextEditingController weight,
    String weightUnit,
    void Function(String) setGlucoseType,
    void Function(String) setWeightUnit,
  ) {
    switch (metric) {
      case HealthMetricType.bloodPressure:
        return Row(
          children: [
            Expanded(child: _buildNumberFieldSheet(controller: bpSys, label: '收缩压', hint: '120', unit: 'mmHg', color: AppColors.primary)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('/', style: TextStyle(fontSize: 24, color: AppColors.textSecondary)),
            ),
            Expanded(child: _buildNumberFieldSheet(controller: bpDia, label: '舒张压', hint: '80', unit: 'mmHg', color: AppColors.primary)),
          ],
        );

      case HealthMetricType.bloodGlucose:
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildNumberFieldSheet(controller: glucose, label: '血糖值', hint: '5.6', unit: 'mmol/L', color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildSubTypeChipSheet('空腹', glucoseType == 'fasting', () => setGlucoseType('fasting'), AppColors.primary),
                const SizedBox(width: 8),
                _buildSubTypeChipSheet('餐后', glucoseType == 'postprandial', () => setGlucoseType('postprandial'), AppColors.primary),
              ],
            ),
          ],
        );

      case HealthMetricType.weight:
        return Row(
          children: [
            Expanded(child: _buildNumberFieldSheet(controller: weight, label: '体重', hint: '60', unit: '', color: AppColors.primary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButton<String>(
                value: weightUnit,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: 'kg', child: Text('kg', style: TextStyle(color: AppColors.textPrimary))),
                  DropdownMenuItem(value: '斤', child: Text('斤', style: TextStyle(color: AppColors.textPrimary))),
                ],
                onChanged: (v) { if (v != null) setWeightUnit(v); },
              ),
            ),
          ],
        );
    }
  }

  Widget _buildNumberFieldSheet({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textTertiary),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (unit.isNotEmpty)
                Text(unit, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubTypeChipSheet(String label, bool isSelected, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  _InfoItem(this.label, this.value);
}
