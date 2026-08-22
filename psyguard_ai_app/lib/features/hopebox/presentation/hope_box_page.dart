// ═══════════════════════════════════════════════════════════
// lii - 希望盒 Flash Cards 🌙✨ (明信片風)
//
// 貓咪插圖鋪滿整張卡 + 白色粗體可愛藝術字(Fredoka)疊在上面。
// 點一下翻面、左右滑換卡、♡ 收藏、自己也能寫。中英嚴格分開。
// ═══════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_strings.dart';
import '../../../core/security/local_settings_service.dart';

class _Q {
  final String en;
  final String zh;
  final String cat;
  const _Q(this.en, this.zh, this.cat);
}

// 情境：emoji + 名稱 + 對應貓咪圖
const _cats = <String, Map<String, String>>{
  'anxious': {'en': 'Breathe', 'zh': '深呼吸', 'emoji': '🌊', 'img': 'assets/images/hope_anxious.jpg'},
  'sad':     {'en': 'Low day', 'zh': '低落',   'emoji': '🌧️', 'img': 'assets/images/hope_sad.jpg'},
  'lonely':  {'en': 'Not alone', 'zh': '不孤單', 'emoji': '🌑', 'img': 'assets/images/hope_lonely.jpg'},
  'tired':   {'en': 'Rest', 'zh': '休息',     'emoji': '🌙', 'img': 'assets/images/hope_tired.jpg'},
  'harsh':   {'en': 'Be kind', 'zh': '對自己好', 'emoji': '🏷️', 'img': 'assets/images/hope_harsh.jpg'},
  'night':   {'en': 'Late night', 'zh': '深夜', 'emoji': '🌌', 'img': 'assets/images/hope_night.jpg'},
  'cheer':   {'en': 'You got this', 'zh': '你可以的', 'emoji': '⭐', 'img': 'assets/images/hope_cheer.jpg'},
  'custom':  {'en': 'Mine', 'zh': '我的',     'emoji': '✍️', 'img': 'assets/images/hope_custom.jpg'},
};

const _builtin = <_Q>[
  _Q("You're safe right now. This feeling is a wave — it will pass.", '你現在是安全的。這感覺像海浪，會退去的。', 'anxious'),
  _Q("Breathe in for 4. Hold. Out for 6. I'm here with you.", '吸氣 4 秒，停住，吐氣 6 秒。我在這裡陪你。', 'anxious'),
  _Q("Your body is trying to protect you. You are not in danger.", '你的身體想保護你。你沒有危險。', 'anxious'),
  _Q("One breath at a time. That's all you need to do.", '一次一口呼吸就好，你只要做這個。', 'anxious'),
  _Q("Feet on the ground. You are here. You are now.", '腳踏在地上，你在這裡，你在此刻。', 'anxious'),
  _Q("You don't have to shine every day. Even the moon rests.", '你不必每天發光，連月亮都會休息。', 'sad'),
  _Q("This heaviness is real, and it is not forever.", '這份沉重是真的，但不會是永遠。', 'sad'),
  _Q("Feeling deeply means you care deeply. That's not weakness.", '感受這麼深，是因為你在乎這麼深。那不是軟弱。', 'sad'),
  _Q("You've survived every hard day so far. A 100% record.", '你撐過了至今每一個難熬的日子，成功率 100%。', 'sad'),
  _Q("Let it be a slow day. Slow is still moving.", '就讓今天慢一點吧。慢，也還是在前進。', 'sad'),
  _Q("Even at 3am, you are not as alone as it feels.", '就算凌晨三點，你也沒有感覺中那麼孤單。', 'lonely'),
  _Q("Someone would be glad you're still here. Including me.", '有人會慶幸你還在，包括我。', 'lonely'),
  _Q("Reaching out is brave, not a burden.", '求助是勇敢，不是負擔。', 'lonely'),
  _Q("The moon is far away too, yet it still lights the way home.", '月亮也離得很遠，卻仍照亮回家的路。', 'lonely'),
  _Q("Rest is not quitting. Rest is how you keep going.", '休息不是放棄，休息是你走下去的方式。', 'tired'),
  _Q("You are allowed to do less today.", '今天，你可以少做一點。', 'tired'),
  _Q("You are a person, not a to-do list.", '你是一個人，不是一張待辦清單。', 'tired'),
  _Q("Put it down for now. It'll still be there when you're stronger.", '先放下吧，等你有力氣了它還在。', 'tired'),
  _Q("Tired is a signal, not a failure.", '累，是一個訊號，不是一種失敗。', 'tired'),
  _Q("If a friend said this about themselves, what would you say?", '如果好朋友這樣說自己，你會怎麼回他？', 'harsh'),
  _Q("You are more than one word. More than one mistake.", '你不只是一個詞，你不只是一個錯誤。', 'harsh'),
  _Q("Progress, not perfect. You can be a work in progress.", '進步就好，不用完美。你可以是還在完成中的自己。', 'harsh'),
  _Q("The voice being cruel to you isn't telling the truth.", '那個對你狠心的聲音，說的不是事實。', 'harsh'),
  _Q("You're doing better than the story in your head says.", '你比腦中那個故事說的，做得更好。', 'harsh'),
  _Q("Your mind is loud tonight. You needn't believe all it says.", '今晚思緒很吵，你不必相信它說的每一句。', 'night'),
  _Q("You don't need to solve your whole life at 3am.", '你不需要在凌晨三點解決你的一整個人生。', 'night'),
  _Q("Just rest your body. Sleep can come later.", '先讓身體休息，睡意晚點會來。', 'night'),
  _Q("The night always ends. Morning is on its way.", '夜晚總會結束，早晨正在路上。', 'night'),
  _Q("One small step today still counts as forward.", '今天一小步，仍然算前進。', 'cheer'),
  _Q("You showed up. That already matters.", '你出現了，這本身就有意義。', 'cheer'),
  _Q("Being gentle with yourself is also strength.", '對自己溫柔，也是一種力量。', 'cheer'),
  _Q("You're not behind. You're on your own path, your own pace.", '你沒有落後，你走在自己的路上，用自己的步調。', 'cheer'),
  _Q("Luna is keeping pace with you — you set the speed.", '步調由你決定。', 'cheer'),
];

class HopeBoxPage extends ConsumerStatefulWidget {
  const HopeBoxPage({super.key});
  @override
  ConsumerState<HopeBoxPage> createState() => _HopeBoxPageState();
}

class _HopeBoxPageState extends ConsumerState<HopeBoxPage> {
  final List<_Q> _custom = [];
  final Set<String> _fav = {};
  int _index = 0;
  bool _flipped = false;
  bool _onlyFav = false;

  List<_Q> get _deck {
    final all = [..._custom, ..._builtin];
    if (_onlyFav) {
      final f = all.where((q) => _fav.contains(q.en)).toList();
      return f.isEmpty ? all : f;
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    final isZh = copy.isZhTw;
    final deck = _deck;
    if (_index >= deck.length) _index = 0;
    final q = deck[_index];
    final cat = _cats[q.cat]!;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1426),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(isZh ? '希望盒 🌙' : 'Hope Box 🌙',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(_onlyFav ? Icons.favorite : Icons.favorite_border,
                color: const Color(0xFFFF9EC4)),
            tooltip: isZh ? '只看收藏' : 'Favorites only',
            onPressed: () => setState(() { _onlyFav = !_onlyFav; _index = 0; _flipped = false; }),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 6),
            Text('${_index + 1} / ${deck.length}',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => setState(() => _flipped = !_flipped),
                  onHorizontalDragEnd: (d) {
                    if (d.primaryVelocity == null) return;
                    if (d.primaryVelocity! < 0) {
                      _next(deck.length);
                    } else {
                      _prev(deck.length);
                    }
                  },
                  child: _FlipCard(
                    flipped: _flipped,
                    front: _cardFace(cat: cat, isZh: isZh, isFront: true,
                        text: isZh ? cat['zh']! : cat['en']!),
                    back: _cardFace(cat: cat, isZh: isZh, isFront: false,
                        text: isZh ? q.zh : q.en),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _circleBtn(Icons.arrow_back_ios_new, () => _prev(deck.length)),
                  _circleBtn(
                    _fav.contains(q.en) ? Icons.favorite : Icons.favorite_border,
                    () => setState(() {
                      _fav.contains(q.en) ? _fav.remove(q.en) : _fav.add(q.en);
                    }),
                    color: _fav.contains(q.en) ? const Color(0xFFFF6CAB) : Colors.white,
                    big: true,
                  ),
                  _circleBtn(Icons.arrow_forward_ios, () => _next(deck.length)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () => _addDialog(isZh),
                  icon: const Icon(Icons.add, size: 20),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(isZh ? '寫下自己的話' : 'Add your own',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD166),
                    foregroundColor: const Color(0xFF0D1426),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _next(int len) => setState(() { _index = (_index + 1) % len; _flipped = false; });
  void _prev(int len) => setState(() { _index = (_index - 1 + len) % len; _flipped = false; });

  Widget _circleBtn(IconData icon, VoidCallback onTap, {Color color = Colors.white, bool big = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: big ? 60 : 48, height: big ? 60 : 48,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: big ? 28 : 20),
      ),
    );
  }

  // 卡面：貓咪圖鋪滿 + 漸層遮罩 + 白色粗體可愛字
  Widget _cardFace({
    required Map<String, String> cat,
    required bool isZh,
    required bool isFront,
    required String text,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 貓咪圖鋪滿
          Image.asset(
            cat['img']!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF2A3A5C),
              child: Center(child: Text(cat['emoji']!, style: const TextStyle(fontSize: 80))),
            ),
          ),
          // 底部深色漸層（讓白字看得清）
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: isFront ? 0.15 : 0.30),
                  Colors.black.withValues(alpha: isFront ? 0.35 : 0.68),
                ],
                stops: const [0.45, 1.0],
              ),
            ),
          ),
          // 文字
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat['emoji']!, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 10),
                if (isFront) ...[
                  Text(
                    text,
                    style: TextStyle(
                      color: Colors.white, fontSize: 34, fontWeight: FontWeight.w600,
                      shadows: [const Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(isZh ? '👆 點一下翻開' : '👆 Tap to reveal',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w400)),
                  ),
                ] else
                  Text(
                    text,
                    style: TextStyle(
                      color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600, height: 1.4,
                      shadows: [const Shadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 2))],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addDialog(bool isZh) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2540),
        title: Text(isZh ? '寫一句給自己的話' : 'Write a note to yourself',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: TextField(
          controller: ctrl, autofocus: true, maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: isZh ? '例如：這也會過去的。' : 'e.g. This too shall pass.',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true, fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isZh ? '取消' : 'Cancel', style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty) {
                setState(() {
                  _custom.insert(0, _Q(t, t, 'custom'));
                  _fav.add(t);
                  _index = 0; _flipped = false;
                });
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD166), foregroundColor: const Color(0xFF0D1426)),
            child: Text(isZh ? '收藏' : 'Save'),
          ),
        ],
      ),
    );
  }
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({required this.flipped, required this.front, required this.back});
  final bool flipped;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: flipped ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      builder: (context, t, child) {
        final angle = t * math.pi;
        final showBack = t > 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle),
          child: showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: back)
              : front,
        );
      },
    );
  }
}
