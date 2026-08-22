import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/storage/database_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../l10n/app_strings.dart';

class SleepHistoryPage extends ConsumerWidget {
  const SleepHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final theme = Theme.of(context);
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));

    return Scaffold(
      backgroundColor: LumiTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: LumiTheme.textPrimary),
        title: Text(
          copy.isZhTw ? '睡眠歷史紀錄' : 'Sleep History',
          style: GoogleFonts.varelaRound(
            color: LumiTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FutureBuilder(
        future: db.getAllSleepLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: LumiTheme.primary),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text(copy.loadFailed(snapshot.error!)));
          }

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bedtime_outlined,
                    size: 64,
                    color: LumiTheme.textLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    copy.isZhTw ? '尚無睡眠紀錄' : 'No sleep records yet',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: LumiTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: logs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final log = logs[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF0F0F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('yyyy/MM/dd').format(log.date),
                          style: GoogleFonts.nunitoSans(
                            color: LumiTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        _buildQualityBadge(log.difficulty, copy),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoColumn(
                          copy.bedtime,
                          _formatTime(log.bedtime),
                        ),
                        _buildInfoColumn(
                          copy.waketime,
                          _formatTime(log.waketime),
                        ),
                        _buildInfoColumn(
                          copy.isZhTw ? '總時數' : 'Total',
                          copy.hours(log.sleepHours),
                          isHighlight: true,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return DateFormat('HH:mm').format(dt);
  }

  Widget _buildInfoColumn(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.nunitoSans(
            fontSize: 12,
            color: LumiTheme.textLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.nunitoSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isHighlight
                ? LumiTheme.primary
                : LumiTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildQualityBadge(int difficulty, AppStrings copy) {
    // difficulty: 0 (沒有困難) to 3 (嚴重)
    String label;
    Color color;

    if (difficulty <= 0) {
      label = copy.isZhTw ? '品質優良' : 'Excellent';
      color = LumiTheme.success;
    } else if (difficulty <= 1) {
      label = copy.isZhTw ? '品質良好' : 'Good';
      color = LumiTheme.success;
    } else if (difficulty == 2) {
      label = copy.isZhTw ? '品質普通' : 'Fair';
      color = LumiTheme.textSecondary;
    } else {
      label = copy.isZhTw ? '品質不佳' : 'Poor';
      color = LumiTheme.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunitoSans(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
