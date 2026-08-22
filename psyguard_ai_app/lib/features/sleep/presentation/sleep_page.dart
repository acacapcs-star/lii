import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/risk_engine/risk_models.dart';
import '../../../core/risk_engine/risk_provider.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../core/storage/database_provider.dart';
import '../../../l10n/app_strings.dart';

class SleepPage extends ConsumerStatefulWidget {
  const SleepPage({super.key});

  @override
  ConsumerState<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends ConsumerState<SleepPage> {
  double _sleepHours = 7;
  int _difficulty = 1;
  TimeOfDay _bedtime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _waketime = const TimeOfDay(hour: 7, minute: 0);
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    final copy = AppStrings.of(ref.read(appLanguageControllerProvider));
    setState(() => _saving = true);

    final now = DateTime.now();
    DateTime toDate(TimeOfDay t) =>
        DateTime(now.year, now.month, now.day, t.hour, t.minute);

    try {
      await ref
          .read(appDatabaseProvider)
          .upsertSleepLog(
            date: now,
            sleepHours: _sleepHours,
            difficulty: _difficulty,
            bedtime: toDate(_bedtime),
            waketime: toDate(_waketime),
          );

      final risk = await ref
          .read(riskEvaluationServiceProvider)
          .evaluateAndPersistToday();

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(copy.savedSleepRisk(risk.riskLevelKey.toUpperCase())),
        ),
      );

      if (risk.riskLevel == RiskLevel.high) {
        context.go('/safety');
      }
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
    final difficultyLabels = copy.sleepDifficultyLabels;

    return Scaffold(
      backgroundColor: LumiTheme.background,
      appBar: AppBar(
        title: Text(copy.sleepTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            color: LumiTheme.textPrimary,
            onPressed: () => context.push('/sleep/history'),
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Sleep duration
          Container(
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
                        color: const Color(0xFFA18CD1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.access_time_rounded,
                        color: Color(0xFFA18CD1),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      copy.sleepDuration,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: LumiTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA18CD1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        copy.hours(_sleepHours),
                        style: const TextStyle(
                          color: Color(0xFFA18CD1),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFA18CD1),
                    inactiveTrackColor: const Color(
                      0xFFA18CD1,
                    ).withValues(alpha: 0.15),
                    thumbColor: const Color(0xFFA18CD1),
                    overlayColor: const Color(
                      0xFFA18CD1,
                    ).withValues(alpha: 0.1),
                    trackHeight: 6,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                  ),
                  child: Slider(
                    value: _sleepHours,
                    min: 2,
                    max: 12,
                    divisions: 20,
                    onChanged: (v) => setState(() => _sleepHours = v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Difficulty
          Container(
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
                        color: const Color(0xFFF5576C).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.nights_stay_rounded,
                        color: Color(0xFFF5576C),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      copy.sleepDifficulty,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: LumiTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  children: List.generate(4, (i) {
                    final isSelected = _difficulty == i;
                    return ChoiceChip(
                      label: Text('$i — ${difficultyLabels[i]}'),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _difficulty = i),
                      selectedColor: LumiTheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : LumiTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Time pickers
          Container(
            padding: const EdgeInsets.all(20),
            decoration: LumiTheme.softCard,
            child: Column(
              children: [
                _timeTile(
                  label: copy.bedtime,
                  time: _bedtime,
                  icon: Icons.bedtime_rounded,
                  color: const Color(0xFF667EEA),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _bedtime,
                    );
                    if (picked != null) setState(() => _bedtime = picked);
                  },
                ),
                Divider(color: Colors.grey.withValues(alpha: 0.1), height: 24),
                _timeTile(
                  label: copy.waketime,
                  time: _waketime,
                  icon: Icons.wb_sunny_rounded,
                  color: LumiTheme.accent,
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _waketime,
                    );
                    if (picked != null) setState(() => _waketime = picked);
                  },
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
                  : Text(copy.saveSleep),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeTile({
    required String label,
    required TimeOfDay time,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: LumiTheme.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              time.format(context),
              style: TextStyle(
                fontSize: 15,
                color: LumiTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: LumiTheme.textLight,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
