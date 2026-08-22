import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../l10n/app_strings.dart';

class AiReportPage extends ConsumerWidget {
  const AiReportPage({super.key, required this.reportContent});

  final String reportContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(copy.aiReportTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: copy.copyReport,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: reportContent));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(copy.reportCopied)));
            },
          ),
        ],
      ),
      body: Markdown(
        data: reportContent,
        padding: const EdgeInsets.all(20),
        styleSheet: MarkdownStyleSheet(
          h1: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: LumiTheme.textPrimary,
            height: 1.5,
          ),
          h2: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: LumiTheme.textPrimary,
            height: 1.5,
          ),
          h3: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: LumiTheme.textPrimary,
            height: 1.5,
          ),
          p: const TextStyle(
            fontSize: 16,
            color: LumiTheme.textPrimary,
            height: 1.6,
          ),
          listBullet: const TextStyle(
            color: LumiTheme.primary,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
