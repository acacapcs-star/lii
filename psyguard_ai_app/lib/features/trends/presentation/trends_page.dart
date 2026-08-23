import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/lii_bottom_nav.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/network/ai_chat_repository.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/database_provider.dart';
import '../../../core/widgets/geometric_stress_indicator.dart';
import '../../../core/widgets/brand_loading_indicator.dart';
import '../../../l10n/app_strings.dart';
import '../../../core/ers/group_norms.dart';

class TrendBundle {
  TrendBundle({
    required this.checkins,
    required this.sleepLogs,
    required this.risks,
  });

  final List<DailyCheckin> checkins;
  final List<SleepLog> sleepLogs;
  final List<RiskSnapshot> risks;
}

// 拉桿：3、6、9…30，每 3 天一格
final trendRangeProvider = StateProvider<int>((ref) => 30);

/// 對比模式：個人（跟自己比）或團體（跟同齡人比）
enum TrendCompareMode { personal, group }

final trendCompareModeProvider =
    StateProvider<TrendCompareMode>((ref) => TrendCompareMode.personal);

/// 團體基準線（跟著年齡層走）。個人模式用不到，回傳 null。
final trendGroupNormProvider = FutureProvider<GroupNorm?>((ref) async {
  if (ref.watch(trendCompareModeProvider) != TrendCompareMode.group) {
    return null;
  }
  final band = await AgeBandStore.get() ?? AgeBand.age16to18;
  final norm = await GroupNorms.fetch(band);
  // 樣本數不足 15 人時不顯示同齡比較（統計效度 + 隱私）
  if (!GroupNorms.hasEnoughSample(norm)) return null;
  return norm;
});

/// 三張趨勢卡各自要不要顯示：mood / sleep / risk
class TrendVisible {
  final bool mood;
  final bool sleep;
  final bool risk;
  const TrendVisible({this.mood = true, this.sleep = true, this.risk = true});

  TrendVisible copyWith({bool? mood, bool? sleep, bool? risk}) => TrendVisible(
        mood: mood ?? this.mood,
        sleep: sleep ?? this.sleep,
        risk: risk ?? this.risk,
      );
}

final trendVisibleProvider =
    StateProvider<TrendVisible>((ref) => const TrendVisible());

final trendBundleProvider = FutureProvider<TrendBundle>((ref) async {
  final range = ref.watch(trendRangeProvider);
  final db = ref.read(appDatabaseProvider);
  final since = DateTime.now().subtract(Duration(days: range - 1));

  final checkins = await db.getCheckinsSince(since);
  final sleepLogs = await db.getSleepLogsSince(since);
  final allRisks = await db.select(db.riskSnapshots).get();
  final risks = allRisks.where((item) => !item.date.isBefore(since)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  return TrendBundle(checkins: checkins, sleepLogs: sleepLogs, risks: risks);
});

class TrendsPage extends ConsumerWidget {
  const TrendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(trendRangeProvider);
    final visible = ref.watch(trendVisibleProvider);
    final compareMode = ref.watch(trendCompareModeProvider);
    final groupNorm = ref.watch(trendGroupNormProvider).valueOrNull;
    final data = ref.watch(trendBundleProvider);
    final theme = Theme.of(context);
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));

    return Scaffold(
      bottomNavigationBar: LiiBottomNav(
        isZh: Localizations.localeOf(context).languageCode == 'zh',
        current: LiiTab.records,
      ),
      backgroundColor: LumiTheme.background,
      appBar: AppBar(
        title: Text(copy.trendsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: copy.analysisHistory,
            onPressed: () => context.push('/ai_history'),
          ),
          IconButton(
            icon: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF6B4C9A),
            ),
            tooltip: copy.aiTrendAnalysis,
            onPressed: () => _showAiAnalysisDialog(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 天數拉桿 + 個人/團體切換
          _rangeAndCompareControls(context, ref, copy),
          if (false) // 舊的範圍按鈕停用（保留避免大改版面）
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final days in [7, 14, 30, 90])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        key: ValueKey('range_$days'),
                        label: Text(
                          days == 90 ? copy.threeMonths : copy.days(days),
                        ),
                        selected: range == days,
                        onSelected: (selected) {
                          if (selected) {
                            ref.read(trendRangeProvider.notifier).state = days;
                          }
                        },
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: range == days
                              ? Colors.white
                              : LumiTheme.textSecondary,
                          fontWeight: range == days
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        backgroundColor: LumiTheme.surface,
                        selectedColor: LumiTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: range == days
                                ? Colors.transparent
                                : Colors.black.withValues(alpha: 0.1),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: data.when(
              data: (bundle) {
                try {
                  // 取得最新風險分數用於圖標變色
                  final latestRiskScore = bundle.risks.isNotEmpty
                      ? bundle.risks.last.riskScore
                      : 20;
                  final riskIconColor = LumiTheme.riskColor(
                    latestRiskScore,
                  );

                  if (bundle.checkins.isEmpty &&
                      bundle.sleepLogs.isEmpty &&
                      bundle.risks.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Icon(
                                Icons.timeline_rounded,
                                size: 48,
                                color: LumiTheme.primary.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              copy.noTrendData,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: LumiTheme.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              copy.noTrendDataBody,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: LumiTheme.textSecondary,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => context.push('/checkin'),
                                    child: Text(copy.doCheckin),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => context.push('/sleep'),
                                    child: Text(copy.recordSleep),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      // 案號浮水印
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: Transform.rotate(
                              angle: -0.3,
                              child: Text(
                                copy.emergencyCase,
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black.withValues(alpha: 0.03),
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        children: [
                          const SizedBox(height: 20),
                          RecordShortcuts(isZh: copy.isZhTw),
                          const SizedBox(height: 20),
                          _seriesToggles(context, ref, copy),
                          const SizedBox(height: 4),
                          if (visible.mood)
                          _chartCard(
                            context,
                            title: copy.moodPercentage,
                            icon: Icons.sentiment_satisfied_alt_rounded,
                            color: const Color(0xFF667EEA),
                            spots: _toSpots(
                              bundle.checkins
                                  .map((e) => e.moodScore.toDouble())
                                  .toList(),
                            ),
                            baseline: compareMode == TrendCompareMode.group
                                ? groupNorm?.mood
                                : _avg(bundle.checkins
                                    .map((e) => e.moodScore.toDouble())),
                            baselineIsGroup:
                                compareMode == TrendCompareMode.group,
                            copy: copy,
                            minY: 0,
                            maxY: 100,
                            formatYLabel: _formatPercentAxis,
                          ),
                          if (visible.mood) const SizedBox(height: 16),
                          if (visible.sleep)
                          _chartCard(
                            context,
                            title: copy.sleepHoursLabel,
                            icon: Icons.bedtime_rounded,
                            color: const Color(0xFFA18CD1),
                            spots: _toSpots(
                              bundle.sleepLogs
                                  .map((e) => e.sleepHours)
                                  .toList(),
                            ),
                            baseline: compareMode == TrendCompareMode.group
                                ? groupNorm?.sleepHours
                                : _avg(bundle.sleepLogs
                                    .map((e) => e.sleepHours)),
                            baselineIsGroup:
                                compareMode == TrendCompareMode.group,
                            copy: copy,
                            minY: 0,
                            maxY: 12,
                          ),
                          if (visible.sleep) const SizedBox(height: 16),
                          // 風險分數卡 + 幾何壓力指示器
                          if (visible.risk)
                          _chartCard(
                            context,
                            title: copy.riskScore,
                            icon: Icons.shield_rounded,
                            color: riskIconColor,
                            spots: _toSpots(
                              bundle.risks
                                  .map((e) => e.riskScore.toDouble())
                                  .toList(),
                            ),
                            baseline: compareMode == TrendCompareMode.group
                                ? groupNorm?.riskScore
                                : _avg(bundle.risks
                                    .map((e) => e.riskScore.toDouble())),
                            baselineIsGroup:
                                compareMode == TrendCompareMode.group,
                            copy: copy,
                            minY: 0,
                            maxY: 100,
                            trailing: GeometricStressIndicator(
                              riskScore: latestRiskScore,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                } catch (e) {
                  return Center(
                    child: Text(
                      copy.chartLoadError(e),
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                }
              },
              loading: () => Center(
                child: BrandLoadingIndicator(message: copy.loadingTrendData),
              ),
              error: (error, stack) => Center(
                child: Text(
                  copy.loadFailed(error),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 判斷某個值是否超過基準線 ±10%（對齊摘要「flagging shifts beyond ±10%」）
  bool _isBeyond10(double value, double? baseline) {
    if (baseline == null || baseline == 0) return false;
    final ratio = (value - baseline) / baseline;
    return ratio.abs() > 0.10;
  }

  Widget _chartCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<FlSpot> spots,
    required double minY,
    required double maxY,
    double? baseline,
    bool baselineIsGroup = false,
    AppStrings? copy,
    String Function(double value)? formatYLabel,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: LumiTheme.softCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: LumiTheme.textPrimary,
                ),
              ),
              if (trailing != null) ...[const Spacer(), trailing],
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Builder(builder: (context) {
              // 資料點多的時候給每個點固定寬度，超出畫面就能左右滑
              final count = spots.length;
              final needScroll = count > 14;
              final chartWidth = needScroll
                  ? count * 26.0
                  : MediaQuery.of(context).size.width - 72;
              final chart = SizedBox(
                width: chartWidth,
                child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.08),
                    strokeWidth: 1,
                  ),
                ),
                lineTouchData: const LineTouchData(enabled: true),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(
                        (formatYLabel ?? _formatDefaultAxis)(value),
                        style: TextStyle(
                          fontSize: 11,
                          color: LumiTheme.textLight,
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: baseline == null
                    ? const ExtraLinesData()
                    : ExtraLinesData(horizontalLines: [
                        HorizontalLine(
                          y: baseline,
                          color: baselineIsGroup
                              ? const Color(0xFFFF9800)
                              : color.withValues(alpha: 0.55),
                          strokeWidth: 2,
                          dashArray: [6, 4],
                        ),
                      ]),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots.isEmpty ? const [FlSpot(0, 0)] : spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: color,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        // 📊 超過基準線 ±10% 的點 -> 橘色放大（對齊摘要 ±10% 波動）
                        final beyond = _isBeyond10(spot.y, baseline);
                        return FlDotCirclePainter(
                          radius: beyond ? 6 : 4,
                          color: beyond
                              ? const Color(0xFFFF9800)
                              : Colors.white,
                          strokeWidth: 2.5,
                          strokeColor: beyond
                              ? const Color(0xFFEF6C00)
                              : color,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
                ),
              );
              return needScroll
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: chart,
                    )
                  : chart;
            }),
          ),
          if (baseline != null && copy != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 2,
                    color: baselineIsGroup
                        ? const Color(0xFFFF9800)
                        : color.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      baselineIsGroup
                          ? (copy.isZhTw
                              ? '同齡人參考線（參與者尚不足，數據僅供參考）'
                              : 'Peer reference (small sample — for reference only)')
                          : (copy.isZhTw ? '你的期間平均' : 'Your period average'),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9AA5B1)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// ☑️ 選要看哪些線
  Widget _seriesToggles(BuildContext context, WidgetRef ref, AppStrings copy) {
    final v = ref.watch(trendVisibleProvider);
    final isZh = copy.isZhTw;

    Widget chip(String label, Color color, bool on, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? color.withValues(alpha: 0.14) : Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: on ? color : Colors.grey.withValues(alpha: 0.3),
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 15,
                color: on ? color : Colors.grey,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: on ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final notifier = ref.read(trendVisibleProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          chip(isZh ? '心情' : 'Mood', const Color(0xFF667EEA), v.mood,
              () => notifier.state = v.copyWith(mood: !v.mood)),
          chip(isZh ? '睡眠' : 'Sleep', const Color(0xFFA18CD1), v.sleep,
              () => notifier.state = v.copyWith(sleep: !v.sleep)),
          chip(isZh ? '風險' : 'Risk', const Color(0xFFEF5350), v.risk,
              () => notifier.state = v.copyWith(risk: !v.risk)),
        ],
      ),
    );
  }

  /// 天數拉桿 + 個人/團體切換
  Widget _rangeAndCompareControls(
      BuildContext context, WidgetRef ref, AppStrings copy) {
    final range = ref.watch(trendRangeProvider);
    final mode = ref.watch(trendCompareModeProvider);
    final isZh = copy.isZhTw;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 個人 / 團體
          Container(
            decoration: BoxDecoration(
              color: LumiTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _modeTab(
                  label: isZh ? '個人' : 'Personal',
                  sub: isZh ? '跟自己比' : 'vs yourself',
                  on: mode == TrendCompareMode.personal,
                  onTap: () => ref.read(trendCompareModeProvider.notifier).state =
                      TrendCompareMode.personal,
                ),
                _modeTab(
                  label: isZh ? '團體' : 'Group',
                  sub: isZh ? '跟同齡人比' : 'vs peers',
                  on: mode == TrendCompareMode.group,
                  onTap: () => ref.read(trendCompareModeProvider.notifier).state =
                      TrendCompareMode.group,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // 天數拉桿
          Row(
            children: [
              Text(
                isZh ? '近 $range 天' : 'Last $range days',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
              Expanded(
                child: Slider(
                  value: range.toDouble(),
                  min: 3,
                  max: 30,
                  divisions: 9, // 3,6,9,...,30
                  label: '$range',
                  activeColor: LumiTheme.primary,
                  onChanged: (v) => ref.read(trendRangeProvider.notifier).state =
                      (v / 3).round() * 3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeTab({
    required String label,
    required String sub,
    required bool on,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: on ? LumiTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: on ? Colors.white : LumiTheme.textSecondary,
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 11,
                  color: on
                      ? Colors.white.withValues(alpha: 0.85)
                      : LumiTheme.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 平均值，空的話回 null（個人基準線用）
  double? _avg(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return null;
    return list.reduce((a, b) => a + b) / list.length;
  }

  List<FlSpot> _toSpots(List<double> values) {
    if (values.isEmpty) return const [FlSpot(0, 0)];
    return values
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList();
  }

  String _formatDefaultAxis(double value) => value.toInt().toString();

  String _formatPercentAxis(double value) => '${value.toInt()}%';

  Future<void> _showAiAnalysisDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final copy = AppStrings.of(ref.read(appLanguageControllerProvider));
    final range = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(copy.chooseAiRange),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 30),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Text(copy.lastMonth, style: const TextStyle(fontSize: 16)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 90),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Text(
              copy.lastThreeMonths,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 365),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Text(copy.lastYear, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (range == null) return;
    if (!context.mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final db = ref.read(appDatabaseProvider);
      final since = DateTime.now().subtract(Duration(days: range));

      // 1. Fetch Data
      final checkins = await db.getCheckinsSince(since);
      final sleepLogs = await db.getSleepLogsSince(since);
      final allRisks = await db.select(db.riskSnapshots).get();
      final risks = allRisks
          .where((item) => !item.date.isBefore(since))
          .toList();

      // 2. Format Data for AI
      final moodSummary = checkins
          .map(
            (e) => copy.isZhTw
                ? '${e.date.toString().substring(0, 10)}:心情${e.moodScore}%'
                : '${e.date.toString().substring(0, 10)}: mood ${e.moodScore}%',
          )
          .join('\n');
      final sleepSummary = sleepLogs
          .map(
            (e) => copy.isZhTw
                ? '${e.date.toString().substring(0, 10)}:睡眠${e.sleepHours}hr'
                : '${e.date.toString().substring(0, 10)}: sleep ${e.sleepHours}hr',
          )
          .join('\n');
      final riskSummary = risks
          .map(
            (e) => copy.isZhTw
                ? '${e.date.toString().substring(0, 10)}:風險${e.riskScore}'
                : '${e.date.toString().substring(0, 10)}: risk ${e.riskScore}',
          )
          .join('\n');

      final inputData = copy.isZhTw
          ? '''
時間範圍：近 $range 天
-- 心情紀錄 --
$moodSummary
-- 睡眠紀錄 --
$sleepSummary
-- 風險分數 --
$riskSummary
'''
          : '''
Time range: last $range days
-- Mood Records --
$moodSummary
-- Sleep Records --
$sleepSummary
-- Risk Scores --
$riskSummary
''';

      // 3. Call AI
      final aiRepo = ref.read(aiChatRepositoryProvider);
      final report = await aiRepo.generateReport(analysisData: inputData);

      // 4. Save to DB
      await db.saveAiReport(rangeDays: range, content: report);

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading

      // 5. Navigate to Report Page (Top Level Route)
      context.push('/ai_report', extra: report);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.analysisFailed(e))));
    }
  }
}


class _RecordShortcuts extends StatelessWidget {
  const _RecordShortcuts({required this.isZh});

  final bool isZh;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        isZh ? '本週人設' : 'Weekly Persona',
        isZh ? '這週的樣子' : 'How this week looked',
        Icons.auto_awesome_mosaic_rounded,
        const Color(0xFF41B6C8),
        '/weekly-persona',
      ),
      (
        isZh ? '月曆總覽' : 'Calendar',
        isZh ? '依週彙整重要事項' : 'Weekly view of what matters',
        Icons.calendar_month_rounded,
        const Color(0xFF417CC8),
        '/calendar-overview',
      ),
      (
        isZh ? '日記時間軸' : 'Diary timeline',
        isZh ? '寫過的每一天' : 'Every day you wrote',
        Icons.timeline_rounded,
        const Color(0xFF4143C8),
        '/checkin/history',
      ),
    ];

    return Row(
      children: [
        for (final it in items) ...[
          Expanded(
            child: _ShortcutCard(
              title: it.$1,
              subtitle: it.$2,
              icon: it.$3,
              color: it.$4,
              route: it.$5,
            ),
          ),
          if (it != items.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(color);
    final onCard = hsl.withSaturation(1.0).withLightness(0.22).toColor();
    final onCardSoft = hsl.withSaturation(0.85).withLightness(0.36).toColor();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        splashColor: color.withValues(alpha: 0.3),
        onTap: () => context.push(route),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color.alphaBlend(color.withValues(alpha: 0.14), Colors.white),
                Color.alphaBlend(color.withValues(alpha: 0.38), Colors.white),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.40), width: 3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(height: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: onCard),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(fontSize: 9.5, color: onCardSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
// 貼到 trends_page.dart 檔案最後面（最外層，不要放在任何 class 裡面）

class RecordShortcuts extends StatelessWidget {
  const RecordShortcuts({super.key, required this.isZh});

  final bool isZh;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, IconData, Color, String)>[
      (
        isZh ? '本週人設' : 'Weekly Persona',
        isZh ? '這週的樣子' : 'How this week looked',
        Icons.auto_awesome_mosaic_rounded,
        const Color(0xFF41B6C8),
        '/weekly-persona',
      ),
      (
        isZh ? '年度總覽' : 'Year Overview',
        isZh ? '一個月一個月看' : 'Month by month',
        Icons.calendar_month_rounded,
        const Color(0xFF417CC8),
        '/calendar-overview',
      ),
      (
        isZh ? '日記時間軸' : 'Diary timeline',
        isZh ? '寫過的每一天' : 'Every day you wrote',
        Icons.timeline_rounded,
        const Color(0xFF4143C8),
        '/checkin/history',
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: _ShortcutCard(
              title: items[i].$1,
              subtitle: items[i].$2,
              icon: items[i].$3,
              color: items[i].$4,
              route: items[i].$5,
            ),
          ),
          if (i != items.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}
