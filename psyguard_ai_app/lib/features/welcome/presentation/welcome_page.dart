import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/security/local_settings_service.dart';
import '../../../core/theme/background_theme_service.dart';
import '../../../core/theme/mood_theme_service.dart';
import '../../../core/widgets/floating_app_brand.dart';
import '../../../l10n/app_language.dart';

// ── 頁面資料 ──────────────────────────────────────────────────────────────────
class _Page {
  final String emoji;
  final String titleZh;
  final String titleEn;
  final String bodyZh;
  final String bodyEn;
  const _Page(this.emoji, this.titleZh, this.titleEn, this.bodyZh, this.bodyEn);
}

const List<_Page> _pages = [
  _Page('', 'lii', 'lii',
      '給台灣青少年的\n心理健康夥伴',
      'A mental health companion\nbuilt for youth in Taiwan'),
  _Page('🔉', '狀況越差\n它說得越少', 'The worse it gets,\nthe less it says',
      '大部分 App 在你最累的時候講最多話。\nlii 相反，分數越高，它越安靜。',
      'Most apps talk more when you are struggling.\nlii does the opposite: the higher the score,\nthe quieter it gets.'),
  _Page('📊', '每天一分鐘\n分數看得懂', 'One minute a day',
      '記情緒、睡眠時間、入睡難易度。\nERS 把三種訊號算成一個分數，\n每個數字都追得到來源，不是 AI 猜的。',
      'Log your mood, sleep hours and how hard it was\nto fall asleep. ERS turns three signals into one\nscore, and every number traces back to its\ninputs. None is guessed by a model.'),
  _Page('🧠', '換個想法\n不是換個心情', 'Reframe, not pretend',
      '思考教練帶你把一個念頭拆開重寫。\n思考陷阱測驗讓你看見自己的慣性。\n不是叫你正向，是給你方法。',
      'Thought Coach walks you through rewriting\na thought. The Thinking Trap Quiz shows your\nhabits. Not telling you to be positive,\ngiving you a method.'),
  _Page('', '球球是你的\n想放哪就放哪', 'The orb is yours',
      '點一下：陪你呼吸，從你的速度慢慢放慢\n長按：看水晶收藏，練習過會變成水晶\n拖著走：換位置\n拉四個角：調大小',
      'Tap: breathe with Luna. It starts at your own\npace, then slows down.\nHold: your crystals, unlocked by practice.\nDrag to move it. Pull a corner to resize.'),
  _Page('🚡', '別人說過的話\n留到你需要的那天', 'Saved for the day\nyou need it',
      'Pacer Lift 把有人對你說過的話收成纜車，\n心情低的那天自己浮上來。\n時機是規則挑的，話是人說的。',
      'Pacer Lift saves what people said to you as\ncable cars; one comes back on a hard day.\nRules choose the moment,\nbut a person wrote the words.'),
  _Page('', '選一個氛圍\n陪你開始', 'Pick an atmosphere\nto begin with',
      '之後長按天上的球可以隨時切換',
      'Long-press the orb anytime to change it'),
  _Page('🔒', '沒有你的同意\n不會有人知道', 'Nothing leaves\nwithout you',
      '日記加密留在手機裡。\n危機字詞在送進 AI 之前就被攔下。\nlii 不是醫療工具，也不能取代專業人員。',
      'Your diary stays encrypted on this phone.\nCrisis keywords are caught before they reach\nthe AI. lii is not a medical tool and does not\nreplace licensed professionals.'),
];

// ── 氛圍資料：季節用 MoodTheme，燈光用 BgColorChoice ─────────────────────────
class _AtmItem {
  final String emoji;
  final String labelZh;
  final String labelEn;
  final Color bg;
  // 季節 8 個用 moodTheme，燈光 7 個用 bgColor
  final MoodTheme? moodTheme;
  final BgColorChoice? bgColor;

  const _AtmItem({
    required this.emoji,
    required this.labelZh,
    required this.labelEn,
    required this.bg,
    this.moodTheme,
    this.bgColor,
  });
}

const _atmItems = [
  _AtmItem(emoji: '🎄', labelZh: '聖誕節', labelEn: 'Christmas',   bg: Color(0xFF1A4A2A), moodTheme: MoodTheme.christmas),
  _AtmItem(emoji: '🧧', labelZh: '過年',   labelEn: 'Lunar NY',    bg: Color(0xFF5A1A1A), moodTheme: MoodTheme.newYear),
  _AtmItem(emoji: '🌸', labelZh: '春',     labelEn: 'Spring',      bg: Color(0xFF6A3A5A), moodTheme: MoodTheme.spring),
  _AtmItem(emoji: '☀️', labelZh: '夏',     labelEn: 'Summer',      bg: Color(0xFF1A4A5A), moodTheme: MoodTheme.summer),
  _AtmItem(emoji: '🍂', labelZh: '秋',     labelEn: 'Autumn',      bg: Color(0xFF5A3A1A), moodTheme: MoodTheme.autumn),
  _AtmItem(emoji: '❄️', labelZh: '冬',     labelEn: 'Winter',      bg: Color(0xFF1A3A5A), moodTheme: MoodTheme.winter),
  _AtmItem(emoji: '⛷️', labelZh: '寒假',   labelEn: 'Winter Hols', bg: Color(0xFF2A3A4A), moodTheme: MoodTheme.winterBreak),
  _AtmItem(emoji: '🏖️', labelZh: '暑假',   labelEn: 'Summer Hols', bg: Color(0xFF4A3A1A), moodTheme: MoodTheme.summerBreak),
  _AtmItem(emoji: '💙', labelZh: '藍光',   labelEn: 'Blue',        bg: Color(0xFF2A4A7A), bgColor: BgColorChoice.blueLight),
  _AtmItem(emoji: '💚', labelZh: '綠光',   labelEn: 'Green',       bg: Color(0xFF2A5A3A), bgColor: BgColorChoice.greenLight),
  _AtmItem(emoji: '🌸', labelZh: '粉光',   labelEn: 'Pink',        bg: Color(0xFF6A3A5A), bgColor: BgColorChoice.pinkLight),
  _AtmItem(emoji: '🌈', labelZh: '彩虹',   labelEn: 'Rainbow',     bg: Color(0xFF4A3A6A), bgColor: BgColorChoice.rainbowLight),
  _AtmItem(emoji: '🌙', labelZh: '深藍',   labelEn: 'Navy',        bg: Color(0xFF0D1A3A), bgColor: BgColorChoice.navyDark),
  _AtmItem(emoji: '🌲', labelZh: '森林',   labelEn: 'Forest',      bg: Color(0xFF0D2A1A), bgColor: BgColorChoice.forestDark),
  _AtmItem(emoji: '⬛', labelZh: '純黑',   labelEn: 'Black',       bg: Color(0xFF0D0D0D), bgColor: BgColorChoice.pureBlack),
];

// ── WelcomePage ───────────────────────────────────────────────────────────────
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});
  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage>
    with TickerProviderStateMixin {
  final _ctrl = PageController();
  int _i = 0;

  // 氛圍選擇狀態
  int _selectedAtmIdx = -1;
  late final AnimationController _previewCtrl;
  late final Animation<double> _previewFade;
  late final Animation<Offset> _previewSlide;

  @override
  void initState() {
    super.initState();
    _previewCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _previewFade =
        CurvedAnimation(parent: _previewCtrl, curve: Curves.easeOut);
    _previewSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _previewCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _previewCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final settings = ref.read(localSettingsServiceProvider);
    await settings.setWelcomeSeen();
    await settings.setConsentAccepted(version: 1);
    if (mounted) context.go('/home');
  }

  /// 選氛圍：依類型分別寫入對應 provider，並觸發「已套用」卡片
  Future<void> _selectAtm(int idx) async {
    final item = _atmItems[idx];
    setState(() => _selectedAtmIdx = idx);

    if (item.moodTheme != null) {
      await ref.read(moodThemeProvider.notifier).setMood(item.moodTheme!);
    } else if (item.bgColor != null) {
      await ref.read(backgroundThemeProvider.notifier).setColor(item.bgColor!);
    }

    _previewCtrl.forward(from: 0);
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) _previewCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isZh = ref.watch(appLanguageControllerProvider) == AppLanguage.zhTw;
    final last = _i == _pages.length - 1;
    final atmPage = _i == _pages.length - 2; // 倒數第二頁 = 氛圍選擇頁

    // 背景顏色：與首頁相同邏輯 — 季節氛圍優先，否則用燈光模式
    final moodIsDark = ref.watch(backgroundThemeProvider).mode == BgMode.dark;
    final moodColor = ref.watch(moodThemeProvider).backgroundColorFor(moodIsDark);
    final bgBase = moodColor.a != 0
        ? moodColor
        : ref.watch(backgroundThemeProvider).backgroundColor;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              bgBase,
              Color.lerp(bgBase, Colors.black, 0.3)!,
              Color.lerp(bgBase, Colors.black, 0.5)!,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // 跳過按鈕
                  SizedBox(
                    height: 48,
                    child: last
                        ? null
                        : Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: TextButton(
                                onPressed: _finish,
                                child: Text(isZh ? '跳過' : 'Skip',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.6),
                                        letterSpacing: 2)),
                              ),
                            ),
                          ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _ctrl,
                      itemCount: _pages.length,
                      onPageChanged: (v) => setState(() => _i = v),
                      itemBuilder: (context, i) => i == _pages.length - 2
                          ? _atmSlide(isZh)
                          : _slide(_pages[i], isZh, i == 0, i),
                    ),
                  ),
                  // 分頁點
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (k) {
                      final on = k == _i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: on ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: on ? 0.9 : 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),
                  // 下一頁 / 開始
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (last) {
                            _finish();
                          } else {
                            _ctrl.nextPage(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2C5282),
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          last
                              ? (isZh ? '開始' : 'Start')
                              : (isZh ? '下一頁' : 'Next'),
                          style: GoogleFonts.playfairDisplay(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),

              // 「已套用這個氛圍」浮動卡片
              if (atmPage && _selectedAtmIdx >= 0)
                Positioned(
                  bottom: 120,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _previewFade,
                    child: SlideTransition(
                      position: _previewSlide,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: _atmItems[_selectedAtmIdx]
                                .bg
                                .withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_atmItems[_selectedAtmIdx].emoji,
                                  style:
                                      const TextStyle(fontSize: 36)),
                              const SizedBox(height: 8),
                              Text(
                                isZh
                                    ? _atmItems[_selectedAtmIdx].labelZh
                                    : _atmItems[_selectedAtmIdx].labelEn,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isZh ? '已套用這個氛圍' : 'Atmosphere applied',
                                style: TextStyle(
                                    color: Colors.white
                                        .withValues(alpha: 0.7),
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 一般內容頁 ──────────────────────────────────────────────────────────────
  Widget _slide(_Page p, bool isZh, bool isCover, int pageIdx) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 第 4 頁（index 4）：球球示範，空 emoji + 有互動球
          if (p.emoji.isEmpty && pageIdx == 4) ...[
            const _OrbDemo(),
            const SizedBox(height: 28),
          ] else if (p.emoji.isNotEmpty) ...[
            Text(p.emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 28),
          ],
          Text(
            isZh ? p.titleZh : p.titleEn,
            textAlign: TextAlign.center,
            style: isCover
                ? GoogleFonts.playfairDisplay(
                    fontSize: 72,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 20,
                    color: Colors.white)
                : const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            isZh ? p.bodyZh : p.bodyEn,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14.5,
                height: 1.85,
                color: Colors.white.withValues(alpha: 0.78)),
          ),
        ],
      ),
    );
  }

  // ── 氛圍選擇頁 ──────────────────────────────────────────────────────────────
  Widget _atmSlide(bool isZh) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isZh ? '選一個氛圍\n陪你開始' : 'Pick an atmosphere\nto begin with',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            isZh
                ? '之後長按天上的球可以隨時切換'
                : 'Long-press the orb anytime to change it',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14.5,
                height: 1.85,
                color: Colors.white.withValues(alpha: 0.78)),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_atmItems.length, (idx) {
              final a = _atmItems[idx];
              final selected = _selectedAtmIdx == idx;
              return GestureDetector(
                onTap: () => _selectAtm(idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: a.bg.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.2),
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(a.emoji,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 3),
                      Text(isZh ? a.labelZh : a.labelEn,
                          style: TextStyle(
                              fontSize: 9,
                              color:
                                  Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── 球球互動示範（第 4 頁用）：FloatingAppBrandIcon 有繩子的球，可拖動縮放 ──
class _OrbDemo extends StatefulWidget {
  const _OrbDemo();
  @override
  State<_OrbDemo> createState() => _OrbDemoState();
}

class _OrbDemoState extends State<_OrbDemo> {
  Offset _pos = Offset.zero;
  double _scale = 1.0;
  bool _joystick = false;
  double _scaleBase = 1.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 提示文字
          Positioned(
            bottom: 0,
            child: Text(
              _joystick ? '拖動換位置・再點兩下鎖定' : '點兩下解鎖操控',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  letterSpacing: 1),
            ),
          ),

          // ＋／－ 大小按鈕（解鎖後才顯示）
          if (_joystick)
            Positioned(
              bottom: 24,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SizeBtn(
                    icon: Icons.remove,
                    onTap: () => setState(
                        () => _scale = (_scale - 0.1).clamp(0.5, 2.0)),
                  ),
                  const SizedBox(width: 24),
                  _SizeBtn(
                    icon: Icons.add,
                    onTap: () => setState(
                        () => _scale = (_scale + 0.1).clamp(0.5, 2.0)),
                  ),
                ],
              ),
            ),

          // 球本體
          Transform.translate(
            offset: _pos,
            child: GestureDetector(
              onDoubleTap: () => setState(() => _joystick = !_joystick),
              onScaleStart: _joystick ? (d) { _scaleBase = _scale; } : null,
              onScaleUpdate: _joystick
                  ? (d) => setState(() {
                        _pos += d.focalPointDelta;
                        _scale = (_scaleBase * d.scale).clamp(0.5, 2.0);
                      })
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: _joystick
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1.5))
                    : null,
                child: Transform.scale(
                  scale: _scale,
                  child: const FloatingAppBrandIcon(size: 110),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SizeBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SizeBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
