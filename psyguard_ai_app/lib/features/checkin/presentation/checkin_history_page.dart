import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/storage/database_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../l10n/app_strings.dart';

class CheckinHistoryPage extends ConsumerWidget {
  const CheckinHistoryPage({super.key});

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
          copy.isZhTw ? '筆記紀錄歷史' : 'Check-in History',
          style: GoogleFonts.varelaRound(
            color: LumiTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FutureBuilder(
        future: db.getAllCheckins(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: LumiTheme.primary),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text(copy.loadFailed(snapshot.error!)));
          }

          final checkins = snapshot.data ?? [];

          if (checkins.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.note_alt_outlined,
                    size: 64,
                    color: LumiTheme.textLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    copy.isZhTw ? '尚無紀錄' : 'No records yet',
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
            itemCount: checkins.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final checkin = checkins[index];
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
                          DateFormat('yyyy/MM/dd HH:mm').format(checkin.date),
                          style: GoogleFonts.nunitoSans(
                            color: LumiTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        _buildScoreBadge(copy.mood, checkin.moodScore),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (checkin.note != null && checkin.note!.isNotEmpty) ...[
                      Text(
                        checkin.note!,
                        style: GoogleFonts.nunitoSans(
                          color: LumiTheme.textPrimary,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ] else
                      Text(
                        copy.isZhTw ? '無文字筆記' : 'No text note',
                        style: GoogleFonts.nunitoSans(
                          color: LumiTheme.textLight,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildSmallBadge(copy.energy, checkin.energyScore),
                        const SizedBox(width: 8),
                        _buildSmallBadge(copy.stress, checkin.stressScore),
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

  Widget _buildScoreBadge(String label, int score) {
    Color color;
    if (score >= 70) {
      color = LumiTheme.success;
    } else if (score >= 40) {
      color = LumiTheme.textSecondary;
    } else {
      color = LumiTheme.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $score%',
        style: GoogleFonts.nunitoSans(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSmallBadge(String label, int score) {
    return Text(
      '$label: $score%',
      style: GoogleFonts.nunitoSans(
        color: LumiTheme.textSecondary,
        fontSize: 12,
      ),
    );
  }
}
