import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/crystals/crystal_collection_page.dart';
import '../../../core/pacer/breath_plan.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../core/theme/background_theme_service.dart';
import '../../../core/theme/mood_theme_service.dart';
import '../../../core/widgets/floating_app_brand.dart';
import '../../../core/widgets/lii_breath_page.dart';
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
  // 彩蛋：圖片路徑 + 文字
  final String easterImg;
  final String easterZh;
  final String easterEn;

  const _AtmItem({
    required this.emoji,
    required this.labelZh,
    required this.labelEn,
    required this.bg,
    this.moodTheme,
    this.bgColor,
    required this.easterImg,
    required this.easterZh,
    required this.easterEn,
  });
}

const _atmItems = [
  _AtmItem(
    emoji: '🎄', labelZh: '聖誕節', labelEn: 'Christmas',
    bg: Color(0xFF1A4A2A), moodTheme: MoodTheme.christmas,
    easterImg: 'assets/images/mood_xmas_cat.png',
    easterZh: '聖誕貓貓在偷看你', easterEn: 'Santa Cat is watching',
  ),
  _AtmItem(
    emoji: '🧧', labelZh: '過年', labelEn: 'Lunar NY',
    bg: Color(0xFF5A1A1A), moodTheme: MoodTheme.newYear,
    easterImg: 'assets/images/mood_hongbao.png',
    easterZh: '恭喜發財，紅包拿來', easterEn: 'Happy New Year!',
  ),
  _AtmItem(
    emoji: '🌸', labelZh: '春', labelEn: 'Spring',
    bg: Color(0xFF6A3A5A), moodTheme: MoodTheme.spring,
    easterImg: 'assets/images/mood_easter_bunny.jpg',
    easterZh: '春天藏了一隻兔兔', easterEn: 'A bunny hides in spring',
  ),
  _AtmItem(
    emoji: '☀️', labelZh: '夏', labelEn: 'Summer',
    bg: Color(0xFF1A4A5A), moodTheme: MoodTheme.summer,
    easterImg: 'assets/images/mood_summer_beach.png',
    easterZh: '夏日海灘等你來', easterEn: 'Summer beach awaits',
  ),
  _AtmItem(
    emoji: '🍂', labelZh: '秋', labelEn: 'Autumn',
    bg: Color(0xFF5A3A1A), moodTheme: MoodTheme.autumn,
    easterImg: 'assets/images/mood_fox_hide.png',
    easterZh: '落葉裡躲著一隻狐狸', easterEn: 'A fox hides in the leaves',
  ),
  _AtmItem(
    emoji: '❄️', labelZh: '冬', labelEn: 'Winter',
    bg: Color(0xFF1A3A5A), moodTheme: MoodTheme.winter,
    easterImg: 'assets/images/mood_snowman_cat.png',
    easterZh: '雪地裡有個雪貓咪', easterEn: 'Snowcat in the snow',
  ),
  _AtmItem(
    emoji: '⛷️', labelZh: '寒假', labelEn: 'Winter Hols',
    bg: Color(0xFF2A3A4A), moodTheme: MoodTheme.winterBreak,
    easterImg: 'assets/images/mood_baby_penguin_1.png',
    easterZh: '寒假小企鵝出沒', easterEn: 'Baby penguin on vacation',
  ),
  _AtmItem(
    emoji: '🏖️', labelZh: '暑假', labelEn: 'Summer Hols',
    bg: Color(0xFF4A3A1A), moodTheme: MoodTheme.summerBreak,
    easterImg: 'assets/images/mood_icecream.png',
    easterZh: '暑假就該吃冰淇淋', easterEn: 'Ice cream season!',
  ),
  _AtmItem(
    emoji: '💙', labelZh: '藍光', labelEn: 'Blue',
    bg: Color(0xFF2A4A7A), bgColor: BgColorChoice.blueLight,
    easterImg: 'assets/images/mood_drink_1.png',
    easterZh: '藍色讓心靜下來', easterEn: 'Blue calms the mind',
  ),
  _AtmItem(
    emoji: '💚', labelZh: '綠光', labelEn: 'Green',
    bg: Color(0xFF2A5A3A), bgColor: BgColorChoice.greenLight,
    easterImg: 'assets/images/mood_paw_1.png',
    easterZh: '綠光裡有個小腳印', easterEn: 'A paw print in the green',
  ),
  _AtmItem(
    emoji: '🌸', labelZh: '粉光', labelEn: 'Pink',
    bg: Color(0xFF6A3A5A), bgColor: BgColorChoice.pinkLight,
    easterImg: 'assets/images/mood_petal_1.png',
    easterZh: '粉色花瓣飄下來', easterEn: 'Pink petals falling',
  ),
  _AtmItem(
    emoji: '🌈', labelZh: '彩虹', labelEn: 'Rainbow',
    bg: Color(0xFF4A3A6A), bgColor: BgColorChoice.rainbowLight,
    easterImg: 'assets/images/mood_fish_1.png',
    easterZh: '彩虹尾端有條魚', easterEn: 'A fish at the rainbow\'s end',
  ),
  _AtmItem(
    emoji: '🌙', labelZh: '深藍', labelEn: 'Navy',
    bg: Color(0xFF0D1A3A), bgColor: BgColorChoice.navyDark,
    easterImg: 'assets/images/mood_penguin.png',
    easterZh: '深夜企鵝陪你', easterEn: 'A penguin in the dark',
  ),
  _AtmItem(
    emoji: '🌲', labelZh: '森林', labelEn: 'Forest',
    bg: Color(0xFF0D2A1A), bgColor: BgColorChoice.forestDark,
    easterImg: 'assets/images/mood_fox_lamp.jpg',
    easterZh: '森林裡的狐狸燈', easterEn: 'Fox lamp in the forest',
  ),
  _AtmItem(
    emoji: '⬛', labelZh: '純黑', labelEn: 'Black',
    bg: Color(0xFF0D0D0D), bgColor: BgColorChoice.pureBlack,
    easterImg: 'assets/images/mood_hq_boy.png',
    easterZh: '黑暗中有人陪你', easterEn: 'Someone\'s here in the dark',
  ),
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

    // 背景顏色：welcome page 用深色系
    // - 未選氛圍：固定深藍
    // - 已選氛圍：用 _atmItems 的深色 bg（不用 provider，provider 是淺色 UI 色）
    const _defaultBg = Color(0xFF1A2A4A);
    final bgBase = _selectedAtmIdx >= 0
        ? _atmItems[_selectedAtmIdx].bg
        : _defaultBg;

    return Focus(
      autofocus: false,
      canRequestFocus: false,
      child: Scaffold(
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

              // 彩蛋 / 已套用浮動卡片
              if (atmPage)
                Positioned(
                  bottom: 120,
                  left: 20,
                  right: 20,
                  child: FadeTransition(
                    opacity: _previewFade,
                    child: SlideTransition(
                      position: _previewSlide,
                      child: Center(
                        child: _selectedAtmIdx >= 0
                            ? _EasterCard(
                                item: _atmItems[_selectedAtmIdx],
                                isZh: isZh,
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  isZh ? '點下方選一個氛圍' : 'Pick one below',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500),
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
    ), // Scaffold
    ); // Focus
  }

  // ── 一般內容頁 ──────────────────────────────────────────────────────────────
  Widget _slide(_Page p, bool isZh, bool isCover, int pageIdx) {
    // index 4：球球頁，全頁自由拖動
    if (pageIdx == 4) {
      return Stack(
        children: [
          const Positioned.fill(child: _OrbDemo()),
          // 標題文字放頂部，不跟搖桿搶底部空間
          Positioned(
            left: 32, right: 32, top: 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isZh ? p.titleZh : p.titleEn,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 25, fontWeight: FontWeight.w600,
                      height: 1.4, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  isZh ? p.bodyZh : p.bodyEn,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.8,
                      color: Colors.white.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (p.emoji.isNotEmpty) ...[
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
          // 有繩子的球：點一下彩蛋，長按切換氛圍（循環）
          GestureDetector(
            onTap: () {
              // 點擊球：直接觸發彩蛋預覽卡片
              _previewCtrl.forward(from: 0);
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) _previewCtrl.reverse();
              });
            },
            onLongPress: () {
              // 長按：切換到下一個氛圍
              final next = (_selectedAtmIdx + 1) % _atmItems.length;
              _selectAtm(next);
            },
            child: const FloatingAppBrandIcon(size: 90),
          ),
          const SizedBox(height: 16),
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
                onTap: () {
                  _selectAtm(idx);
                  _previewCtrl.forward(from: 0);
                  Future.delayed(const Duration(seconds: 3), () {
                    if (mounted) _previewCtrl.reverse();
                  });
                },
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

// ── 彩蛋預覽卡片 ────────────────────────────────────────────────────────────
class _EasterCard extends StatefulWidget {
  final _AtmItem item;
  final bool isZh;
  const _EasterCard({required this.item, required this.isZh});
  @override
  State<_EasterCard> createState() => _EasterCardState();
}

class _EasterCardState extends State<_EasterCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hop;

  @override
  void didUpdateWidget(_EasterCard old) {
    super.didUpdateWidget(old);
    if (old.item != widget.item) {
      _hop.forward(from: 0);
    }
  }

  @override
  void initState() {
    super.initState();
    _hop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    // 只播一次，結束後停在 1.0
    _hop.forward();
    _hop.addStatusListener((status) {
      if (status == AnimationStatus.completed) _hop.stop();
    });
  }

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: item.bg.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 彩蛋圖片
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
            child: AnimatedBuilder(
              animation: _hop,
              builder: (ctx, child) {
                final t = _hop.value;
                // sin(0→π) → 0→0，中間拱起來再落下，只播一次
                final dy = -math.sin(t * math.pi) * 10;
                return Transform.translate(offset: Offset(0, dy), child: child);
              },
              child: Image.asset(
                item.easterImg,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => SizedBox(
                  width: 90,
                  height: 90,
                  child: Center(
                      child: Text(item.emoji,
                          style: const TextStyle(fontSize: 40))),
                ),
              ),
            ),
          ),
          // 文字
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${item.emoji}  ${widget.isZh ? item.labelZh : item.labelEn}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.isZh ? item.easterZh : item.easterEn,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        height: 1.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.isZh ? '已套用這個氛圍 ✓' : 'Applied ✓',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 球球互動示範（index 4）：無繩球，點兩下開 Joy-Con controller ──
class _OrbDemo extends StatefulWidget {
  const _OrbDemo();
  @override
  State<_OrbDemo> createState() => _OrbDemoState();
}

class _OrbDemoState extends State<_OrbDemo> {
  // 球位置：null = 畫面正中央
  Offset? _pos;
  double _size = 90.0;
  bool _ctrlOpen = false;
  Timer? _hideCtrl;
  Timer? _stickTimer;
  Timer? _zoomTimer;
  Offset _stick = Offset.zero;
  double _curLeft = 0, _curTop = 0;

  static const double _stickR = 32;
  static const double _minSize = 48;
  static const double _maxSize = 180;

  // 點擊球：短暫放大再縮回（預覽呼吸感）
  bool _pulsing = false;
  void _pulseAnim() {
    if (_pulsing) return;
    setState(() { _pulsing = true; _size = (_size * 1.18).clamp(_minSize, _maxSize); });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() { _size = (_size / 1.18).clamp(_minSize, _maxSize); _pulsing = false; });
    });
  }

  void _openCtrl() {
    setState(() => _ctrlOpen = true);
    _resetHideTimer();
  }

  void _resetHideTimer() {
    _hideCtrl?.cancel();
    _hideCtrl = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _ctrlOpen = false);
    });
  }

  void _stickStart() {
    _hideCtrl?.cancel();
    _stickTimer?.cancel();
    _stickTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_stick == Offset.zero || !mounted) return;
      setState(() => _pos = Offset(_curLeft, _curTop) + _stick * 6);
    });
  }

  void _stickMove(Offset local) {
    var v = (local - const Offset(_stickR, _stickR)) / _stickR;
    if (v.distance > 1) v = v / v.distance;
    setState(() => _stick = v);
  }

  void _stickEnd() {
    _stickTimer?.cancel();
    setState(() => _stick = Offset.zero);
    _resetHideTimer();
  }

  void _zoomOnce(double d) =>
      setState(() => _size = (_size + d).clamp(_minSize, _maxSize));

  void _zoomStart(double d) {
    _hideCtrl?.cancel();
    _zoomOnce(d);
    _zoomTimer?.cancel();
    _zoomTimer =
        Timer.periodic(const Duration(milliseconds: 60), (_) => _zoomOnce(d));
  }

  void _zoomEnd() {
    _zoomTimer?.cancel();
    _resetHideTimer();
  }

  void _resetPos() {
    setState(() => _pos = null);
    _resetHideTimer();
  }

  Widget _joyBtn(IconData icon,
      {required VoidCallback onDown, VoidCallback? onUp}) {
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp?.call(),
      onTapCancel: () => onUp?.call(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.14),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _hideCtrl?.cancel();
    _stickTimer?.cancel();
    _zoomTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final cx = sz.width / 2;
    final cy = sz.height / 2;
    final ballLeft = (_pos?.dx ?? cx) - _size / 2;
    final ballTop = (_pos?.dy ?? cy) - _size / 2;
    // 更新 _curLeft/_curTop 供 stick timer 用
    _curLeft = _pos?.dx ?? cx;
    _curTop = _pos?.dy ?? cy;

    const panelW = 200.0;
    const panelH = 72.0;
    const joyBottom = 32.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 球本體（無繩）
        Positioned(
          left: ballLeft,
          top: ballTop,
          width: _size,
          height: _size,
          child: GestureDetector(
            onTap: () => showLiiBreath(context, mood: BreathMood.calm),
            onLongPress: () => showCrystalCollection(context),
            onDoubleTap: _openCtrl,
            child: Image.asset('assets/images/lii_ball.png'),
          ),
        ),

        // 提示文字
        Positioned(
          bottom: joyBottom + panelH + 8,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              _ctrlOpen
                  ? '搖桿移動・+/-調大小・再點兩下關閉'
                  : '點一下・長按・拖著走・點兩下操控',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  letterSpacing: 1),
            ),
          ),
        ),

        // Joy-Con 膠囊 controller
        if (_ctrlOpen)
          Positioned(
            bottom: joyBottom,
            left: (sz.width - panelW) / 2,
            width: panelW,
            height: panelH,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1B2233).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(panelH / 2),
                border: Border.all(color: Colors.white12),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black38,
                      blurRadius: 14,
                      offset: Offset(0, 6)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  // 搖桿
                  GestureDetector(
                    onPanStart: (d) {
                      _stickStart();
                      _stickMove(d.localPosition);
                    },
                    onPanUpdate: (d) => _stickMove(d.localPosition),
                    onPanEnd: (_) => _stickEnd(),
                    onPanCancel: _stickEnd,
                    child: SizedBox(
                      width: _stickR * 2,
                      height: _stickR * 2,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.35),
                              border: Border.all(color: Colors.white24),
                            ),
                          ),
                          Positioned(
                            left: _stickR -
                                14 +
                                _stick.dx * (_stickR - 14),
                            top: _stickR -
                                14 +
                                _stick.dy * (_stickR - 14),
                            width: 28,
                            height: 28,
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  center: Alignment(-0.3, -0.35),
                                  colors: [
                                    Color(0xFFFFE9A8),
                                    Color(0xFFFFB84A)
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                      color: Color(0x66FFD166),
                                      blurRadius: 10),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 放大縮小
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _joyBtn(Icons.add_rounded,
                          onDown: () => _zoomStart(4), onUp: _zoomEnd),
                      const SizedBox(height: 4),
                      _joyBtn(Icons.remove_rounded,
                          onDown: () => _zoomStart(-4), onUp: _zoomEnd),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // 回到原位
                  _joyBtn(Icons.center_focus_strong_outlined,
                      onDown: _resetPos),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

