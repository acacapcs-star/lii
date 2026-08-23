import 'dart:math';

import 'package:flutter/material.dart';
import '../../../core/widgets/lii_bottom_nav.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/risk_engine/risk_models.dart';
import '../../../core/risk_engine/risk_provider.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../core/storage/database_provider.dart';
import '../../../core/data/quotes_data.dart';
import '../../../l10n/app_strings.dart';

class ToolItem {
  const ToolItem({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.isInteractive = false,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool isInteractive;
}

class ToolsPage extends ConsumerWidget {
  const ToolsPage({super.key});

  static const toolboxItems = [
    ToolItem(
      id: 'self_dialogue',
      name: '自我對話卡',
      description: '抽出一張指引卡片，轉化自我責備的念頭。',
      icon: Icons.style_rounded,
      color: Color(0xFFF2A365), // Orange
      isInteractive: true,
    ),
    ToolItem(
      id: 'breathing_478',
      name: '4-7-8 呼吸',
      description: '吸氣 4 秒、閉氣 7 秒、吐氣 8 秒，做 3 回合。',
      icon: Icons.air_rounded,
      color: Color(0xFF667EEA), // Blue
    ),
    ToolItem(
      id: 'grounding_54321',
      name: '5-4-3-2-1 著地',
      description: '說出你看見 5 樣、摸到 4 樣、聽到 3 樣、聞到 2 樣、感受 1 樣。',
      icon: Icons.nature_people_rounded,
      color: Color(0xFF43E97B), // Green
    ),
    ToolItem(
      id: 'emotion_dict',
      name: '情緒詞彙庫',
      description: '除了「不開心」，試著精準描述你的感受。',
      icon: Icons.menu_book_rounded,
      color: Color(0xFFE5989B), // Pink
      isInteractive: true,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    return Scaffold(
      bottomNavigationBar: LiiBottomNav(
        isZh: Localizations.localeOf(context).languageCode == 'zh',
        current: LiiTab.tools,
      ),
      backgroundColor: LumiTheme.background,
      appBar: AppBar(
        title: Text(copy.toolsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: copy.toolHistory,
            onPressed: () => context.push('/tools/history'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        itemCount: 1,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) => ToolsLayout(isZh: copy.isZhTw),
      ),
    );
  }
}

class _ToolCard extends ConsumerWidget {
  const _ToolCard({required this.tool});

  final ToolItem tool;

  void _handleToolAction(BuildContext context, WidgetRef ref) {
    final copy = AppStrings.of(ref.read(appLanguageControllerProvider));
    if (tool.id == 'self_dialogue') {
      _showCardDialog(context, copy);
    } else if (tool.id == 'emotion_dict') {
      _showEmotionDialog(context, copy);
    }
  }

  void _showCardDialog(BuildContext context, AppStrings copy) {
    final quote = copy.isZhTw
        ? kSelfCompassionQuotes[Random().nextInt(kSelfCompassionQuotes.length)]
              .content
        : _englishSelfCompassionQuotes[Random().nextInt(
            _englishSelfCompassionQuotes.length,
          )];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, color: tool.color, size: 48),
              const SizedBox(height: 20),
              Text(
                copy.todayGuidance,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: LumiTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                copy.isZhTw ? '「$quote」' : '"$quote"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: LumiTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: tool.color,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(copy.acceptThisLine),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmotionDialog(BuildContext context, AppStrings copy) {
    final emotions = copy.isZhTw
        ? const [
            '焦慮',
            '疲憊',
            '平靜',
            '憤怒',
            '孤獨',
            '充滿希望',
            '悲傷',
            '感恩',
            '不知所措',
            '興奮',
            '無力',
            '滿足',
          ]
        : const [
            'Anxious',
            'Exhausted',
            'Calm',
            'Angry',
            'Lonely',
            'Hopeful',
            'Sad',
            'Grateful',
            'Overwhelmed',
            'Excited',
            'Powerless',
            'Content',
          ];

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(copy.emotionDictionary),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        children: emotions
            .map(
              (e) => SimpleDialogOption(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Text(e, style: const TextStyle(fontSize: 16)),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _logCompletion(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(appDatabaseProvider)
          .insertToolUsage(
            date: DateTime.now(),
            toolId: tool.id,
            durationSec: 180,
            completed: true,
          );
      final risk = await ref
          .read(riskEvaluationServiceProvider)
          .evaluateAndPersistToday();

      final copy = AppStrings.of(ref.read(appLanguageControllerProvider));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(copy.toolSavedRisk(risk.riskLevelKey.toUpperCase())),
        ),
      );
      if (risk.riskLevel == RiskLevel.high) {
        context.go('/safety');
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.of(
              ref.read(appLanguageControllerProvider),
            ).toolRecordFailed(e),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    final toolName = _toolName(tool.id, copy);
    final toolDescription = _toolDescription(tool.id, copy);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: LumiTheme.softCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tool.icon, color: tool.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  toolName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: LumiTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            toolDescription,
            style: const TextStyle(
              fontSize: 15,
              color: LumiTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: tool.isInteractive
                ? FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _handleToolAction(context, ref),
                    child: Text(copy.startExperience),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _logCompletion(context, ref),
                    child: Text(copy.completePractice),
                  ),
          ),
        ],
      ),
    );
  }

  String _toolName(String id, AppStrings copy) {
    return switch (id) {
      'self_dialogue' => copy.selfDialogueCard,
      'breathing_478' => copy.breathing478,
      'grounding_54321' => copy.grounding54321,
      'emotion_dict' => copy.emotionDictionary,
      _ => id,
    };
  }

  String _toolDescription(String id, AppStrings copy) {
    return switch (id) {
      'self_dialogue' => copy.selfDialogueDesc,
      'breathing_478' => copy.breathing478Desc,
      'grounding_54321' => copy.grounding54321Desc,
      'emotion_dict' => copy.emotionDictionaryDesc,
      _ => '',
    };
  }
}

const _englishSelfCompassionQuotes = [
  'Even if today feels hard, I do not need to punish myself to feel better.',
  'This feeling is temporary. It can pass through me like a cloud.',
  'I have the right to rest, say no, and care for my needs.',
  'It is okay not to do this perfectly. I am learning.',
  'I only need to focus on the next small step.',
  'My worth is not measured by productivity or other people\'s opinions.',
  'Take a breath. I am here. I am safe in this moment.',
  'I can speak to myself with the same kindness I would offer a good friend.',
];
// 貼到 tools_page.dart 檔案最後面（最外層，不要放在任何 class 裡面）

class ToolShortcuts extends StatelessWidget {
  const ToolShortcuts({super.key, required this.isZh});

  final bool isZh;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, IconData, Color, String)>[
      (
        isZh ? '換個角度' : 'Thought Coach',
        isZh ? '同一件事，另一種說法' : 'Reframe a thought',
        Icons.refresh_rounded,
        const Color(0xFF41C8A0),
        '/thought-coach',
      ),
      (
        isZh ? '你常掉進哪一個' : 'Thinking Traps',
        isZh ? '找出你的慣性' : 'Find your patterns',
        Icons.search_rounded,
        const Color(0xFF417CC8),
        '/distortion-quiz',
      ),
      (
        isZh ? '希望盒' : 'Hope Box',
        isZh ? '撐住你的那些話' : 'Cards that carry you',
        Icons.favorite_rounded,
        const Color(0xFF7A41C8),
        '/hope-box',
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        for (final it in items)
          _ToolShortcutCard(
            title: it.$1,
            subtitle: it.$2,
            icon: it.$3,
            color: it.$4,
            route: it.$5,
          ),
      ],
    );
  }
}

class _ToolShortcutCard extends StatelessWidget {
  const _ToolShortcutCard({
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
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        splashColor: color.withValues(alpha: 0.3),
        onTap: () => context.push(route),
        child: Container(
          padding: const EdgeInsets.all(16),
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
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.40), width: 4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: onCard,
                      height: 1.15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(fontSize: 11, color: onCardSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
// 貼到 tools_page.dart 檔案最後面（最外層）

/// 工具頁的第四條：心理工具箱入口
class ToolboxEntry extends StatelessWidget {
  const ToolboxEntry({super.key, required this.isZh});

  final bool isZh;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF41C8A0);
    final hsl = HSLColor.fromColor(color);
    final onCard = hsl.withSaturation(1.0).withLightness(0.22).toColor();
    final onCardSoft = hsl.withSaturation(0.85).withLightness(0.36).toColor();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        splashColor: color.withValues(alpha: 0.3),
        onTap: () => context.push('/toolbox'),
        child: Container(
          padding: const EdgeInsets.all(18),
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
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.40), width: 4),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medical_services_rounded,
                    color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isZh ? '心理工具箱' : 'Toolbox',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: onCard)),
                    const SizedBox(height: 2),
                    Text(isZh ? '現在就能用的四個方法' : 'Four things you can do now',
                        style: TextStyle(fontSize: 11, color: onCardSoft)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: onCardSoft, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// 心理工具箱 — 四個當下就能用的方法
class ToolboxPage extends ConsumerWidget {
  const ToolboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          copy.isZhTw ? '心理工具箱' : 'Toolbox',
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: LumiTheme.textPrimary),
        ),
      ),
      body: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        itemCount: ToolsPage.toolboxItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) =>
            _ToolCard(tool: ToolsPage.toolboxItems[index]),
      ),
    );
  }
}
// 貼到 tools_page.dart 檔案最後面（最外層）
// 取代舊的 ToolShortcuts：左欄兩張方塊，右欄一張方塊 + 四個橫條工具

class ToolsLayout extends StatelessWidget {
  const ToolsLayout({super.key, required this.isZh});

  final bool isZh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左欄
        Expanded(
          child: Column(
            children: [
              _SquareCard(
                title: isZh ? '換個角度' : 'Thought Coach',
                subtitle: isZh ? '同一件事，另一種說法' : 'Reframe a thought',
                icon: Icons.refresh_rounded,
                color: const Color(0xFF41C8A0),
                route: '/thought-coach',
              ),
              const SizedBox(height: 14),
              _SquareCard(
                title: isZh ? '希望盒' : 'Hope Box',
                subtitle: isZh ? '撐住你的那些話' : 'Cards that carry you',
                icon: Icons.favorite_rounded,
                color: const Color(0xFF7A41C8),
                route: '/hope-box',
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        // 右欄
        Expanded(
          child: Column(
            children: [
              _SquareCard(
                title: isZh ? '你常掉進哪一個' : 'Thinking Traps',
                subtitle: isZh ? '找出你的慣性' : 'Find your patterns',
                icon: Icons.search_rounded,
                color: const Color(0xFF417CC8),
                route: '/distortion-quiz',
              ),
              const SizedBox(height: 14),
              for (final t in ToolsPage.toolboxItems) ...[
                _CompactToolCard(tool: t),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SquareCard extends StatelessWidget {
  const _SquareCard({
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

    return AspectRatio(
      aspectRatio: 1.05,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          splashColor: color.withValues(alpha: 0.3),
          onTap: () => context.push(route),
          child: Container(
            padding: const EdgeInsets.all(16),
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
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: color.withValues(alpha: 0.40), width: 4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 10),
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: onCard,
                        height: 1.15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: onCardSoft),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// 貼到 tools_page.dart 檔案最後面（最外層）
// 右欄用的精簡版：只有圖示與標題，點一下直接觸發原本的功能

class _CompactToolCard extends ConsumerWidget {
  const _CompactToolCard({required this.tool});

  final ToolItem tool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    final name = copy.isZhTw ? tool.name : _englishName(tool.id, tool.name);
    final hsl = HSLColor.fromColor(tool.color);
    final onCard = hsl.withSaturation(1.0).withLightness(0.22).toColor();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        splashColor: tool.color.withValues(alpha: 0.3),
        onTap: () => _ToolCard(tool: tool)._handleToolAction(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color.alphaBlend(
                    tool.color.withValues(alpha: 0.14), Colors.white),
                Color.alphaBlend(
                    tool.color.withValues(alpha: 0.34), Colors.white),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: tool.color.withValues(alpha: 0.40), width: 3),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(tool.icon, color: tool.color, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: onCard,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _englishName(String id, String fallback) {
    switch (id) {
      case 'self_dialogue':
        return 'Self-dialogue Card';
      case 'breathing_478':
        return '4-7-8 Breathing';
      case 'grounding_54321':
        return '5-4-3-2-1 Grounding';
      case 'emotion_dict':
        return 'Emotion Dictionary';
      default:
        return fallback;
    }
  }
}
