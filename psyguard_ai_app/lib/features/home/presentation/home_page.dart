import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../core/widgets/lii_bottom_nav.dart';
import 'encouragement_banner.dart';
import '../../ers/silence_detector.dart';
import '../../ers/cumulative_risk_engine.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/background_theme_service.dart';
import '../../../core/theme/mood_theme_service.dart';
import 'package:go_router/go_router.dart';

import '../../../core/risk_engine/risk_models.dart';
import '../../../core/risk_engine/risk_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/storage/database_provider.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/widgets/app_brand_icon.dart';
import '../../../core/widgets/floating_app_brand.dart';
import '../../../core/widgets/mood_fall_overlay.dart';
import '../../../core/widgets/floating_pacer.dart';
import '../../../core/widgets/snow_cap.dart';
import '../../../core/widgets/paw_tap.dart';
import '../../../core/widgets/fish_pond.dart';
import '../../../core/widgets/pet_reminder_bubble.dart';
import '../../../core/widgets/penguin_nest.dart';
import '../../../core/widgets/beach_corner.dart';
import '../../../core/widgets/hongbao_layer.dart';
import '../../../core/widgets/micro_shake.dart';
import '../../../core/widgets/tooltip_bubble.dart';
import '../../../core/widgets/brand_loading_indicator.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../l10n/app_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/lii_breath_entry.dart';
import '../../../core/widgets/luna_orb.dart';
import 'dart:io';
import '../../../core/crystals/crystal_collection_page.dart';
import '../../bookmark/presentation/bookmark_page.dart'
    show kBookmarkBgColors, kBookmarkBgImages;

// ─────────────────────────────────────────────────────────
// PACER 底色濃度。改這三個數字就能調「底色蓋住背景圖」的程度。
//   0x00 = 全透明（只看得到背景圖）
//   0xFF = 全不透明（背景圖完全看不到）
// 目前：上 0.10 → 中 0.20 → 下 0.35（淺上深下）
// 覺得底色太淡就三個一起往上加，太濃就往下減。
// ─────────────────────────────────────────────────────────
const int kTintTop = 0x1A;    // 0.10
const int kTintMid = 0x33;    // 0.20
const int kTintBottom = 0x59; // 0.35

// ─────────────────────────────────────────────────────────
// 六色各自的預設背景圖（沒有自選圖片時才會用到）。
// 想換圖就改這裡的檔名，記得圖要放在 assets/images/ 底下。
// ─────────────────────────────────────────────────────────
const Map<GlassTone, String> kToneBg = {
  GlassTone.ice: 'assets/images/night_scenic.png',      // 夜空
  GlassTone.sea: 'assets/images/ocean_bg.jpeg',         // 海底
  GlassTone.amethyst: 'assets/images/bg_penguin.jpeg',  // 企鵝
  GlassTone.amber: 'assets/images/coral_bg.jpeg',       // 珊瑚
  GlassTone.moss: 'assets/images/bg_otter.jpeg',        // 水獺
  GlassTone.dawn: 'assets/images/bg_capybara.jpeg',     // 水豚
};

class HomeDashboard {
  HomeDashboard({
    required this.todayCheckin,
    required this.todaySleep,
    required this.todayCheckinRisk,
    required this.latestRisk,
    required this.recentNotes,
    required this.cumulativeCount,
    required this.ersScore,
  });

  final DailyCheckin? todayCheckin;
  final SleepLog? todaySleep;
  final RiskSnapshotResult? todayCheckinRisk;
  final RiskSnapshot? latestRisk;
  final List<String> recentNotes;

  // CUM_IN_PROVIDER 累積紅燈次數。以前是 _HomeContentState 的 local
  // state，抓一次就不動 -> 表情顏色永遠不更新。搬進來跟大家一起抓。
  final int cumulativeCount;

  // ERS_UNIFIED 全 app 共用的那個分數（last_ers_score）。
  // 以前首頁自己用 riskEngine 另外算一套，跟彈窗/snackbar 對不起來。
  final int ersScore;
}

// AUTO_REFRESH autoDispose = 沒人看就丟掉，回首頁時重抓。
// 這樣在 check-in 存完心情，回來首頁就會是新的，不用滑掉重開。
final homeDashboardProvider =
    FutureProvider.autoDispose<HomeDashboard>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final riskEngine = ref.read(riskEngineProvider);
  final since = DateTime.now().subtract(const Duration(days: 3));
  final messages = await db.getMessagesSince(since);
  final checkins = await db.getCheckinsSince(since);
  final todayCheckin = await db.getTodayCheckin();
  final cumulativeCount = await CumulativeRiskEngine().getRedCount();
  final prefs = await SharedPreferences.getInstance();
  final ersScore = (prefs.getDouble('last_ers_score') ?? 20).floor();
  final notes = <String>[
    ...messages.map((m) => m.content),
    ...checkins.where((c) => c.note != null).map((c) => c.note!),
  ];

  return HomeDashboard(
    todayCheckin: todayCheckin,
    todaySleep: await db.getTodaySleepLog(),
    todayCheckinRisk: todayCheckin == null
        ? null
        : riskEngine.evaluateCheckin(
            moodScore: todayCheckin.moodScore,
            stressScore: todayCheckin.stressScore,
            energyScore: todayCheckin.energyScore,
          ),
    latestRisk: await db.getLatestRiskSnapshot(),
    cumulativeCount: cumulativeCount,
    ersScore: ersScore,
    recentNotes: notes,
  );
});

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(homeDashboardProvider);
    final theme = Theme.of(context);
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));

    // Dynamic greeting
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? copy.goodMorning
        : (hour < 18 ? copy.goodAfternoon : copy.goodEvening);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: LumiTheme.background,
      ),
      child: Scaffold(
        bottomNavigationBar: LiiBottomNav(
          isZh: copy.isZhTw,
          current: LiiTab.home,
        ),
        backgroundColor: (() {
          final moodIsDark = ref.watch(backgroundThemeProvider).mode == BgMode.dark;
          final moodColor = ref.watch(moodThemeProvider).backgroundColorFor(moodIsDark);
          if (moodColor.a != 0) return moodColor; // 有選氛圍（非「無」），優先使用
          return ref.watch(backgroundThemeProvider).backgroundColor; // 沒選氛圍，回到深淺模式
        })(),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 76,
          centerTitle: true,
          title: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: FloatingAppBrandIcon(size: 66),
          ),
        ),
        body: PawTapLayer(
          child: Stack(
          children: [
            // ☀️ 夏天全頁魚池（視覺層，墊在卡片後面）
            const Positioned.fill(child: FishVisualLayer()),
            // 原本的首頁內容
            Positioned.fill(
              child: dashboard.when(
                data: (data) => _HomeContent(
                  data: data,
                  greeting: greeting,
                  theme: theme,
                  copy: copy,
                ),
                loading: () =>
                    Center(child: BrandLoadingIndicator(message: copy.loading)),
                error: (error, stack) =>
                    Center(child: Text(copy.loadFailed(error))),
              ),
            ),
            // 氛圍飄落動畫圖層（IgnorePointer，不會擋到任何互動）
            Positioned.fill(
              child: MoodFallOverlay(
                controller: ref.watch(moodFallControllerProvider),
                effect: ref.watch(moodThemeProvider).fallEffect,
              ),
            ),
            // 🧧 過年紅包（點了開金額、灑金幣鈔票）
            const Positioned.fill(child: HongbaoLayer()),
            // ☀️ 魚與籃球的觸控層（只有魚/球位置攔截手指，其他全穿透）
            const Positioned.fill(child: FishTouchLayer()),
            // ❄️ 冰霜觸碰層（手碰到哪就結冰，不擋操作）
            // LII_BREATH_ENTRY 🌙 lii 呼吸入口（自己輕輕呼吸，點下去進呼吸會話）
            Positioned.fill(
              // LII_BREATH_MOOD 呼吸頻率跟著「當天」的 check-in 走。
              // 沒有分數就傳 null，_open() 會退回 calm。
              child: Consumer(builder: (context, ref, _) {
                final c = ref.watch(homeDashboardProvider).valueOrNull
                    ?.todayCheckin;
                // BREATH_ERS 傳 ERS 進去，呼吸節奏才會跟紅黃綠一致
                final ers = ref.watch(homeDashboardProvider).valueOrNull
                    ?.ersScore;
                return LiiBreathButton(
                  mood: c?.moodScore,
                  stress: c?.stressScore,
                  energy: c?.energyScore,
                  ersScore: ers,
                );
              }),
            ),
            // CRYSTAL_BOX 水晶收藏的獨立入口。跟球分開，
            // 有自己的手勢，不會跟拖曳/縮放/切換互搶。
            Positioned(
              right: 20,
              bottom: 28,
              child: GestureDetector(
                onTap: () => showCrystalCollection(context),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xE616264C),
                    border: Border.all(
                        color: const Color(0x66FFD166), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 8,
                          offset: Offset(0, 3)),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome,
                      size: 20, color: Color(0xFFFFD166)),
                ),
              ),
            ),
          ],
        ),
        ),
        drawer: _buildDrawer(context, copy),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AppStrings copy) {
    final zh = copy.isZhTw;
    final items = <(String, String, IconData)>[
      ('/home', copy.navHome, Icons.home_rounded),
      ('#', zh ? '每日紀錄' : 'Daily', Icons.circle),
      ('/dashboard', zh ? '儀表板' : 'Dashboard', Icons.dashboard_rounded),
      ('/checkin', copy.navCheckin, Icons.edit_note_rounded),
      ('/sleep', copy.navSleep, Icons.bedtime_rounded),
      ('/trends', copy.navTrends, Icons.timeline_rounded),
      ('/calendar-overview', zh ? '月曆總覽' : 'Calendar', Icons.calendar_month_rounded),
      ('#', zh ? '練習工具' : 'Practice', Icons.circle),
      ('/chat', copy.navChat, Icons.forum_outlined),
      ('/thought-coach', zh ? '思考教練' : 'Thought Coach', Icons.psychology_rounded),
      ('/distortion-quiz', zh ? '你常掉進哪一個' : 'Thinking Traps', Icons.quiz_rounded),
      ('/tools', copy.navTools, Icons.style_rounded),
      ('#', zh ? '安靜的地方' : 'Quiet', Icons.circle),
      ('/hope-box', zh ? '🌙 希望盒' : '🌙 Hope Box', Icons.auto_awesome_rounded),
      ('/bookmark', zh ? '📑 我的 Pacers' : '📑 My Pacers', Icons.bookmark_rounded),
      ('/weekly-persona', zh ? '本週人設' : 'Weekly Persona', Icons.pets_rounded),
      ('#', zh ? '報告' : 'Reports', Icons.circle),
      ('/ai_report', zh ? 'AI 報告' : 'AI Report', Icons.description_rounded),
      ('/ai_history', zh ? 'AI 歷史' : 'AI History', Icons.history_rounded),
      ('/api-usage', zh ? 'API 用量' : 'API Usage', Icons.data_usage_rounded),
      ('#', zh ? '其他' : 'More', Icons.circle),
      ('/safety', copy.navSafety, Icons.health_and_safety_rounded),
      ('/voice', zh ? '語音' : 'Voice', Icons.mic_rounded),
      ('/export', copy.navExport, Icons.download_rounded),
      ('/settings', copy.navSettings, Icons.settings_rounded),
      ('/about', zh ? '關於與聲明' : 'About & Statement', Icons.info_outline_rounded),
    ];

    return Drawer(
      backgroundColor: const Color(0xFFF9F9F8),
      surfaceTintColor: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/lii_ball.png',
                  width: 52,
                  height: 52,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: items.map((item) {
                if (item.$1 == '#') {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
                    child: Text(item.$2,
                        style: GoogleFonts.nunitoSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: LumiTheme.textSecondary)),
                  );
                }
                final currentRoute = GoRouterState.of(context).uri.toString();
                final isActive = currentRoute == item.$1;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: isActive
                        ? LumiTheme.primary.withValues(alpha: 0.1)
                        : null,
                    leading: Icon(
                      item.$3,
                      color: isActive
                          ? LumiTheme.primary
                          : LumiTheme.textSecondary,
                    ),
                    title: Text(
                      item.$2,
                      style: GoogleFonts.nunitoSans(
                        color: isActive
                            ? LumiTheme.primary
                            : LumiTheme.textPrimary,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      context.push(item.$1);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Home Content (StatefulWidget for animations) ────────────────────
class _HomeContent extends StatefulWidget {
  const _HomeContent({
    required this.data,
    required this.greeting,
    required this.theme,
    required this.copy,
  });

  final HomeDashboard data;
  final String greeting;
  final ThemeData theme;
  final AppStrings copy;

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  String _homePetType = 'otter';

  Future<void> _maybeShowDailyPacer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 使用者可以關掉推播。18 位試用者裡有 2 位說「以前的話跳出來可能更難過」——
      // 推播是唯一會主動打斷人的功能，必須留一個關得掉的開關。
      if (prefs.getBool('daily_pacer_on') == false) return;
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month}-${now.day}';
      const kAlwaysShow = true; if (kAlwaysShow == false && prefs.getString('daily_pacer_date') == todayStr) return;
      final raw = prefs.getString('bookmarks_v2');
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List;
      if (list.isEmpty) return;
      // DAILY_SWIPE 抽一疊，可以左右滑
      final all = list.cast<Map<String, dynamic>>()
          .where((e) => ((e['quote'] as String?) ?? '').isNotEmpty)
          .toList();
      if (all.isEmpty) return;
      all.shuffle(math.Random());
      final deck = all.take(5).toList();
      await prefs.setString('daily_pacer_date', todayStr);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => Consumer(
          builder: (c, r, _) {
            final zh =
                AppStrings.of(r.watch(appLanguageControllerProvider)).isZhTw;
            return _dailyPacerCard(ctx, deck, zh);
          },
        ),
      );
    } catch (_) {}
  }

  Widget _dailyPacerCard(
      BuildContext ctx, List<Map<String, dynamic>> deck, bool zh) {
    // 不用 Dialog —— 它會攔掉水平手勢，PageView 就滑不動了。
    // 改用透明的 Material 直接鋪在遮罩上。
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 500,
              child: PageView.builder(
                itemCount: deck.length,
                controller: PageController(viewportFraction: 0.88),
                itemBuilder: (c, i) => Center(
                  child: _DailyCableCard(
                    key: ValueKey('daily_$i'),
                    data: deck[i],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              zh ? '\u2190 左右滑看更多' : '\u2190 swipe for more',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(zh ? '收起來' : 'Got it',
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            // 在被打斷的當下就能關掉 —— 會想關的人正是此刻覺得不舒服的人，
            // 比叫他去設定裡找準確得多。
            TextButton(
              onPressed: () async {
                final p = await SharedPreferences.getInstance();
                await p.setBool('daily_pacer_on', false);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(
                zh ? '不要再自動跳出' : 'Stop showing this',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pt = prefs.getString('pet_type') ?? 'otter';
      if (mounted) setState(() => _homePetType = pt);
    } catch (_) {}
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowDailyPacer());
    await SilenceDetector().recordActivity();
    // CUM_IN_PROVIDER 累積次數改由 provider 提供，這裡不用再查一次
    final alert = await SilenceDetector().checkSilence();
    if (mounted) {
      if (alert != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🌙', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  Text(alert.messageFor(widget.copy.isZhTw),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(widget.copy.isZhTw ? '我在' : "I'm here"),
                  ),
                ],
              ),
            ),
          );
        });
      }
    }
  }
  // Bold logic: check recent notes for negative keywords
  bool get _hasNegativeSignal {
    final notes = widget.data.recentNotes.join(' ');
    return LumiTheme.negativeKeywords.any((kw) => notes.contains(kw));
  }

  // ERS_UNIFIED 改讀 ERS，跟 snackbar / 彈窗 / dashboard 同一個數字。
  // 門檻在 LumiTheme.riskColor：<=40 綠 / 41-70 黃 / >70 紅
  int get _riskScore => widget.data.ersScore;
  String get _riskLevel =>
      widget.data.todayCheckinRisk?.riskLevelKey ??
      widget.data.latestRisk?.riskLevel ??
      'low';
  bool get _isHighRisk => _riskScore >= 70;
  IconData get _statusIcon => switch (_riskLevel) {
    'high' => Icons.sentiment_very_dissatisfied_rounded,
    'medium' => Icons.sentiment_neutral_rounded,
    _ => Icons.sentiment_very_satisfied_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final copy = widget.copy;
    final engine = CumulativeRiskEngine();
    // CUM_IN_PROVIDER 改讀 provider 的值，不再用永遠不會變的 local state
    final cumCount = widget.data.cumulativeCount;
    // COLOR_TODAY 顏色只看「當天」的分數（<=40 綠 / 41-70 黃 / >70 紅）。
    // 以前只要累積過紅燈就整個蓋掉，今天填黃色也會顯示紅色。
    // 累積的嚴重程度改由底下的 riskLabel 文字表達。
    final riskColor = LumiTheme.riskColor(_riskScore);
    // ERS_LABEL 文字也跟著 ERS，跟上面的顏色用同一組門檻。
    // 以前讀的是累積紅燈次數，所以 ERS 68（黃）還是寫 Doing okay。
    final riskLabel = _riskScore <= 40
        ? copy.statusGood
        : (_riskScore <= 70 ? copy.statusCare : copy.statusSupport);

    final exploreCards = [
      _cardData(
        copy.navCheckin,
        copy.emotionalRelease,
        Icons.edit_note_rounded,
        const Color(0xFFC85341),
        '/checkin',
        copy.isZhTw
            ? '把心裡的感受寫下來，讓自己慢慢看見、慢慢理解。'
            : 'Write down what you feel so you can see and understand it more gently.',
      ),
      _cardData(
        copy.trendsTitle,
        copy.healthDataTrends,
        Icons.favorite_rounded,
        const Color(0xFFC88D41),
        '/trends',
        copy.isZhTw
            ? '用溫柔的方式，看見你的變化，一步步找回自己的節奏。'
            : 'See your changes gently and find your rhythm step by step.',
      ),
      _cardData(
        copy.navChat,
        copy.supportiveChat,
        Icons.forum_outlined,
        const Color(0xFFC8C741),
        '/chat',
        copy.isZhTw
            ? '不用整理好再說，想到什麼就寫什麼。'
            : "You don't have to organise it first. Just write.",
      ),
      _cardData(
        copy.navSleep,
        copy.sleepStatus,
        Icons.bedtime_outlined,
        const Color(0xFF8FC841),
        '/sleep',
        copy.isZhTw
            ? '看見每晚的睡眠變化，慢慢找回適合自己的作息節奏。'
            : 'Track nightly sleep changes and rebuild a rhythm that fits you.',
      ),
      _cardData(
        copy.isZhTw ? '年度總覽' : 'Year Overview',
        copy.isZhTw ? '重點行事曆' : 'Key Calendar',
        Icons.calendar_month_rounded,
        const Color(0xFF56C841),
        '/calendar-overview',
        copy.isZhTw
            ? '一眼看見全年重要事項，紅色緊急、黃色重要，一目了然。'
            : 'See all important items at a glance — red for urgent, yellow for important.',
      ),
      _cardData(
        copy.isZhTw ? '我的專屬格言' : 'My Quote Cards',
        copy.isZhTw ? '手作暖話卡' : 'Make your own',
        Icons.auto_awesome_rounded,
        const Color(0xFF41C866),
        '/my-cards',
        copy.isZhTw
            ? '自己做暖話卡：選底色、字體、加照片，寫下屬於你的格言。'
            : 'Make your own quote card — pick a color, font, photo, and words.',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const SizedBox(height: 12),
        // ── Greeting ──────────────────────────────────
        // 深色模式時問候語改米白，亮色維持原本深色字
        Consumer(builder: (context, ref, _) {
          final greetingIsDark =
              ref.watch(backgroundThemeProvider).mode == BgMode.dark;
          const cream = Color(0xFFF5F0E6);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.greeting,
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: greetingIsDark ? cream : LumiTheme.textPrimary,
                      ),
                    ),
                  ),
                  const _SunMoonToggle(),
                ],
              ),
              Text(
                copy.peacefulDay,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: greetingIsDark
                      ? cream.withValues(alpha: 0.82)
                      : LumiTheme.textSecondary,
                ),
              ),
            ],
          );
        }),
        // 💬 寵物提醒泡泡（沒東西提醒時自己不顯示）
        PetReminderBubble(isZh: copy.isZhTw),
        const SizedBox(height: 32),
        // ── Status Card + Sticky Note + Pet (PageView with arrows) ─────
        _SwipeableCards(
          riskColor: riskColor,
          riskLabel: riskLabel,
          todayStatus: copy.todayStatus,
          statusIcon: _statusIcon,
          theme: theme,
        ),
        const SizedBox(height: 32),

        if (_isHighRisk) ...[
          MicroShake(
            enabled: true,
            child: _InteractiveCard(
              title: copy.isZhTw ? '行政救援' : 'Emergency Support',
              subtitle: copy.emergencyCase,
              icon: Icons.emergency_rounded,
              color: const Color(0xFFD14343),
              route: '/safety',
              isBold: true,
              isFullWidth: true,
              tooltipTitle: copy.isZhTw ? '行政救援（案號）' : 'Emergency Support',
              tooltipDescription: copy.isZhTw
                  ? '緊急時刻，為你媒合校園與市府實體資源。'
                  : 'Connect with campus and city support resources in urgent moments.',
            ),
          ),
          const SizedBox(height: 32),
        ],

        // ── 計算「今天的狀態」的四個輸入 ──────────────
        const SizedBox(height: 28),
        Text(
          copy.isZhTw ? '計算「今天的狀態」的四個輸入' : 'The four inputs behind today',
          style: theme.textTheme.titleMedium?.copyWith(
            color: _bgIsDark(context) ? const Color(0xFFD8DEE6) : null,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF4A7FA5).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF4A7FA5).withValues(alpha: 0.22)),
          ),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _InteractiveCard(
                title: copy.isZhTw ? '睡眠紀錄' : 'Sleep Log',
                subtitle: copy.isZhTw ? '昨晚睡得如何' : 'How you slept',
                icon: Icons.nightlight_round,
                color: const Color(0xFF4A7FA5),
                route: '/sleep',
              ),
              _InteractiveCard(
                title: copy.isZhTw ? '心晴筆記' : 'Check-in',
                subtitle: copy.isZhTw ? '寫下今天' : 'Write today down',
                icon: Icons.edit_note_rounded,
                color: const Color(0xFF4A7FA5),
                route: '/checkin',
              ),
              _InteractiveCard(
                title: copy.isZhTw ? '說出來' : 'Talk it out',
                subtitle: copy.isZhTw ? '好好講一段' : 'Say it properly',
                icon: Icons.forum_outlined,
                color: const Color(0xFF4A7FA5),
                route: '/chat',
              ),
              _InteractiveCard(
                title: copy.isZhTw ? '隨手說' : 'Quick voice',
                subtitle: copy.isZhTw ? '一句話也可以' : 'One line is enough',
                icon: Icons.mic_rounded,
                color: const Color(0xFF4A7FA5),
                route: '/voice',
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // ── 今日待辦 ──────────────────────────────────
        const SizedBox(height: 28),
        Text(
          copy.isZhTw ? '今日待辦' : "Today's list",
          style: theme.textTheme.titleMedium?.copyWith(
            color: _bgIsDark(context) ? const Color(0xFFD8DEE6) : null,
          ),
        ),
        const SizedBox(height: 12),
        _InteractiveCard(
          title: copy.isZhTw ? '心晴筆記' : 'Notes',
          subtitle: copy.isZhTw ? '寫下今天' : 'Write today down',
          icon: Icons.checklist_rounded,
          color: const Color(0xFF56C841),
          route: '/checkin',
        ),

        // ── 季節氛圍 ──────────────────────────────────
        const SizedBox(height: 24),
        Row(
          children: [
            const Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: DrinkBarStrip(),
              ),
            ),
            const Spacer(),
            const ChosenDrinkBadge(),
            const HongbaoEnvelope(),
          ],
        ),
        Consumer(builder: (context, ref, _) {
          final m = ref.watch(moodThemeProvider);
          final isWinter = m.fallEffect == FallEffectType.snow;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 750),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: isWinter
                ? KeyedSubtree(
                    key: const ValueKey('penguin-nest'),
                    child: PenguinNestRow(isZh: copy.isZhTw))
                : const KeyedSubtree(
                    key: ValueKey('penguin-empty'),
                    child: SizedBox.shrink(),
                  ),
          );
        }),
        SizedBox(
          height: 120,
          child: Align(
            alignment: Alignment.centerRight,
            child: const SizedBox(
              width: 160,
              height: 120,
              child: _CornerPenguin(),
            ),
          ),
        ),


        const SizedBox(height: 40),
      ],
    );
  }

  Map<String, dynamic> _cardData(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String route,
    String tooltip,
  ) {
    return {
      'title': title,
      'subtitle': subtitle,
      'icon': icon,
      'color': color,
      'route': route,
      'tooltip': tooltip,
    };
  }
}

/// Interactive card with micro-zoom press effect, long-press tooltip,
/// and dynamic bold text.
bool _bgIsDark(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  return container.read(backgroundThemeProvider).mode == BgMode.dark;
}

class _InteractiveCard extends StatefulWidget {
  const _InteractiveCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.isBold = false,
    this.isFullWidth = false,
    this.tooltipTitle,
    this.tooltipDescription,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final bool isBold;
  final bool isFullWidth;
  final String? tooltipTitle;
  final String? tooltipDescription;

  @override
  State<_InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<_InteractiveCard>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    // 白色打底 + 8% 主題色 → 先合成成「不透明」的淡彩白。
    // 關鍵是不透明：深色模式時深藍頁面就透不上來，
    // 卡片永遠維持亮色版的白底淡彩，深色文字才看得清楚。
    final isDark = _bgIsDark(context);
    // 文字＝卡片同色相，飽和度拉滿、亮度壓低
    final hsl = HSLColor.fromColor(widget.color);
    final onCard = hsl
        .withSaturation(1.0)
        .withLightness(0.22)
        .toColor();
    final onCardSoft = hsl
        .withSaturation(0.85)
        .withLightness(0.36)
        .toColor();
    final bgColor = Color.alphaBlend(
      widget.color.withValues(alpha: 0.0),
      Colors.white,
    );

    return SnowCap(
      // 雪系氛圍時，卡片頂端會積雪；按住雪堆用手溫融化它
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          splashFactory: _FastSplash.factory,
          splashColor: widget.color.withValues(alpha: 0.5),
          highlightColor: widget.color.withValues(alpha: 0.25),
          onTap: () async {
            HapticFeedback.lightImpact();
            await Future.delayed(const Duration(milliseconds: 280));
            if (mounted) context.push(widget.route);
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            if (widget.tooltipTitle != null && widget.tooltipDescription != null) {
              showFeatureTooltip(
                context,
                title: widget.tooltipTitle!,
                description: widget.tooltipDescription!,
              );
            }
          },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color.alphaBlend(widget.color.withValues(alpha: 0.22), Colors.white),
                Color.alphaBlend(widget.color.withValues(alpha: 0.34), Colors.white),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(color: widget.color.withValues(alpha: isDark ? 0.62 : 0.40), width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: isDark ? 0.16 : 1.0),
                blurRadius: 8,
                offset: const Offset(-4, -4),
                spreadRadius: -4,
                blurStyle: BlurStyle.inner,
              ),
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.45)
                    : widget.color.withValues(alpha: 0.55),
                blurRadius: 14,
                offset: const Offset(5, 6),
                spreadRadius: -3,
                blurStyle: BlurStyle.inner,
              ),
              BoxShadow(
                color: widget.color.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
            borderRadius: BorderRadius.circular(24),

          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FoxPocket(
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                style: GoogleFonts.nunitoSans(
                  fontSize: 15,
                  fontWeight:
                      widget.isBold ? FontWeight.w600 : FontWeight.w600,
                  color: onCard,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: GoogleFonts.nunitoSans(
                  fontSize: 11,
                  color: onCardSoft,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class StickyNotePage extends StatefulWidget {
  final Color color;
  final Color borderColor;
  final String hintText;
  final String storageKey;
  const StickyNotePage({
    required this.color,
    required this.borderColor,
    required this.hintText,
    required this.storageKey,
  });
  @override
  State<StickyNotePage> createState() => StickyNotePageState();
}

class StickyNotePageState extends State<StickyNotePage> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(widget.storageKey) ?? '';
    if (mounted) setState(() => _ctrl.text = val);
  }

  Future<void> _save(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(widget.storageKey, val);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 14, color: widget.borderColor),
              const SizedBox(width: 6),
              Text('✏️', style: TextStyle(fontSize: 12, color: widget.borderColor)),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: TextField(
              controller: _ctrl,
              maxLines: null,
                  onTap: () {},
              style: const TextStyle(fontSize: 13, height: 1.6),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: TextStyle(color: widget.borderColor.withOpacity(0.6), fontSize: 13),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _save,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeableCards extends StatefulWidget {
  final Color riskColor;
  final String riskLabel;
  final String todayStatus;
  final IconData statusIcon;
  final ThemeData theme;

  const _SwipeableCards({
    required this.riskColor,
    required this.riskLabel,
    required this.todayStatus,
    required this.statusIcon,
    required this.theme,
  });

  @override
  State<_SwipeableCards> createState() => _SwipeableCardsState();
}

class _SwipeableCardsState extends State<_SwipeableCards> {
  final PageController _ctrl = PageController();
  int _page = 0;
  String _petName = '';

  @override
  void initState() {
    super.initState();
    _loadPet();
  }

  Future<void> _loadPet() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _petName = 'Luna';
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = 4;
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              // 頁1：狀態卡片
              Consumer(
                builder: (context, ref, _) {
                  final isDark = ref.watch(backgroundThemeProvider).mode == BgMode.dark;
                  return Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    Color.alphaBlend(const Color(0xFF7A8FA6).withValues(alpha: 0.05), const Color(0xFF16202F)),
                                    Color.alphaBlend(const Color(0xFF7A8FA6).withValues(alpha: 0.12), const Color(0xFF0E1522)),
                                  ]
                                : [
                                    Colors.white,
                                    Color.alphaBlend(widget.riskColor.withValues(alpha: 0.30), Colors.white),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? const Color(0xFF7A8FA6).withValues(alpha: 0.3) : widget.riskColor.withValues(alpha: 0.42),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.transparent : isDark ? Colors.transparent : widget.riskColor.withValues(alpha: 0.10),
                              blurRadius: 16,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: widget.riskColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(widget.statusIcon, color: widget.riskColor, size: 30),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(widget.riskLabel,
                                    style: widget.theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFFEDF3F8)
                                          : LumiTheme.textPrimary,
                                    )),
                                  const SizedBox(height: 4),
                                  Text(widget.todayStatus,
                                    style: widget.theme.textTheme.bodyMedium?.copyWith(
                                      color: isDark
                                          ? const Color(0xFFA8BACB)
                                          : null,
                                    )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              // 頁2：寵物卡片
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Color(0xFFDCEBF7)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: const Color(0xFF4A7FA5).withValues(alpha: 0.42), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A7FA5).withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Center(
                        child: Image.asset(
                          'assets/images/lii_ball.png',
                          width: 56,
                          height: 56,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_petName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C5282),
                          )),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0ABFBC).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Consumer(builder: (context, ref, _) {
                            final zh = AppStrings.of(ref.watch(appLanguageControllerProvider)).isZhTw;
                            return Text(
                              zh ? '一直都在' : 'Always here',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF0ABFBC)),
                            );
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 頁3：桃紅便條紙
              StickyNotePage(
                color: const Color(0xFFFFE4EC),
                borderColor: const Color(0xFFFFB3C6),
                hintText: 'Jot anything down... 🌸',
                storageKey: 'sticky_pink',
              ),
              // 頁4：薄荷綠便條紙
              StickyNotePage(
                color: const Color(0xFFE4F9F0),
                borderColor: const Color(0xFF9FDEBD),
                hintText: 'Key priorities today... 🌿',
                storageKey: 'sticky_mint',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 頁面指示點 + 箭頭
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
              color: _page > 0 ? const Color(0xFF0ABFBC) : Colors.grey.shade300,
              onPressed: _page > 0 ? () => _ctrl.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ) : null,
            ),
            Row(
              children: List.generate(pages, (i) => Container(
                width: 6, height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _page ? const Color(0xFF0ABFBC) : Colors.grey.shade300,
                ),
              )),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              color: _page < pages - 1 ? const Color(0xFF0ABFBC) : Colors.grey.shade300,
              onPressed: _page < pages - 1 ? () => _ctrl.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _SunMoonToggle extends ConsumerWidget {
  const _SunMoonToggle();

  void _showColorPicker(BuildContext context, WidgetRef ref, bool isDark) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final options = isDark
            ? [
                (BgColorChoice.navyDark, '深藍', const Color(0xFF0D1B2A)),
                (BgColorChoice.forestDark, '深墨綠', const Color(0xFF0D2818)),
              ]
            : [
                (BgColorChoice.blueLight, '淺藍', const Color(0xFFE3F2FD)),
                (BgColorChoice.greenLight, '淺綠', const Color(0xFFE8F5E9)),
              ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppStrings.of(ref.watch(appLanguageControllerProvider)).isZhTw ? '選擇底色' : 'Pick a background', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: options.map((opt) {
                    return GestureDetector(
                      onTap: () {
                        ref.read(backgroundThemeProvider.notifier).setColor(opt.$1);
                        Navigator.pop(ctx);
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: opt.$3,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300, width: 1.5),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(opt.$2, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(backgroundThemeProvider);
    final isDark = themeState.mode == BgMode.dark;

    return GestureDetector(
      onTap: () => ref.read(backgroundThemeProvider.notifier).toggleMode(),
      onLongPress: () => _showColorPicker(context, ref, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 280),
              opacity: isDark ? 0.25 : 1.0,
              child: const Icon(Icons.wb_sunny_rounded, size: 20, color: Color(0xFFF5A623)),
            ),
            const SizedBox(width: 4),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 280),
              opacity: isDark ? 1.0 : 0.25,
              child: const Icon(Icons.nightlight_round, size: 18, color: Color(0xFFC8E8FF)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 年度總覽旁的空位：雪系氛圍（冬/聖誕/寒假）時，工程師企鵝會來這裡窩著。
/// 點他會開心蹦跳一下；其他氛圍時維持原本的空位。
class _CornerPenguin extends ConsumerStatefulWidget {
  const _CornerPenguin();

  @override
  ConsumerState<_CornerPenguin> createState() => _CornerPenguinState();
}

class _CornerPenguinState extends ConsumerState<_CornerPenguin>
    with TickerProviderStateMixin {
  late final AnimationController _sway; // 平常微微搖晃
  late final AnimationController _bounce; // 點擊蹦跳
  // 🥚 蛋改由 penguinNest（core/widgets/penguin_nest.dart）統一管理，
  //    這樣巢窩那邊看得到同一份資料，也能存檔。

  @override
  void initState() {
    super.initState();
    penguinNest.addListener(_onNestChanged);
    penguinNest.load();
    _sway = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
  }

  @override
  void dispose() {
    penguinNest.removeListener(_onNestChanged);
    _sway.dispose();
    _bounce.dispose();
    super.dispose();
  }

  void _onNestChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mood = ref.watch(moodThemeProvider);
    final effect = mood.fallEffect;
    if (mood == MoodTheme.christmas) {
      return const _OrnamentCatCorner(); // 🎄 掛飾裡的貓
    }
    if (mood == MoodTheme.winterBreak) {
      return const _SnowmanCorner(); // 🧣 一起堆雪人
    }
    if (mood == MoodTheme.newYear) {
      return const _NyDragonsCorner(); // 🧧 小龍賀歲
    }
    if (mood == MoodTheme.spring) {
      return const _EasterBunnyCorner(); // 🐰 復活節兔兔
    }
    if (mood == MoodTheme.summer) {
      return const SummerBeachCorner(); // ☀️ 海灘上的墨鏡貓與兔兔
    }
    if (mood == MoodTheme.summerBreak) {
      return const DrinkBarCorner(); // 🏖️ 排球男孩＋飲料吧
    }
    if (effect != FallEffectType.snow && effect != FallEffectType.leaves) {
      return const SizedBox.shrink(); // 沒有對應吉祥物的氛圍：維持空位
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _bounce.forward(from: 0);
        if (effect == FallEffectType.snow) {
          // ❄️ 企鵝生蛋！滿 5 顆會在「更多功能」上方展開巢窩開始孵化
          penguinNest.layEgg(-0.8 + math.Random().nextDouble() * 1.6);
        }
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([_sway, _bounce]),
        builder: (context, child) {
          final swayAngle = (_sway.value - 0.5) * 0.06; // 微微左右搖
          final jump = math.sin(_bounce.value * math.pi) * 12; // 蹦跳高度
          final squash = 1 + math.sin(_bounce.value * math.pi * 2) * 0.04;
          return Transform.translate(
            offset: Offset(0, -jump),
            child: Transform.rotate(
              angle: swayAngle,
              child: Transform.scale(scaleY: squash, child: child),
            ),
          );
        },
        child: effect == FallEffectType.snow
            // ❄️ 孵完 → 這一格換成冰屋（igloo），不再單獨掛在中間
            ? (penguinNest.stage == NestStage.done
                ? AspectRatio(
                    aspectRatio: 1.15,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/igloo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('🛖', style: TextStyle(fontSize: 48)),
                        ),
                      ),
                    ),
                  )
                // ❄️ 冬系：工程師企鵝（點他會生蛋）
                : Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/images/mood_penguin.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('🐧', style: TextStyle(fontSize: 48)),
                      ),
                    ),
                  ),
                  // 🥚 生下來的蛋排在腳邊
                  if (penguinNest.stage == NestStage.filling)
                    for (int i = 0; i < penguinNest.eggs.length; i++)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment(penguinNest.eggs[i], 1.0),
                        child: Container(
                          width: 13,
                          height: 17,
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFDF6),
                            borderRadius: const BorderRadius.all(
                                Radius.elliptical(7, 9)),
                            border: Border.all(
                                color: const Color(0xFFD8CDB8), width: 1),
                          ),
                        ),
                      ),
                    ),
                ],
              ))
            // 🍁 秋：燈下讀書狐狸 —— 用 AspectRatio 鎖成格子比例、cover 填滿，
            //         這樣圖片比例不符時也乖乖待在格子裡，不會凸出去
            : AspectRatio(
                aspectRatio: 1.15,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/mood_fox_lamp.jpg',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('🦊', style: TextStyle(fontSize: 48)),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// 🎄 聖誕角落：掛飾裡的貓，像吊飾一樣輕輕搖擺，點他會叮一下。
class _OrnamentCatCorner extends StatefulWidget {
  const _OrnamentCatCorner();

  @override
  State<_OrnamentCatCorner> createState() => _OrnamentCatCornerState();
}

class _OrnamentCatCornerState extends State<_OrnamentCatCorner>
    with TickerProviderStateMixin {
  late final AnimationController _swing;
  late final AnimationController _jingle;

  @override
  void initState() {
    super.initState();
    _swing = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _jingle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _swing.dispose();
    _jingle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 包一層 PawFreeZone：戳貓咪與貓貓球時不會出現貓掌
    return PawFreeZone(child: _buildOrnament());
  }

  Widget _buildOrnament() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _jingle.forward(from: 0); // 點貓或球，吊飾都會叮一下
      },
      child: Row(
        children: [
          // 貓貓球（加大版），只有吊飾在搖擺
          Expanded(
            flex: 11,
            child: ListenableBuilder(
              listenable: Listenable.merge([_swing, _jingle]),
              builder: (context, child) {
                final swing = (_swing.value - 0.5) * 0.16;
                final jingle = math.sin(_jingle.value * math.pi * 3) *
                    (1 - _jingle.value) *
                    0.2;
                return Transform.rotate(
                  angle: swing + jingle,
                  alignment: Alignment.topCenter,
                  child: child,
                );
              },
              child: Transform.scale(
                scale: 0.9,
                alignment: Alignment.topCenter,
                child: Image.asset(
                  'assets/images/mood_ornament_cat.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('🐱', style: TextStyle(fontSize: 44)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 0), // 貓和毛球分開一點
          // 下面坐著橘貓，抬頭盯著貓貓球（放大並往下坐一點）
          Expanded(
            flex: 8,
            child: Transform.translate(
              // 數字越大貓咪越往下；超過 30 左右會畫出卡片外
              offset: const Offset(-26, 0),
              child: Transform.scale(
                scale: 0.9,
                alignment: Alignment.bottomCenter,
                child: Image.asset(
                  'assets/images/mood_xmas_cat.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Text('🐈', style: TextStyle(fontSize: 28)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🧣 寒假角落：跟著下雪一起堆雪人。
/// 點球球下雪一次，雪人就長高一階（大雪球 → 身體＋頭 → 完成！）
/// 堆到第三階，貓咪會蹦出來跟完成的雪人合照。
class _SnowmanCorner extends ConsumerWidget {
  const _SnowmanCorner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 寒假角落：直接顯示聖誕水獺（不再堆雪人）
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Image.asset(
        'assets/images/mood_snowman_cat.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Text('🦦', style: TextStyle(fontSize: 44)),
        ),
      ),
    );
  }
}

class _SnowmanPainter extends CustomPainter {
  _SnowmanPainter({required this.stage});

  final int stage;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final base = size.height * 0.88;
    final body = Paint()..color = const Color(0xFFFAFDFF);
    final outline = Paint()
      ..color = const Color(0xFFBFD8E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    // 第一階：底部大雪球
    final r1 = size.shortestSide * 0.22;
    canvas.drawCircle(Offset(cx, base - r1), r1, body);
    canvas.drawCircle(Offset(cx, base - r1), r1, outline);

    if (stage >= 2) {
      // 第二階：身體 + 頭 + 眼睛
      final r2 = r1 * 0.72;
      final c2 = Offset(cx, base - r1 * 2 - r2 * 0.72);
      canvas.drawCircle(c2, r2, body);
      canvas.drawCircle(c2, r2, outline);
      final r3 = r1 * 0.5;
      final c3 = Offset(cx, c2.dy - r2 - r3 * 0.68);
      canvas.drawCircle(c3, r3, body);
      canvas.drawCircle(c3, r3, outline);
      final eye = Paint()..color = const Color(0xFF4A5A66);
      canvas.drawCircle(Offset(c3.dx - r3 * 0.35, c3.dy - r3 * 0.1), 1.6, eye);
      canvas.drawCircle(Offset(c3.dx + r3 * 0.35, c3.dy - r3 * 0.1), 1.6, eye);
    }
  }

  @override
  bool shouldRepaint(_SnowmanPainter old) => old.stage != stage;
}

/// 🧧 過年角落：小龍們賀歲，點一下會喜氣地晃一晃。
class _NyDragonsCorner extends StatefulWidget {
  const _NyDragonsCorner();

  @override
  State<_NyDragonsCorner> createState() => _NyDragonsCornerState();
}

class _NyDragonsCornerState extends State<_NyDragonsCorner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cheer;

  @override
  void initState() {
    super.initState();
    _cheer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _cheer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _cheer.forward(from: 0);
      },
      child: ListenableBuilder(
        listenable: _cheer,
        builder: (context, child) {
          final t = _cheer.value;
          final wob = math.sin(t * math.pi * 4) * (1 - t) * 0.05;
          final pop = 1 + math.sin(t * math.pi) * 0.05;
          return Transform.scale(
            scale: pop,
            child: Transform.rotate(angle: wob, child: child),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            'assets/images/mood_ny_dragons.jpg',
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('🐉', style: TextStyle(fontSize: 44)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 🌸 春天角落：復活節巧克力兔兔，點一下會開心地晃一晃。
class _EasterBunnyCorner extends StatefulWidget {
  const _EasterBunnyCorner();

  @override
  State<_EasterBunnyCorner> createState() => _EasterBunnyCornerState();
}

class _EasterBunnyCornerState extends State<_EasterBunnyCorner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hop;

  @override
  void initState() {
    super.initState();
    _hop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _hop.forward(from: 0);
      },
      child: ListenableBuilder(
        listenable: _hop,
        builder: (context, child) {
          final t = _hop.value;
          final wob = math.sin(t * math.pi * 4) * (1 - t) * 0.05;
          final hop = math.sin(t * math.pi) * 6; // 兔子式小跳
          return Transform.translate(
            offset: Offset(0, -hop),
            child: Transform.rotate(angle: wob, child: child),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            'assets/images/mood_easter_bunny.jpg',
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('🐰', style: TextStyle(fontSize: 44)),
            ),
          ),
        ),
      ),
    );
  }
}

// DAILY_SWIPE 每日推播的纜車卡：球吊在上面，下面掛那則 pacer
class _DailyCableCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _DailyCableCard({super.key, required this.data});

  @override
  State<_DailyCableCard> createState() => _DailyCableCardState();
}

class _DailyCableCardState extends State<_DailyCableCard> {
  double _t = 1;
  double _pull = 0;

  // 圖片來源的優先順序也跟 My Pacers 一致：
  // 自訂照片 -> 選到的預設背景圖 -> 都沒有就回 null（改用純色底）
  ImageProvider? get _image {
    final d = widget.data;
    final path = (d['customImagePath'] as String?) ?? '';
    if (path.startsWith('b64:')) {
      return MemoryImage(base64Decode(path.substring(4)));
    }
    if (path.isNotEmpty) {
      return FileImage(File(path));
    }
    final ii = (d['imageIndex'] as num?)?.toInt() ?? -1;
    if (ii >= 0) {
      return AssetImage(
          kBookmarkBgImages[ii.clamp(0, kBookmarkBgImages.length - 1)]);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final tone = GlassTone.values[((d['tone'] as num?)?.toInt() ?? 0)
        .clamp(0, GlassTone.values.length - 1)];

    // ORB_FIT 尺寸跟著螢幕算，球才不會爆出對話框（爆出去就摸不到、滑不動）
    final mq = MediaQuery.of(context);
    final w = (mq.size.width * 0.62).clamp(180.0, 250.0);
    final avail = mq.size.height - mq.padding.vertical;
    final h = (w * 1.36).clamp(200.0, avail * 0.52);
    final orb = w * 0.42;

    return LunaCableCar(
      tone: tone,
      childWidth: w,
      childHeight: h,
      orbSize: orb,
      ropeLen: 12,
      interactive: true,
      t: _t,
      pull: _pull,
      onChanged: (nt, np) => setState(() {
        _t = nt;
        _pull = np;
      }),
      child: _car(tone, _t),
    );
  }

  Widget _car(GlassTone tone, double t) {
    final d = widget.data;
    final quote = (d['quote'] as String?) ?? '';
    final author = (d['author'] as String?) ?? '';
    final ci = (d['colorIndex'] as num?)?.toInt() ?? 0;
    final img = _image;
    // 取當前水晶的最深色階，卡片和球才是一套
    final deep = tone.stops.last;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: img == null
            ? kBookmarkBgColors[ci.clamp(0, kBookmarkBgColors.length - 1)]
            : null,
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: const [
          BoxShadow(
              color: Colors.black38, blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 照片跟著文字一起浮現
            if (img != null)
              Opacity(
                opacity: (0.18 + 0.82 * t).clamp(0.0, 1.0),
                child: Image(image: img, fit: BoxFit.cover),
              ),
            // 沒有邊界的染色：從底部往上化開，越上面越透明
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    deep.withAlpha(0x00),
                    deep.withAlpha(0x59),
                    deep.withAlpha(0xC4),
                    deep.withAlpha(0xE0),
                  ],
                  stops: const [0.34, 0.58, 0.84, 1.0],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LunaReveal(
                      text: quote,
                      progress: t,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.55,
                        shadows: [
                          Shadow(blurRadius: 8, color: Colors.black87),
                          Shadow(blurRadius: 3, color: Colors.black87),
                        ],
                      ),
                    ),
                    if (author.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '\u2014 $author',
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Color(0xE6FFFFFF),
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black87),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 320ms 的漣漪 — 比 Flutter 預設俐落，看得到但不拖。
class _FastSplash extends InteractiveInkFeature {
  _FastSplash({
    required super.controller,
    required super.referenceBox,
    required Offset position,
    required super.color,
    required double radius,
    super.onRemoved,
  })  : _position = position,
        _maxRadius = radius {
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: controller.vsync,
    )
      ..addListener(controller.markNeedsPaint)
      ..addStatusListener((st) {
        if (st == AnimationStatus.completed) dispose();
      })
      ..forward();
    _r = Tween<double>(begin: 0, end: _maxRadius).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart),
    );
    _a = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.45, 1.0)),
    );
    controller.addInkFeature(this);
  }

  final Offset _position;
  final double _maxRadius;
  late final AnimationController _ctrl;
  late final Animation<double> _r;
  late final Animation<double> _a;

  static const InteractiveInkFeatureFactory factory = _FastSplashFactory();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    final paint = Paint()..color = color.withValues(alpha: color.a * _a.value);
    canvas.save();
    canvas.transform(transform.storage);
    canvas.drawCircle(_position, _r.value, paint);
    canvas.restore();
  }
}

class _FastSplashFactory extends InteractiveInkFeatureFactory {
  const _FastSplashFactory();

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    final size = referenceBox.size;
    return _FastSplash(
      controller: controller,
      referenceBox: referenceBox,
      position: position,
      color: color,
      radius: radius ?? (size.width + size.height) / 2,
      onRemoved: onRemoved,
    );
  }
}
