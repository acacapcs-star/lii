import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/risk_engine/risk_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/safety/safety_flow_service.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../core/storage/database_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_language.dart';
import '../../../l10n/app_strings.dart';

final latestRiskLevelProvider = FutureProvider<RiskLevel>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final ersLevel = prefs.getString('last_ers_level') ?? 'green';
  if (ersLevel == 'red') return RiskLevel.high;
  if (ersLevel == 'yellow') return RiskLevel.medium;
  final snapshot = await ref.read(appDatabaseProvider).getLatestRiskSnapshot();
  return switch (snapshot?.riskLevel) {
    'high' => RiskLevel.high,
    'medium' => RiskLevel.medium,
    _ => RiskLevel.low,
  };
});

class SafetyPage extends ConsumerWidget {
  const SafetyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riskLevelAsync = ref.watch(latestRiskLevelProvider);
    final language = ref.watch(appLanguageControllerProvider);
    final copy = AppStrings.of(language);
    return Scaffold(
      backgroundColor: LumiTheme.background,
      appBar: AppBar(
        title: Text(copy.safetyTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: riskLevelAsync.when(
        data: (riskLevel) {
          final plan = ref
              .read(safetyFlowServiceProvider)
              .getPlan(
                riskLevel: riskLevel,
                locale: language == AppLanguage.zhTw ? 'zh-TW' : 'en-US',
              );

          final effectiveHigh = riskLevel == RiskLevel.high;

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (effectiveHigh) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEF9A9A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        copy.liiIsHere,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0ABFBC),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => context.go('/chat'),
                        child: Text(copy.safetyOptionChat),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0ABFBC)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(copy.safetyOptionCounselor),
                              content: Text(copy.safetyCounselorBody),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(copy.gotIt),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Text(copy.safetyOptionCounselor),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {},
                        child: Text(copy.safetyOptionResources),
                      ),
                    ],
                  ),
                ),
              ],
              // 守護精靈訊息卡片
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: riskLevel == RiskLevel.high
                      ? const Color(0xFFFFEBEE)
                      : riskLevel == RiskLevel.medium
                          ? const Color(0xFFFFF8E1)
                          : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: riskLevel == RiskLevel.high
                        ? const Color(0xFFEF9A9A)
                        : riskLevel == RiskLevel.medium
                            ? const Color(0xFFFFE082)
                            : const Color(0xFFA5D6A7),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      riskLevel == RiskLevel.high ? '🔴' : riskLevel == RiskLevel.medium ? '🟡' : '🟢',
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        effectiveHigh
                            ? copy.guardianHigh
                            : riskLevel == RiskLevel.medium
                                ? copy.guardianMedium
                                : copy.guardianLow,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF5576C), Color(0xFFFF8177)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF5576C).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.health_and_safety_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            riskLevel == RiskLevel.high
                                ? copy.safetyFirst
                                : copy.needHelpQuestion,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            copy.immediateDangerCall,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _sectionTitle(copy.supportResources),
              const SizedBox(height: 12),
              ...plan.resources.expand((r) sync* {
                yield _resourceCard(
                  context,
                  copy: copy,
                  name: r.name,
                  contact: r.contact,
                  description: r.description,
                );
                yield const SizedBox(height: 12);
              }).toList()..removeLast(),
              const SizedBox(height: 18),
              _sectionTitle(copy.safetySteps),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: LumiTheme.softCard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final step in plan.steps) ...[
                      Text(
                        step.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: LumiTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step.content,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: LumiTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _sectionTitle(copy.copyHelpMessage),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: LumiTheme.softCard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.copyTemplate,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: LumiTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        key: const ValueKey('copy_help_template_button'),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: plan.copyTemplate),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(copy.helpMessageCopied)),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LumiTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(copy.copy),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                plan.disclaimer,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: LumiTheme.textLight,
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: LumiTheme.primary),
        ),
        error: (error, stack) => Center(child: Text(copy.loadFailed(error))),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: LumiTheme.textPrimary,
      ),
    );
  }

  Widget _resourceCard(
    BuildContext context, {
    required AppStrings copy,
    required String name,
    required String contact,
    required String description,
  }) {
    return InkWell(
      onTap: contact.trim().isEmpty
          ? null
          : () async {
              await Clipboard.setData(ClipboardData(text: contact));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${copy.copied}: $contact')),
                );
              }
            },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: LumiTheme.softCard,
        // 改成上下排：名稱與說明佔滿整行，聯絡方式自成一行。
        // 舊版把三者塞進同一條 Row，contact 一長就把名稱擠成兩三個字元寬，
        // 英文長字（counseling）只好一個音節一行，看起來像直書。
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LumiTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: LumiTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: LumiTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: LumiTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (contact.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              // 自成一行，寬度不再跟名稱搶
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: LumiTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    contact,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: LumiTheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
