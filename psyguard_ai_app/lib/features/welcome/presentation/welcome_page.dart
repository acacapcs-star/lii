import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/security/local_settings_service.dart';
import '../../../core/widgets/luna_orb.dart';
import '../../../l10n/app_language.dart';

class _Page {
  final String titleZh;
  final String titleEn;
  final String bodyZh;
  final String bodyEn;

  /// 每頁自己的底色。滑動時會漸變 —— 七頁同一個藍會讓人覺得沒在前進。
  final List<Color> bg;

  const _Page({
    required this.titleZh,
    required this.titleEn,
    required this.bodyZh,
    required this.bodyEn,
    required this.bg,
  });
}

const _pages = <_Page>[
  _Page(
    titleZh: 'lii',
    titleEn: 'lii',
    bodyZh: '給台灣青少年的\n心理健康夥伴',
    bodyEn: 'A mental health companion\nbuilt for youth in Taiwan',
    bg: [Color(0xFF4A7FA5), Color(0xFF2C5282), Color(0xFF1A3558)],
  ),
  _Page(
    titleZh: '狀況越差\n它說得越少',
    titleEn: 'The worse it gets,\nthe less it says',
    bodyZh: '大部分 App 在你最累的時候講最多話。\nlii 相反，分數越高，它越安靜。',
    bodyEn:
        'Most apps talk more when you are struggling.\nlii does the opposite: the higher the score,\nthe quieter it gets.',
    bg: [Color(0xFF3D6B8F), Color(0xFF24466F), Color(0xFF152C4A)],
  ),
  _Page(
    titleZh: '每天一分鐘\n分數看得懂',
    titleEn: 'One minute a day',
    bodyZh: '記情緒、睡眠時間、入睡難易度。\nERS 把三種訊號算成一個分數，\n每個數字都追得到來源，不是 AI 猜的。',
    bodyEn:
        'Log your mood, sleep and how hard it was to\nfall asleep. ERS turns three signals into one\nscore, and every number traces back to its\ninputs. None is guessed by a model.',
    bg: [Color(0xFF2F6B6B), Color(0xFF1E4A52), Color(0xFF122E38)],
  ),
  _Page(
    titleZh: '換個想法\n不是換個心情',
    titleEn: 'Reframe, not pretend',
    bodyZh: '思考教練帶你把一個念頭拆開重寫。\n思考陷阱測驗讓你看見自己的慣性。\n不是叫你正向，是給你方法。',
    bodyEn:
        'Thought Coach walks you through rewriting\na thought. The Thinking Trap Quiz shows your\nhabits. Not telling you to be positive,\ngiving you a method.',
    bg: [Color(0xFF6B5A8F), Color(0xFF453A6B), Color(0xFF28214A)],
  ),
  _Page(
    titleZh: '球球是你的\n想放哪就放哪',
    titleEn: 'The orb is yours',
    bodyZh: '點一下：陪你呼吸\n長按：看水晶收藏\n拖著走：換位置　拉四個角：調大小',
    bodyEn:
        'Tap: breathe with Luna\nHold: your crystal collection\nDrag to move it. Pull a corner to resize.',
    bg: [Color(0xFF2A5F8F), Color(0xFF1A3D6E), Color(0xFF0F2444)],
  ),
  _Page(
    titleZh: '別人說過的話\n留到你需要的那天',
    titleEn: 'Saved for the day\nyou need it',
    bodyZh: 'Pacer Lift 把有人對你說過的話收成纜車，\n心情低的那天自己浮上來。\n時機是規則挑的，話是人說的。',
    bodyEn:
        'Pacer Lift saves what people said to you as\ncable cars; one comes back on a hard day.\nRules choose the moment, but a person\nwrote the words.',
    bg: [Color(0xFF4A6B8F), Color(0xFF2E4A6B), Color(0xFF1A2E4A)],
  ),
  _Page(
    titleZh: '沒有你的同意\n不會有人知道',
    titleEn: 'Nothing leaves\nwithout you',
    bodyZh: '日記加密留在手機裡。\n危機字詞在送進 AI 之前就被攔下。\nlii 不是醫療工具，也不能取代專業人員。',
    bodyEn:
        'Your diary stays encrypted on this phone.\nCrisis keywords are caught before they reach\nthe AI. lii is not a medical tool and does not\nreplace licensed professionals.',
    bg: [Color(0xFF243B5A), Color(0xFF16243B), Color(0xFF0B121F)],
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
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _pages[_i].bg,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
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
                                color: Colors.white.withValues(alpha: 0.55),
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
                  itemBuilder: (context, i) => _slide(i, isZh),
                ),
              ),
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
                      color: Colors.white.withValues(alpha: on ? 0.9 : 0.28),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 26),
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
                      last ? (isZh ? '開始' : 'Start') : (isZh ? '下一頁' : 'Next'),
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
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slide(int i, bool isZh) {
    final p = _pages[i];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 150, child: Center(child: _art(i))),
          const SizedBox(height: 34),
          Text(
            isZh ? p.titleZh : p.titleEn,
            textAlign: TextAlign.center,
            style: i == 0
                ? GoogleFonts.playfairDisplay(
                    fontSize: 66,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 18,
                    color: Colors.white,
                  )
                : const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: Colors.white,
                  ),
          ),
          const SizedBox(height: 18),
          Text(
            isZh ? p.bodyZh : p.bodyEn,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.85,
              color: Colors.white.withValues(alpha: 0.76),
            ),
          ),
        ],
      ),
    );
  }

  /// 每頁的視覺。第 5 頁放真的水晶球 ——
  /// 講「這顆球會呼吸」不如直接讓他看著它呼吸。
  Widget _art(int i) {
    switch (i) {
      case 0:
        return const SizedBox(
            width: 120, height: 120, child: LunaOrbLive(w: 80));
      case 1:
        return _tiers();
      case 2:
        return _streams();
      case 3:
        return _reframe();
      case 4:
        return const SizedBox(
            width: 132, height: 132, child: LunaOrbLive(w: 0));
      case 5:
        return _cableCar();
      default:
        return Icon(Icons.lock_outline_rounded,
            size: 74, color: Colors.white.withValues(alpha: 0.85));
    }
  }

  /// 綠黃紅：字量隨風險遞減 —— 這頁的主張直接畫出來
  Widget _tiers() {
    const data = [
      [Color(0xFF4CAF82), 3.0],
      [Color(0xFFE0A33E), 2.0],
      [Color(0xFFD9534F), 1.0],
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: data.map((d) {
        final c = d[0] as Color;
        final lines = (d[1] as double).toInt();
        return Container(
          width: 62,
          height: 96,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: c.withValues(alpha: 0.7), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              lines,
              (k) => Container(
                height: 4,
                width: k == lines - 1 ? 26 : 40,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 三條訊號匯成一個分數
  Widget _streams() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Colors.white70, Colors.white70, Colors.white70]
              .map((c) => Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 14),
        Icon(Icons.keyboard_arrow_down_rounded,
            size: 30, color: Colors.white.withValues(alpha: 0.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(15),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: const Text('ERS',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
                  color: Colors.white)),
        ),
      ],
    );
  }

  /// 一個念頭被劃掉、重寫
  Widget _reframe() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 168,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            Container(
              width: 130,
              height: 2,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Icon(Icons.keyboard_arrow_down_rounded,
            size: 26, color: Colors.white.withValues(alpha: 0.45)),
        const SizedBox(height: 12),
        Container(
          width: 168,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
          ),
        ),
      ],
    );
  }

  /// 纜線上掛著一張卡
  Widget _cableCar() {
    return SizedBox(
      width: 200,
      height: 130,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Container(
                height: 2, color: Colors.white.withValues(alpha: 0.45)),
          ),
          Positioned(
            top: 14,
            child: Container(width: 2, height: 26, color: Colors.white54),
          ),
          Positioned(
            top: 40,
            child: Container(
              width: 96,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(11),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
              padding: const EdgeInsets.all(11),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 4,
                      width: 56,
                      margin: const EdgeInsets.only(bottom: 6),
                      color: Colors.white.withValues(alpha: 0.65)),
                  Container(
                      height: 4,
                      width: 36,
                      color: Colors.white.withValues(alpha: 0.45)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
