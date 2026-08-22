// ═══════════════════════════════════════════════════════════
// lii - 開場引導（第一次打開 App，滑 4 張卡秒懂怎麼玩）
// 解決「新使用者不知道怎麼玩」。只跳一次，看過就記住。中英分開。
// ══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_strings.dart';
import '../../core/security/local_settings_service.dart';

const _kOnboardingKey = 'onboarding_v1_done';

Future<bool> onboardingDone() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingKey) ?? false;
  } catch (_) {
    return true; // 出錯就當看l過，不擋使用者
  }
}

Future<void> _setDone() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingKey, true);
  } catch (_) {}
}

Future<void> showOnboarding(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'onboarding',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, a1, a2) => Consumer(
      builder: (c, ref, _) {
        final zh =
            AppStrings.of(ref.watch(appLanguageControllerProvider)).isZhTw;
        return _OnboardingSheet(zh: zh);
      },
    ),
  );
}

class _Slide {
  final String emoji;
  final String titleZh;
  final String titleEn;
  final String bodyZh;
  final String bodyEn;
  const _Slide(
      this.emoji, this.titleZh, this.titleEn, this.bodyZh, this.bodyEn);
}

const List<_Slide> _slides = [
  _Slide(
    '🌙',
    'AI 讀你的痕跡\n真人接住你',
    'Someone to talk to.\nSomeone to catch you.',
    '給台灣青少年的\n心理健康夥伴 🌙',
    'A mental-health companion\nbuilt for youth in Taiwan 🌙',
  ),
  _Slide(
    '🔉',
    '狀況越差\n它說得越少',
    'The worse it gets,\nthe less it says',
    '大部分 App 在你最累的時候講最多話。\nlii 相反，分數越高，它越安靜。',
    'Most apps talk more when you are struggling.\nlii does the opposite: the higher the score,\nthe quieter it gets.',
  ),
  _Slide(
    '📊',
    '每天一分鐘\n分數看得懂',
    'One minute a day',
    '記情緒、睡眠時間、入睡難易度。\nERS 把三種訊號算成一個分數，\n每個數字都追得到來源，不是 AI 猜的。',
    'Log your mood, sleep hours and how hard it was\nto fall asleep. ERS turns three signals into one\nscore, and every number traces back to its\ninputs. None is guessed by a model.',
  ),
  _Slide(
    '🧠',
    '換個想法\n不是換個心情',
    'Reframe, not pretend',
    '思考教練帶你把一個念頭拆開重寫。\n思考陷阱測驗讓你看見自己的慣性。\n不是叫你正向，是給你方法。',
    'Thought Coach walks you through rewriting\na thought. The Thinking Trap Quiz shows your\nhabits. Not telling you to be positive,\ngiving you a method.',
  ),
  _Slide(
    '🔮',
    '球球是你的\n想放哪就放哪',
    'The orb is yours',
    '點一下：開始呼吸，從你現在的速度慢慢放慢\n長按：看水晶收藏，練習過的次數會變成水晶\n拖著走：換位置。拉四個角：調大小',
    'Tap: breathe with Luna. It starts at your own\npace, then slows. Hold: your crystals, unlocked\nby practice. Drag to move it, pull a corner\nto resize.',
  ),
  _Slide(
    '🚡',
    '別人說過的話\n留到你需要的那天',
    'Saved for the day you need it',
    'Pacer Lift 把有人對你說過的話收成纜車，\n心情低的那天自己浮上來。時機是規則挑的，\n話是人說的。希望盒還有可以翻面的鼓勵卡。',
    'Pacer Lift saves what people said to you as\ncable cars; one returns on a hard day. Rules\nchoose the moment, a person wrote the words.\nHope Box holds cards you can flip and keep.',
  ),
  _Slide(
    '🔒',
    '沒有你的同意\n不會有人知道',
    'Nothing leaves without you',
    '日記加密留在手機裡。\n危機字詞在送進 AI 之前就被攔下。\nlii 不是醫療工具，也不能取代專業人員。',
    'Your diary stays encrypted on this phone.\nCrisis keywords are caught before they reach\nthe AI. lii is not a medical tool and does not\nreplace licensed professionals.',
  ),
];


class _OnboardingSheet extends StatefulWidget {
  final bool zh;
  const _OnboardingSheet({required this.zh});
  @override
  State<_OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<_OnboardingSheet> {
  final _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _finish() {
    _setDone();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final zh = widget.zh;
    final last = _page == _slides.length - 1;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: double.infinity,
            height: 470,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(zh ? '跳過' : 'Skip',
                        style: TextStyle(color: Colors.grey.shade500)),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pc,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) {
                      final s = _slides[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF7E8FE8),
                                    Color(0xFFB8A7E0)
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Text(s.emoji,
                                    style: const TextStyle(fontSize: 44)),
                              ),
                            ),
                            const SizedBox(height: 26),
                            Text(zh ? s.titleZh : s.titleEn,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C3150))),
                            const SizedBox(height: 14),
                            Text(zh ? s.bodyZh : s.bodyEn,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14.5,
                                    height: 1.6,
                                    color: Colors.grey.shade700)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) {
                    final on = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: on ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color:
                            on ? const Color(0xFF7E8FE8) : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0ABFBC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (last) {
                          _finish();
                        } else {
                          _pc.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut);
                        }
                      },
                      child: Text(
                          last
                              ? (zh ? '開始使用 🌙' : 'Get started 🌙')
                              : (zh ? '下一步' : 'Next'),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
