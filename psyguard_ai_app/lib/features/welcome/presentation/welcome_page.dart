import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../core/theme/background_theme_service.dart';
import '../../../l10n/app_language.dart';

class _Page {
  final String emoji;
  final String titleZh;
  final String titleEn;
  final String bodyZh;
  final String bodyEn;
  const _Page(this.emoji, this.titleZh, this.titleEn, this.bodyZh, this.bodyEn);
}

// 順序有意義：先講主張，再講方法，再講工具，最後交代邊界。
const List<_Page> _pages = [
  _Page(
    '',
    'lii',
    'lii',
    '給台灣青少年的\n心理健康夥伴',
    'A mental health companion\nbuilt for youth in Taiwan',
  ),
  _Page(
    '🔉',
    '狀況越差\n它說得越少',
    'The worse it gets,\nthe less it says',
    '大部分 App 在你最累的時候講最多話。\nlii 相反，分數越高，它越安靜。',
    'Most apps talk more when you are struggling.\nlii does the opposite: the higher the score,\nthe quieter it gets.',
  ),
  _Page(
    '📊',
    '每天一分鐘\n分數看得懂',
    'One minute a day',
    '記情緒、睡眠時間、入睡難易度。\nERS 把三種訊號算成一個分數，\n每個數字都追得到來源，不是 AI 猜的。',
    'Log your mood, sleep hours and how hard it was\nto fall asleep. ERS turns three signals into one\nscore, and every number traces back to its\ninputs. None is guessed by a model.',
  ),
  _Page(
    '🧠',
    '換個想法\n不是換個心情',
    'Reframe, not pretend',
    '思考教練帶你把一個念頭拆開重寫。\n思考陷阱測驗讓你看見自己的慣性。\n不是叫你正向，是給你方法。',
    'Thought Coach walks you through rewriting\na thought. The Thinking Trap Quiz shows your\nhabits. Not telling you to be positive,\ngiving you a method.',
  ),
  _Page(
    '🔮',
    '球球是你的\n想放哪就放哪',
    'The orb is yours',
    '點一下：陪你呼吸，從你的速度慢慢放慢\n長按：看水晶收藏，練習過會變成水晶\n拖著走：換位置\n拉四個角：調大小',
    'Tap: breathe with Luna. It starts at your own\npace, then slows down.\nHold: your crystals, unlocked by practice.\nDrag to move it. Pull a corner to resize.',
  ),
  _Page(
    '🚡',
    '別人說過的話\n留到你需要的那天',
    'Saved for the day\nyou need it',
    'Pacer Lift 把有人對你說過的話收成纜車，\n心情低的那天自己浮上來。\n時機是規則挑的，話是人說的。',
    'Pacer Lift saves what people said to you as\ncable cars; one comes back on a hard day.\nRules choose the moment,\nbut a person wrote the words.',
  ),
  _Page(
    '🎨',
    '選一個氛圍\n陪你開始',
    'Pick an atmosphere\nto begin with',
    '之後長按天上的球可以隨時切換',
    'Long-press the orb anytime to change it',
  ),
  _Page(
    '🔒',
    '沒有你的同意\n不會有人知道',
    'Nothing leaves\nwithout you',
    '日記加密留在手機裡。\n危機字詞在送進 AI 之前就被攔下。\nlii 不是醫療工具，也不能取代專業人員。',
    'Your diary stays encrypted on this phone.\nCrisis keywords are caught before they reach\nthe AI. lii is not a medical tool and does not\nreplace licensed professionals.',
  ),
];

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  final _ctrl = PageController();
  int _i = 0;
  BgColorChoice? _selectedAtm;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final settings = ref.read(localSettingsServiceProvider);
    await settings.setWelcomeSeen();
    await settings.setConsentAccepted(version: 1);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isZh = ref.watch(appLanguageControllerProvider) == AppLanguage.zhTw;
    final last = _i == _pages.length - 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4A7FA5), Color(0xFF2C5282), Color(0xFF1A3558)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 跳過：最後一頁不顯示，那裡已經有 Start
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
                            child: Text(
                              isZh ? '跳過' : 'Skip',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                letterSpacing: 2,
                              ),
                            ),
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
                      : _slide(_pages[i], isZh, i == 0),
                ),
              ),
              // 進度點
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
                      color: Colors.white.withValues(alpha: on ? 0.9 : 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slide(_Page p, bool isZh, bool isCover) {
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
                    color: Colors.white,
                  )
                : const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: Colors.white,
                  ),
          ),
          const SizedBox(height: 20),
          Text(
            isZh ? p.bodyZh : p.bodyEn,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.85,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }

  Widget _atmSlide(bool isZh) {
    const items = [
      (icon: '💙', labelZh: '藍光', choice: BgColorChoice.blueLight,    bg: Color(0xFF2A4A7A)),
      (icon: '💚', labelZh: '綠光', choice: BgColorChoice.greenLight,   bg: Color(0xFF2A5A3A)),
      (icon: '🌸', labelZh: '粉光', choice: BgColorChoice.pinkLight,    bg: Color(0xFF6A3A5A)),
      (icon: '🌈', labelZh: '彩虹', choice: BgColorChoice.rainbowLight, bg: Color(0xFF4A3A6A)),
      (icon: '🌙', labelZh: '深藍', choice: BgColorChoice.navyDark,     bg: Color(0xFF0D1A3A)),
      (icon: '🌲', labelZh: '森林', choice: BgColorChoice.forestDark,   bg: Color(0xFF0D2A1A)),
      (icon: '⬛', labelZh: '純黑', choice: BgColorChoice.pureBlack,    bg: Color(0xFF0D0D0D)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎨', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 28),
          const Text(
            '選一個氛圍\n陪你開始',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600, height: 1.4, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            isZh ? '之後長按天上的球可以隨時切換' : 'Long-press the orb anytime to change it',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, height: 1.85, color: Colors.white.withValues(alpha: 0.78)),
          ),
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: items.map((a) {
              final selected = _selectedAtm == a.choice;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedAtm = a.choice);
                  ref.read(backgroundThemeProvider.notifier).setColor(a.choice);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: a.bg.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.2),
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(a.icon, style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 4),
                      Text(a.labelZh, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
