import 'package:flutter/foundation.dart';
import 'note_page.dart';
import '../../../core/ers/speech_metrics.dart';
import '../../../core/security/secret_swipe_shell.dart';
import 'package:flutter/material.dart';
import '../../../core/analytics/usage_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/risk_engine/risk_models.dart';
import '../../../core/risk_engine/risk_provider.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../core/storage/database_provider.dart';
import '../../home/presentation/home_page.dart'
    show homeDashboardProvider;
import '../../../l10n/app_strings.dart';
import '../../ers/ers_engine.dart';
import '../../ers/ers_models.dart';
import '../../ers/ers_percentile_widget.dart';

class CheckinPage extends ConsumerStatefulWidget {
  const CheckinPage({super.key});

  @override
  ConsumerState<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends ConsumerState<CheckinPage> {
  double _mood = 50;
  double _stress = 50;
  double _energy = 50;
  final TextEditingController _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final copy = AppStrings.of(ref.read(appLanguageControllerProvider));
    if (_noteController.text.length > 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.noteTooLong)));
      return;
    }
    setState(() => _saving = true);

    try {
      final now = DateTime.now();
      final mood = _mood.round();
      final stress = _stress.round();
      final energy = _energy.round();

      await ref
          .read(appDatabaseProvider)
          .upsertDailyCheckin(
            date: now,
            mood: mood,
            stress: stress,
            energy: energy,
            note: _noteController.text.isNotEmpty ? _noteController.text : null,
          );

      final risk = await ref
          .read(riskEvaluationServiceProvider)
          .evaluateAndPersistCheckin(
            date: now,
            mood: mood,
            stress: stress,
            energy: energy,
          );

      if (!mounted) return;
      setState(() => _saving = false);

      // ERS分析
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      final ersEngine = ERSEngine();
      // 讀取真實睡眠數據（行為串流）
      final db = ref.read(appDatabaseProvider);
      final yesterday = now.subtract(const Duration(days: 1));
      final sleepLogs = await db.getSleepLogsSince(yesterday);
      // 沒有睡眠紀錄時，用中性值（不冤枉成高風險）；真正風險交給心情/壓力/能量反映
      final realSleepHours = sleepLogs.isNotEmpty
          ? sleepLogs.last.sleepHours
          : 7.5;

      // 🎤 語言串流：優先用真實語音特徵（7 天內錄過音才算數），
      //    沒有的話才退回用壓力推算，這樣沒用過語音的人也不會壞掉。
      final voice = await SpeechMetricsStore.latest();
      final inferredSpeechRate = voice?.speechRate ??
          (stress > 70 ? 130.0 : stress > 50 ? 200.0 : 300.0);
      final inferredNegRatio =
          voice?.negativeWordRatio ?? (stress / 100.0 * 0.8);
      final inferredPauseFreq = voice?.pauseFrequency ??
          (stress > 70 ? 8.0 : stress > 50 ? 5.0 : 2.0);
      final realStreak = await UsageTracker.streakDays();
      final realConsistency = await UsageTracker.consistency7();
      final ersResult = ersEngine.calculate(
        ERSInput(
          speechRate: inferredSpeechRate,
          negativeWordRatio: inferredNegRatio,
          pauseFrequency: inferredPauseFreq,
          moodScore: mood.toDouble(),
          stressScore: stress.toDouble(),
          energyScore: energy.toDouble(),
          sleepDuration: realSleepHours,
          appUsageStreak: realStreak.toDouble(),
          checkInConsistency: realConsistency,
        ),
        const PersonalBaseline(),
        hasVoice: voice != null,
      );
      final prefs = await SharedPreferences.getInstance();
      // 多天平滑：用近 3 次 ERS 平均，避免單日暴衝誤觸警報
      final recent = prefs.getStringList('ers_recent') ?? [];
      recent.add(ersResult.adjustedERS.toStringAsFixed(2));
      while (recent.length > 3) {
        recent.removeAt(0);
      }
      await prefs.setStringList('ers_recent', recent);
      // DEMO_SKIP_SMOOTHING 設定頁 Demo 區的開關，只在 debug 生效。
      // 平常一定走平均 —— 不讓任何人因為單日狀態差就被丟進紅色警報。
      final skipSmoothing =
          kDebugMode && (prefs.getBool('demo_skip_ers_smoothing') ?? false);
      final smoothed = skipSmoothing
          ? ersResult.adjustedERS
          : recent
                  .map((e) => double.tryParse(e) ?? 0)
                  .fold<double>(0, (p, e) => p + e) /
              recent.length;
      final trueLevel = smoothed >= 70
          ? 'red'
          : smoothed >= 45
              ? 'yellow'
              : 'green';
      // ALERTS_RED_ENABLED 使用者可以在設定頁關掉紅色等級。預設是開的。
      // 關掉時只壓「給使用者看的等級」—— 真實等級照存 last_ers_level_true，
      // 系統不會假裝那天沒發生過。
      final redEnabled = prefs.getBool('alerts_red_enabled') ?? true;
      final smoothedLevel =
          (!redEnabled && trueLevel == 'red') ? 'yellow' : trueLevel;
      await prefs.setString('last_ers_level_true', trueLevel);
      await prefs.setDouble('last_ers_score', smoothed);
      await prefs.setString('last_ers_level', smoothedLevel);
      if (!mounted) return;
      // HOME_INVALIDATE 存完就叫首頁重抓，
      // 不然表情和顏色會停在舊的，要滑掉重開才會更正。
      ref.invalidate(homeDashboardProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(copy.savedRisk(smoothedLevel == 'red'
              ? 'HIGH'
              : smoothedLevel == 'yellow'
                  ? 'MEDIUM'
                  : 'LOW')),
        ),
      );
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(copy.todayMentalStateAnalysis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ERSPercentileWidget(ersResult: ersResult, ageGroup: copy.isZhTw ? '高中' : 'high school'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if ((risk.riskLevel == RiskLevel.high ||
                          ersResult.riskLevel == 'red') &&
                      redEnabled) {
                    context.go('/safety');
                  } else {
                    context.go('/home');
                  }
                },
                child: Text(ersResult.riskLevel == 'red' && redEnabled ? (copy.isZhTw ? '⚠️ 前往求助資源' : '⚠️ Get help resources') : (copy.isZhTw ? '了解了' : 'Got it')),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.saveFailed(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    return Scaffold(
      backgroundColor: LumiTheme.background,
      appBar: AppBar(
        title: Text(copy.checkinTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            color: LumiTheme.textPrimary,
            onPressed: () => context.push('/checkin/history'),
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _buildSliderSection(
            title: copy.mood,
            value: _mood,
            icon: _moodEmoji(_mood.round()),
            color: const Color(0xFF4A90D9),
            minAssistiveLabel: copy.veryBad,
            maxAssistiveLabel: copy.veryGood,
            onChanged: (v) => setState(() => _mood = v),
          ),
          const SizedBox(height: 16),
          _buildSliderSection(
            title: copy.stress,
            value: 100 - _stress,
            icon: _stressEmoji(_stress.round()),
            color: const Color(0xFF9B59B6),
            minAssistiveLabel: copy.veryBad,
            maxAssistiveLabel: copy.veryGood,
            onChanged: (v) => setState(() => _stress = 100 - v),
          ),
          const SizedBox(height: 16),
          _buildSliderSection(
            title: copy.energy,
            value: _energy,
            icon: _energyEmoji(_energy.round()),
            color: const Color(0xFF27AE60),
            minAssistiveLabel: copy.veryBad,
            maxAssistiveLabel: copy.veryGood,
            onChanged: (v) => setState(() => _energy = v),
          ),
          const SizedBox(height: 24),
          // Note section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: LumiTheme.softCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      color: LumiTheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      copy.todayNote,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: LumiTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SecretSwipeShell(
                          publicPage: NotePage(),
                          secretPage: NotePage(secret: true),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF0ABFBC).withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        const Text('📝', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Open Today Diary',
                                style: TextStyle(
                                  fontSize: 14, 
                                  fontWeight: FontWeight.bold, 
                                  color: Color(0xFF2C5282),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Bullet, todo, and 15-level priority tags',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF0ABFBC)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Save button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(copy.completeCheckin),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSection({
    required String title,
    required double value,
    required IconData icon,
    required Color color,
    String? minAssistiveLabel,
    String? maxAssistiveLabel,
    required ValueChanged<double> onChanged,
  }) {
    final percent = value.round().clamp(0, 100);
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    final moodLabel = title == copy.mood
        ? _moodDescriptor(percent, copy)
        : title == copy.stress
            ? _stressDescriptor(100 - percent, copy)
            : title == copy.energy
                ? _energyDescriptor(percent, copy)
                : null;

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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: LumiTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$percent%',
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (moodLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      moodLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: LumiTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.15),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.1),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(value: value, min: 0, max: 100, onChanged: onChanged),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildEndpointLabel(
                  score: '0%',
                  assistiveLabel: minAssistiveLabel,
                  alignEnd: false,
                ),
                _buildEndpointLabel(
                  score: '100%',
                  assistiveLabel: maxAssistiveLabel,
                  alignEnd: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndpointLabel({
    required String score,
    String? assistiveLabel,
    required bool alignEnd,
  }) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          score,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: LumiTheme.textSecondary,
          ),
        ),
        if (assistiveLabel != null)
          Text(
            assistiveLabel,
            style: const TextStyle(
              fontSize: 10,
              color: LumiTheme.textLight,
            ),
          ),
      ],
    );
  }

  String _moodDescriptor(int value, AppStrings copy) {
    if (value <= 20) return copy.veryBad;
    if (value <= 40) return copy.bad;
    if (value <= 60) return copy.okay;
    if (value <= 80) return copy.good;
    return copy.veryGood;
  }

  String _stressDescriptor(int value, AppStrings copy) {
    if (value <= 20) return copy.veryGood;
    if (value <= 40) return copy.good;
    if (value <= 60) return copy.okay;
    if (value <= 80) return copy.bad;
    return copy.veryBad;
  }

  String _energyDescriptor(int value, AppStrings copy) {
    if (value <= 20) return copy.veryBad;
    if (value <= 40) return copy.bad;
    if (value <= 60) return copy.okay;
    if (value <= 80) return copy.good;
    return copy.veryGood;
  }

  // ── 滑桿表情連動 (Slider Emoji Linkage) ─────────────────────────
  IconData _moodEmoji(int value) {
    if (value <= 20) return Icons.sentiment_very_dissatisfied_rounded;
    if (value <= 40) return Icons.sentiment_dissatisfied_rounded;
    if (value <= 60) return Icons.sentiment_neutral_rounded;
    if (value <= 80) return Icons.sentiment_satisfied_rounded;
    return Icons.sentiment_very_satisfied_rounded;
  }

  IconData _stressEmoji(int value) {
    if (value <= 25) return Icons.spa_rounded;
    if (value <= 50) return Icons.psychology_rounded;
    if (value <= 75) return Icons.psychology_alt_rounded;
    return Icons.warning_amber_rounded;
  }

  IconData _energyEmoji(int value) {
    if (value <= 25) return Icons.battery_1_bar_rounded;
    if (value <= 50) return Icons.battery_3_bar_rounded;
    if (value <= 75) return Icons.battery_5_bar_rounded;
    return Icons.battery_full_rounded;
  }
}
