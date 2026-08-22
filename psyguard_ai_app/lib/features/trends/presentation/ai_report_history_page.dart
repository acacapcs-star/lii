import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/app_database.dart';
import '../../../core/storage/database_provider.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_strings.dart';

class AiReportHistoryPage extends ConsumerWidget {
  const AiReportHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(copy.analysisHistory),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<List<AiReport>>(
        future: db.getAllAiReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(copy.loadFailed(snapshot.error!)));
          }

          final data = snapshot.data ?? [];

          if (data.isEmpty) {
            return Center(
              child: Text(
                copy.noAnalysisReports,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: data.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final report = data[index];
              return _ReportCard(report: report, copy: copy);
            },
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.copy});

  final AiReport report;
  final AppStrings copy;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    return Card(
      elevation: 0,
      color: const Color(0xFFF5F7FA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.push('/ai_report', extra: report.content);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: LumiTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      copy.recentDays(report.rangeDays),
                      style: const TextStyle(
                        color: LumiTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    dateFormat.format(report.createdAt),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                report.content, // Show preview
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LumiTheme.textPrimary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    copy.viewFullReport,
                    style: TextStyle(
                      color: LumiTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: LumiTheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
