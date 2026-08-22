import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/export/summary_export_service.dart';
import '../../../core/export/export_models.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../core/storage/database_provider.dart'; // Added
import '../../../core/data/mock_data_seeder.dart'; // Added
import '../../../l10n/app_strings.dart';
import '../../home/presentation/home_page.dart'; // Added
import '../../trends/presentation/trends_page.dart'; // Added

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  bool _exporting = false;
  int _days = 7;

  Future<void> _export() async {
    if (_exporting) return;
    final copy = AppStrings.of(ref.read(appLanguageControllerProvider));
    setState(() => _exporting = true);

    try {
      final service = ref.read(summaryExportServiceProvider);
      final file = await service.exportSummary(
        days: _days,
        format: ExportFormat.json,
        isZh: copy.isZhTw,
      );

      if (!mounted) return;
      // 📤 匯出後跳分享面板（AirDrop／存檔案／傳給家長或輔導老師）
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: copy.isZhTw ? 'lii 情緒摘要報告' : 'lii Well-being Summary',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.exportedTo(file.path))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.exportFailed(e))));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    return Scaffold(
      backgroundColor: LumiTheme.background,
      appBar: AppBar(
        title: Text(copy.exportTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Stack(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: LumiTheme.softCard,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: LumiTheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.description_rounded,
                          size: 48,
                          color: LumiTheme.primary.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        copy.exportReportTitle(_days),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: LumiTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        copy.exportReportBody(_days),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: LumiTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final days in [7, 14, 30])
                            FilterChip(
                              label: Text(copy.days(days)),
                              selected: _days == days,
                              showCheckmark: false,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _days = days);
                                }
                              },
                              selectedColor: LumiTheme.primary,
                              backgroundColor: LumiTheme.surface,
                              labelStyle: TextStyle(
                                color: _days == days
                                    ? Colors.white
                                    : LumiTheme.textSecondary,
                                fontWeight: _days == days
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _exporting ? null : _export,
                          icon: _exporting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.download_rounded),
                          label: Text(
                            _exporting ? copy.exporting : copy.generateAndSave,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: LumiTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: LumiTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          copy.reportDisclaimer,
                          style: TextStyle(
                            color: LumiTheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),
                // ── Developer Options ───────────────────────────────────────────
                TextButton.icon(
                  onPressed: _exporting ? null : _resetAndSeedData,
                  icon: const Icon(Icons.dataset_linked_rounded, size: 18),
                  label: Text(copy.resetDemoData),
                  style: TextButton.styleFrom(
                    foregroundColor: LumiTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetAndSeedData() async {
    final copy = AppStrings.of(ref.read(appLanguageControllerProvider));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(copy.resetData),
        content: Text(copy.resetDemoConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(copy.cancel),
          ), // TextButton
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: LumiTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(copy.reset),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _exporting = true);
    try {
      final db = ref.read(appDatabaseProvider);
      await MockDataSeeder(db).seed();

      // Force refresh of providers
      ref.invalidate(homeDashboardProvider);
      ref.invalidate(trendBundleProvider);
      ref.read(trendRangeProvider.notifier).state =
          30; // Reset range to default

      // Force refresh of providers if needed, or just show snackbar
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.demoDataImported)));
      // Go home to refresh
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.operationFailed(e))));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
