import 'dart:math';

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/mood_fall_overlay.dart';
import '../../../core/pacer/breath_plan.dart';
import '../../../core/widgets/lii_breath_page.dart';
import '../../../core/widgets/tooltip_bubble.dart';
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
    this.whenToUse = '',
    this.how = '',
    this.isInteractive = false,
  });

  final String id;
  final String name;

  /// 卡片上顯示的一句話
  final String description;

  /// 什麼時候該用這個工具
  final String whenToUse;

  /// 詳細做法與原理，長按時顯示
  final String how;

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
      description: '抽一張卡，把責備自己的話換個說法。',
      whenToUse: '一直在心裡罵自己的時候',
      how: '抽出一張自我疼惜的句子，對照你現在對自己說的話，'
          '看看能不能換一種說法。卡片是從語錄庫抽的，不是 AI 生成的。',
      icon: Icons.style_rounded,
      color: Color(0xFFC87C41),
      isInteractive: true,
    ),
    ToolItem(
      id: 'breathing_478',
      name: '4-7-8 呼吸',
      description: '吸氣 4 秒、閉氣 7 秒、吐氣 8 秒，做 3 回合。',
      whenToUse: '心跳很快、快喘不過氣的時候',
      how: '吐氣比吸氣長，會讓副交感神經接手，心跳自然慢下來。'
          '第一次做通常閉不滿 7 秒，那沒關係——按自己的節奏，'
          '三回合之後再試一次完整的。',
      icon: Icons.air_rounded,
      color: Color(0xFF415AC8),
    ),
    ToolItem(
      id: 'grounding_54321',
      name: '5-4-3-2-1 著地',
      description: '說出看見 5 樣、摸到 4 樣、聽到 3 樣、聞到 2 樣、感受 1 樣。',
      whenToUse: '腦袋停不下來、覺得自己飄走的時候',
      how: '用五種感官把注意力從念頭拉回身體所在的地方。'
          '重點不是數對，是每說一樣就真的去看、去摸一次。'
          '做到一半分心了就從頭開始，那也算。',
      icon: Icons.nature_people_rounded,
      color: Color(0xFF41C86F),
    ),
    ToolItem(
      id: 'emotion_dict',
      name: '情緒詞彙庫',
      description: '除了「不開心」，找一個更準的詞。',
      whenToUse: '知道自己不對勁，但講不出來的時候',
      how: '從幾個大類往下找更細的詞。'
          '「不開心」可能是失望、可能是被辜負、可能只是累。'
          '講得出來的情緒比較好處理——這是這個工具唯一的用意。',
      icon: Icons.menu_book_rounded,
      color: Color(0xFFC84147),
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
        itemBuilder: (context, index) => GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.05,
          children: [
            for (final t in toolboxItems) _ToolSquare(tool: t),
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends ConsumerWidget {
  const _ToolCard({required this.tool});

  final ToolItem tool;

  /// 呼吸與著地開專屬頁面，其餘走原本的對話框
  Future<void> _openOrLog(BuildContext context, WidgetRef ref) async {
    if (tool.id == 'grounding_54321') {
      final done = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const GroundingPage()),
      );
      if (done == true && context.mounted) {
        _logCompletion(context, ref);
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GroundingLogPage()),
        );
      }
      return;
    }
    if (tool.id == 'breathing_478') {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const LiiBreathPage(
          mood: BreathMood.anxious,
          mode: LiiBreathMode.daily,
        ),
      ));
      if (context.mounted) _logCompletion(context, ref);
      return;
    }
    if (tool.id == 'emotion_dict') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EmotionDictPage()),
      );
      if (context.mounted) _logCompletion(context, ref);
      return;
    }
    if (tool.isInteractive) {
      _handleToolAction(context, ref);
    } else {
      _logCompletion(context, ref);
    }
  }

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
                    Text(isZh ? '心情工具箱' : 'Toolbox',
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
          copy.isZhTw ? '心情工具箱' : 'Toolbox',
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
      aspectRatio: 0.85,
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
        onTap: () async {
          final card = _ToolCard(tool: tool);
          if (tool.id == 'breathing_478') {
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const LiiBreathPage(
                mood: BreathMood.anxious,
                mode: LiiBreathMode.daily,
              ),
            ));
            if (context.mounted) card._logCompletion(context, ref);
          } else if (tool.id == 'grounding_54321') {
            bool? done;
            try {
              done = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => const GroundingPage(),
                ),
              );
            } catch (e, st) {
              debugPrint('GROUNDING FAILED: $e\n$st');
            }
            if (done == true && context.mounted) {
              card._logCompletion(context, ref);
            }
          } else if (tool.isInteractive) {
            card._handleToolAction(context, ref);
          } else {
            card._logCompletion(context, ref);
          }
        },
        onLongPress: () {
          if (tool.how.isEmpty) return;
          showFeatureTooltip(
            context,
            title: tool.name,
            description: '${tool.whenToUse}\n\n${tool.how}',
          );
        },
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

/// 工具頁的方塊卡：圖示在上、標題與說明在下，點一下直接執行
class _ToolSquare extends ConsumerWidget {
  const _ToolSquare({required this.tool});

  final ToolItem tool;

  static String _enDesc(String id) {
    switch (id) {
      case 'self_dialogue':
        return 'Draw a card and reword what you tell yourself.';
      case 'breathing_478':
        return 'In for 4, hold for 7, out for 8. Three rounds.';
      case 'grounding_54321':
        return 'Name 5 you see, 4 you touch, 3 you hear, 2 you smell, 1 you feel.';
      case 'emotion_dict':
        return 'Past "not okay" toward a more precise word.';
      default:
        return '';
    }
  }

  static String _en(String id, String fallback) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    final zh = copy.isZhTw;
    final name = zh ? tool.name : _en(tool.id, tool.name);
    final hsl = HSLColor.fromColor(tool.color);
    final onCard = hsl.withSaturation(1.0).withLightness(0.22).toColor();
    final onCardSoft = hsl.withSaturation(0.85).withLightness(0.36).toColor();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        splashColor: tool.color.withValues(alpha: 0.3),
        onTap: () => _ToolCard(tool: tool)._openOrLog(context, ref),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color.alphaBlend(
                    tool.color.withValues(alpha: 0.14), Colors.white),
                Color.alphaBlend(
                    tool.color.withValues(alpha: 0.38), Colors.white),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: tool.color.withValues(alpha: 0.40), width: 4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tool.icon, color: tool.color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(name,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      color: onCard),
                  softWrap: true),
              const SizedBox(height: 3),
              Text(
                zh ? tool.description : _enDesc(tool.id),
                style: TextStyle(fontSize: 11, height: 1.25, color: onCardSoft),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// 貼到 tools_page.dart 檔案最後面（最外層）
//
// 5-4-3-2-1 著地的引導頁：五個步驟，每步一個感官。
// 可以打字，也可以只按「下一個」——重點不是寫下來，是真的去看、去摸一次。


/// 5-4-3-2-1 著地：五個頁面，一頁一個感官，各配一種飄落效果。

/// 5-4-3-2-1 著地：五個頁面，一頁一個感官，各配一種飄落效果。
/// 每頁可以寫下來，五頁走完會存成一筆紀錄。

/// 5-4-3-2-1 著地：五個頁面，一頁一個感官。
/// 每頁分成 N 個小格，填一格上面的數字減一。
class GroundingPage extends ConsumerStatefulWidget {
  const GroundingPage({super.key});

  @override
  ConsumerState<GroundingPage> createState() => _GroundingPageState();
}

class _GroundingPageState extends ConsumerState<GroundingPage> {
  final _page = PageController();
  final _fall = MoodFallController();
  int _index = 0;

  /// 五頁各自的輸入框：5、4、3、2、1 格
  late final List<List<TextEditingController>> _ctrls = [
    List.generate(5, (_) => TextEditingController()),
    List.generate(4, (_) => TextEditingController()),
    List.generate(3, (_) => TextEditingController()),
    List.generate(2, (_) => TextEditingController()),
    List.generate(1, (_) => TextEditingController()),
  ];

  @override
  void initState() {
    super.initState();
    for (final page in _ctrls) {
      for (final c in page) {
        c.addListener(_onType);
      }
    }
  }

  void _onType() => setState(() {});

  @override
  void dispose() {
    _page.dispose();
    for (final page in _ctrls) {
      for (final c in page) {
        c.removeListener(_onType);
        c.dispose();
      }
    }
    super.dispose();
  }

  /// 這一頁還剩幾格沒填
  int _remaining(int i) =>
      _ctrls[i].where((c) => c.text.trim().isEmpty).length;

  Future<void> _save() async {
    final keys = ['see', 'touch', 'hear', 'smell', 'feel'];
    final data = <String, dynamic>{'at': DateTime.now().toIso8601String()};
    var any = false;
    for (var i = 0; i < 5; i++) {
      final filled = _ctrls[i]
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (filled.isNotEmpty) any = true;
      data[keys[i]] = filled;
    }
    if (!any) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('grounding_log');
      final list = raw == null ? <dynamic>[] : jsonDecode(raw) as List<dynamic>;
      list.insert(0, data);
      await prefs.setString('grounding_log', jsonEncode(list.take(50).toList()));
    } catch (_) {}
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_index < 4) {
      _page.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    } else {
      await _save();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    final zh = copy.isZhTw;

    final steps = <_GroundStep>[
      _GroundStep(5, FallEffectType.petals, const Color(0xFFC8418E),
          zh ? '看見' : 'See',
          zh ? '寫下你現在看得見的東西' : 'Things you can see',
          zh ? '不用找特別的，桌上那支筆也算。' : 'Nothing special. The pen counts.'),
      _GroundStep(4, FallEffectType.leaves, const Color(0xFFC87C41),
          zh ? '摸到' : 'Touch',
          zh ? '寫下你摸得到的東西' : 'Things you can touch',
          zh ? '真的伸手去摸，不是想像。' : 'Actually reach out and touch them.'),
      _GroundStep(3, FallEffectType.splash, const Color(0xFF41A8C8),
          zh ? '聽到' : 'Hear',
          zh ? '寫下你聽得見的聲音' : 'Sounds you can hear',
          zh ? '包括你自己的呼吸。' : 'Your own breathing counts.'),
      _GroundStep(2, FallEffectType.snow, const Color(0xFF6A41C8),
          zh ? '聞到' : 'Smell',
          zh ? '寫下你聞得到的氣味' : 'Things you can smell',
          zh ? '聞不到也沒關係，那也是一個答案。' : 'Nothing? That is an answer too.'),
      _GroundStep(1, FallEffectType.none, const Color(0xFF41C86F),
          zh ? '感覺' : 'Feel',
          zh ? '寫下你此刻身體的一種感覺' : 'One thing your body feels',
          zh ? '腳踩在地上，那就是你在這裡的證據。' : 'Your feet on the floor. You are here.'),
    ];

    final s = steps[_index];
    final left = _remaining(_index);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor:
          Color.alphaBlend(s.color.withValues(alpha: 0.05), Colors.white),
      body: Stack(
        children: [
          if (s.effect != FallEffectType.none)
            Positioned.fill(
              child: IgnorePointer(
                child: MoodFallOverlay(
                  controller: _fall,
                  effect: s.effect,
                  particleCount: 14,
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        color: s.color,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      const Spacer(),
                      for (var i = 0; i < steps.length; i++) ...[
                        Container(
                          width: i == _index ? 20 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i <= _index
                                ? s.color
                                : s.color.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        if (i != steps.length - 1) const SizedBox(width: 5),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _page,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: steps.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => _stepBody(steps[i], i, zh),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 18),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: s.color,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _next,
                      child: Text(
                        _index == 4
                            ? (zh ? '完成' : 'Done')
                            : (left == 0
                                ? (zh ? '下一個' : 'Next')
                                : (zh ? '先跳過' : 'Skip for now')),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBody(_GroundStep st, int i, bool zh) {
    final onCard = HSLColor.fromColor(st.color)
        .withSaturation(1.0).withLightness(0.22).toColor();
    final onSoft = HSLColor.fromColor(st.color)
        .withSaturation(0.85).withLightness(0.38).toColor();
    final left = _remaining(i);
    final done = left == 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 倒數的大數字
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Text(
                  done ? '✓' : '$left',
                  key: ValueKey(done ? 'done' : left),
                  style: TextStyle(
                    fontSize: 62,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: st.color.withValues(alpha: done ? 0.55 : 0.32),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  st.name,
                  style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                      color: onCard),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            done
                ? (zh ? '都寫完了。' : 'All written down.')
                : (zh ? '還剩 $left 個　·　${st.prompt}' : '$left left　·　${st.prompt}'),
            style: TextStyle(fontSize: 14.5, height: 1.6, color: onSoft),
          ),
          const SizedBox(height: 4),
          Text(
            st.hint,
            style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: onSoft.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 18),

          // N 個小格
          for (var k = 0; k < _ctrls[i].length; k++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${k + 1}.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _ctrls[i][k].text.trim().isEmpty
                            ? onSoft.withValues(alpha: 0.45)
                            : st.color,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrls[i][k],
                      style: const TextStyle(fontSize: 15),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide(
                              color: st.color.withValues(alpha: 0.26)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide(
                              color: st.color.withValues(alpha: 0.26)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide(color: st.color, width: 2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 6),
          Text(
            zh ? '寫不滿也可以，做過就算。' : 'Partial is fine. Doing it counts.',
            style: TextStyle(
                fontSize: 12, color: onSoft.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class _GroundStep {
  const _GroundStep(
      this.count, this.effect, this.color, this.name, this.prompt, this.hint);

  final int count;
  final FallEffectType effect;
  final Color color;
  final String name;
  final String prompt;
  final String hint;
}
class GroundingLogPage extends ConsumerStatefulWidget {
  const GroundingLogPage({super.key});

  @override
  ConsumerState<GroundingLogPage> createState() => _GroundingLogPageState();
}

class _GroundingLogPageState extends ConsumerState<GroundingLogPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  static const _accent = Color(0xFF41C86F);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('grounding_log');
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _items = list
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    } catch (_) {
      _items = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  String _when(String iso, bool zh) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return zh
        ? '${d.month} 月 ${d.day} 日　$hh:$mm'
        : '${d.month}/${d.day}　$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    final zh = copy.isZhTw;
    final onCard = HSLColor.fromColor(_accent)
        .withSaturation(1.0)
        .withLightness(0.22)
        .toColor();
    final onSoft = HSLColor.fromColor(_accent)
        .withSaturation(0.85)
        .withLightness(0.38)
        .toColor();

    final labels = zh
        ? ['看見', '摸到', '聽到', '聞到', '感覺']
        : ['See', 'Touch', 'Hear', 'Smell', 'Feel'];
    const keys = ['see', 'touch', 'hear', 'smell', 'feel'];
    const counts = [5, 4, 3, 2, 1];

    return Scaffold(
      backgroundColor:
          Color.alphaBlend(_accent.withValues(alpha: 0.04), Colors.white),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          zh ? '著地紀錄' : 'Grounding log',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: onCard),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      zh
                          ? '還沒有紀錄。\n做一次 5-4-3-2-1，寫下來的東西會留在這裡。'
                          : 'Nothing yet.\nRun 5-4-3-2-1 once and what you write stays here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14.5, height: 1.8, color: onSoft),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    final e = _items[i];
                    return Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _accent.withValues(alpha: 0.28), width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _when((e['at'] ?? '').toString(), zh),
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: onSoft),
                          ),
                          const SizedBox(height: 10),
                          for (var k = 0; k < keys.length; k++)
                            if ((e[keys[k]] ?? '').toString().trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _accent.withValues(alpha: 0.16),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${counts[k]}',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: onCard),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            labels[k],
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: onSoft.withValues(
                                                    alpha: 0.75)),
                                          ),
                                          Text(
                                            e[keys[k]].toString(),
                                            style: TextStyle(
                                                fontSize: 14.5,
                                                height: 1.55,
                                                color: onCard),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

/// 情緒詞彙庫：六個大類，點進去看更精準的詞，選了會存成紀錄。
class EmotionDictPage extends ConsumerStatefulWidget {
  const EmotionDictPage({super.key});

  @override
  ConsumerState<EmotionDictPage> createState() => _EmotionDictPageState();
}

class _EmotionDictPageState extends ConsumerState<EmotionDictPage> {
  static const _accent = Color(0xFFC84147);
  int? _open;
  String? _picked;

  static const _groups = <_EmotionGroup>[
    _EmotionGroup(
      '生氣', 'Angry', Icons.local_fire_department_outlined,
      Color(0xFFC84147),
      [
        _Word('惱怒', 'Irritated', '事情不順，但還撐得住', 'Things are off, but manageable'),
        _Word('委屈', 'Wronged', '被誤解了，說不出口', 'Misread, and I cannot say it'),
        _Word('被冒犯', 'Offended', '對方越過了一條線', 'Someone crossed a line'),
        _Word('不甘心', 'Resentful', '努力過但沒被看見', 'I tried and it went unseen'),
      ],
    ),
    _EmotionGroup(
      '難過', 'Sad', Icons.water_drop_outlined,
      Color(0xFF4179C8),
      [
        _Word('失落', 'Let down', '本來期待的沒有發生', 'What I hoped for did not happen'),
        _Word('孤單', 'Lonely', '身邊有人，但沒人懂', 'People around, none who get it'),
        _Word('想念', 'Missing someone', '有個位置空著', 'There is an empty place'),
        _Word('心痛', 'Aching', '想到就會揪一下', 'It tightens when I think of it'),
      ],
    ),
    _EmotionGroup(
      '害怕', 'Afraid', Icons.bolt_outlined,
      Color(0xFF9741C8),
      [
        _Word('緊張', 'Nervous', '事情還沒發生，身體先反應', 'My body reacts before it happens'),
        _Word('不安', 'Uneasy', '說不上來哪裡不對', 'Something is off, I cannot name it'),
        _Word('擔心', 'Worried', '在意的人事出了狀況', 'Something is wrong for someone I care about'),
        _Word('沒把握', 'Unsure', '不知道自己做不做得到', 'I do not know if I can'),
      ],
    ),
    _EmotionGroup(
      '累', 'Tired', Icons.battery_2_bar_outlined,
      Color(0xFFC87C41),
      [
        _Word('疲憊', 'Worn out', '睡了還是累', 'Slept, still tired'),
        _Word('厭倦', 'Fed up', '同樣的事一直重複', 'The same thing keeps repeating'),
        _Word('提不起勁', 'Flat', '知道該做但動不了', 'I know I should, and I cannot'),
        _Word('麻木', 'Numb', '什麼感覺都很淡', 'Everything feels muted'),
      ],
    ),
    _EmotionGroup(
      '有壓力', 'Pressured', Icons.compress_outlined,
      Color(0xFF41A8C8),
      [
        _Word('不知所措', 'Overwhelmed', '太多事一起來', 'Too much at once'),
        _Word('被逼著走', 'Pushed', '沒有選擇的感覺', 'It feels like I have no choice'),
        _Word('怕做不好', 'Afraid to fail', '怕辜負誰的期待', 'Afraid of letting someone down'),
        _Word('喘不過氣', 'Suffocated', '連休息都覺得有罪惡感', 'Even resting feels wrong'),
      ],
    ),
    _EmotionGroup(
      '還可以', 'Okay', Icons.wb_twilight_outlined,
      Color(0xFF41C86F),
      [
        _Word('平靜', 'Calm', '沒什麼特別的，那也很好', 'Nothing special, and that is fine'),
        _Word('放鬆', 'At ease', '肩膀鬆下來了', 'My shoulders dropped'),
        _Word('有點期待', 'Looking forward', '有件事在前面等著', 'Something is waiting ahead'),
        _Word('感謝', 'Grateful', '有人做了什麼讓你記得', 'Someone did something I remember'),
      ],
    ),
  ];

  Future<void> _save(String word) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('emotion_log');
      final list = raw == null ? <dynamic>[] : jsonDecode(raw) as List<dynamic>;
      list.insert(0, {
        'at': DateTime.now().toIso8601String(),
        'word': word,
      });
      await prefs.setString('emotion_log', jsonEncode(list.take(60).toList()));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    final zh = copy.isZhTw;
    final onCard = HSLColor.fromColor(_accent)
        .withSaturation(1.0).withLightness(0.22).toColor();
    final onSoft = HSLColor.fromColor(_accent)
        .withSaturation(0.85).withLightness(0.38).toColor();

    return Scaffold(
      backgroundColor:
          Color.alphaBlend(_accent.withValues(alpha: 0.04), Colors.white),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          zh ? '情緒詞彙庫' : 'Emotion Dictionary',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: onCard),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(
            zh
                ? '先選一個大概的方向，再往下找更準的詞。'
                : 'Pick a rough direction, then look for the closer word.',
            style: TextStyle(fontSize: 14, height: 1.7, color: onSoft),
          ),
          const SizedBox(height: 18),
          for (var gi = 0; gi < _groups.length; gi++) ...[
            _groupTile(gi, zh),
            const SizedBox(height: 12),
          ],
          if (_picked != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _accent.withValues(alpha: 0.30)),
              ),
              child: Text(
                zh
                    ? '記下來了：$_picked\n講得出來的情緒比較好處理。'
                    : 'Noted: $_picked\nA feeling you can name is easier to work with.',
                style: TextStyle(fontSize: 14, height: 1.7, color: onCard),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _groupTile(int gi, bool zh) {
    final g = _groups[gi];
    final isOpen = _open == gi;
    final gOn = HSLColor.fromColor(g.color)
        .withSaturation(1.0).withLightness(0.22).toColor();
    final gSoft = HSLColor.fromColor(g.color)
        .withSaturation(0.85).withLightness(0.38).toColor();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: g.color.withValues(alpha: isOpen ? 0.45 : 0.24), width: 2),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _open = isOpen ? null : gi),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: g.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(g.icon, size: 19, color: g.color),
                  ),
                  const SizedBox(width: 13),
                  Text(
                    zh ? g.zh : g.en,
                    style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        color: gOn),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: gSoft, size: 22),
                  ),
                ],
              ),
            ),
          ),
          if (isOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                children: [
                  for (final w in g.words)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: () async {
                          final word = zh ? w.zh : w.en;
                          await _save(word);
                          if (mounted) setState(() => _picked = word);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                          decoration: BoxDecoration(
                            color: g.color.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                zh ? w.zh : w.en,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: gOn),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                zh ? w.zhWhen : w.enWhen,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.5,
                                    color: gSoft),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmotionGroup {
  const _EmotionGroup(this.zh, this.en, this.icon, this.color, this.words);
  final String zh;
  final String en;
  final IconData icon;
  final Color color;
  final List<_Word> words;
}

class _Word {
  const _Word(this.zh, this.en, this.zhWhen, this.enWhen);
  final String zh;
  final String en;
  final String zhWhen;
  final String enWhen;
}
