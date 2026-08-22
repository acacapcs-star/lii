// ═══════════════════════════════════════════════════════════
// lii - 認知扭曲自我檢測測驗 📋🧠
//
// 12 題（6 種認知扭曲各 2 題），做完算出你最容易掉進哪種思考陷阱。
// 像性向測驗，有結果 + 說明 + 練習建議。中英雙語。
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_strings.dart';
import '../../../core/security/local_settings_service.dart';

enum _Distortion {
  allOrNothing,
  overgeneralization,
  jumpingToConclusions,
  emotionalReasoning,
  catastrophizing,
  labeling,
}

class _Q {
  final _Distortion d;
  final String zh;
  final String en;
  const _Q(this.d, this.zh, this.en);
}

const _questions = <_Q>[
  _Q(_Distortion.allOrNothing, '事情不是完全成功，就是徹底失敗', "If it's not a total success, it's a total failure"),
  _Q(_Distortion.allOrNothing, '我要嘛做到最好，要嘛乾脆不做', "It's all or nothing for me"),
  _Q(_Distortion.overgeneralization, '一次搞砸，我會覺得以後都會這樣', "One failure means it'll always be like this"),
  _Q(_Distortion.overgeneralization, '我常用「總是」「從來」形容自己的失敗', "I use 'always' and 'never' about my setbacks"),
  _Q(_Distortion.jumpingToConclusions, '別人沒回訊息，我會覺得他討厭我', "If someone doesn't reply, they must dislike me"),
  _Q(_Distortion.jumpingToConclusions, '我常猜別人在想一些對我不好的事', "I often assume others are thinking badly of me"),
  _Q(_Distortion.emotionalReasoning, '我覺得糟，就代表事情真的很糟', "If I feel bad, things must really be bad"),
  _Q(_Distortion.emotionalReasoning, '我的感覺，對我來說就是事實', "My feelings feel like facts to me"),
  _Q(_Distortion.catastrophizing, '遇到問題，我常想到最糟的結果', "I imagine the worst outcome when problems arise"),
  _Q(_Distortion.catastrophizing, '小事也會讓我覺得天要塌了', "Small things can feel like the end of the world"),
  _Q(_Distortion.labeling, '犯錯時，我會覺得自己就是個失敗者', "When I make mistakes, I feel like a failure"),
  _Q(_Distortion.labeling, '我常用一個詞就定義整個自己', "I define my whole self with a single word"),
];

class DistortionQuizPage extends ConsumerStatefulWidget {
  const DistortionQuizPage({super.key});
  @override
  ConsumerState<DistortionQuizPage> createState() => _DistortionQuizPageState();
}

class _DistortionQuizPageState extends ConsumerState<DistortionQuizPage> {
  int _index = 0;
  final List<int> _answers = List.filled(_questions.length, -1);
  bool _done = false;

  void _answer(int score) {
    setState(() {
      _answers[_index] = score;
      if (_index < _questions.length - 1) {
        _index++;
      } else {
        _done = true;
      }
    });
  }

  _Distortion get _result {
    final scores = <_Distortion, int>{};
    for (int i = 0; i < _questions.length; i++) {
      final d = _questions[i].d;
      scores[d] = (scores[d] ?? 0) + (_answers[i] < 0 ? 0 : _answers[i]);
    }
    _Distortion best = _Distortion.allOrNothing;
    int bestScore = -1;
    scores.forEach((d, s) {
      if (s > bestScore) {
        bestScore = s;
        best = d;
      }
    });
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    final isZh = copy.isZhTw;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(isZh ? '思考陷阱測驗' : 'Thinking Trap Quiz',
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _done ? _buildResult(isZh) : _buildQuestion(isZh),
        ),
      ),
    );
  }

  Widget _buildQuestion(bool isZh) {
    final q = _questions[_index];
    final options = isZh
        ? ['很少', '有時', '常常', '總是']
        : ['Rarely', 'Sometimes', 'Often', 'Always'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        // 進度
        LinearProgressIndicator(
          value: (_index + 1) / _questions.length,
          backgroundColor: const Color(0xFFE3E8EF),
          color: LumiTheme.primary,
          minHeight: 6,
        ),
        const SizedBox(height: 8),
        Text('${_index + 1} / ${_questions.length}',
            style: const TextStyle(color: Color(0xFF9AA5B1), fontSize: 13)),
        const SizedBox(height: 40),
        Text(
          isZh ? q.zh : q.en,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4),
        ),
        const SizedBox(height: 40),
        for (int i = 0; i < options.length; i++) ...[
          _optionButton(options[i], () => _answer(i)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _optionButton(String label, VoidCallback onTap) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFDDE3EC)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF344054))),
      ),
    );
  }

  Widget _buildResult(bool isZh) {
    final d = _result;
    final info = _distortionInfo(d, isZh);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Text(info['emoji']!,
              style: const TextStyle(fontSize: 56), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(isZh ? '你最容易掉進的思考陷阱是' : 'Your most likely thinking trap is',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Text(info['name']!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w600, color: LumiTheme.primary)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3E8EF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isZh ? '這是什麼？' : 'What is it?',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 6),
                Text(info['desc']!,
                    style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF475467))),
                const SizedBox(height: 16),
                Text(isZh ? '下次可以練習問自己：' : 'Next time, try asking yourself:',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 6),
                Text(info['tip']!,
                    style: const TextStyle(
                        fontSize: 15, height: 1.5, color: Color(0xFF5A9B9E),
                        fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () => setState(() {
                _index = 0;
                _done = false;
                for (int i = 0; i < _answers.length; i++) {
                  _answers[i] = -1;
                }
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: LumiTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(isZh ? '再測一次' : 'Take again',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(isZh ? '完成' : 'Done',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Map<String, String> _distortionInfo(_Distortion d, bool isZh) {
    switch (d) {
      case _Distortion.allOrNothing:
        return {
          'emoji': '⚫️⚪️',
          'name': isZh ? '非黑即白' : 'All-or-Nothing',
          'desc': isZh
              ? '你傾向把事情看成「全好」或「全壞」，中間沒有灰色地帶。但生活大多在灰色地帶裡。'
              : 'You tend to see things as all good or all bad, with no middle ground. But most of life lives in the grey.',
          'tip': isZh ? '這件事真的只有兩種結果嗎？中間有沒有其他可能？' : 'Are there really only two outcomes? What lies in between?',
        };
      case _Distortion.overgeneralization:
        return {
          'emoji': '🔁',
          'name': isZh ? '過度類化' : 'Overgeneralization',
          'desc': isZh
              ? '一次的失敗，你會當成「永遠都會這樣」。但一次不代表全部。'
              : 'You treat one setback as "it will always be this way." But once is not always.',
          'tip': isZh ? '除了這次，有沒有不一樣的時候？' : 'Besides this time, was there ever a moment that went differently?',
        };
      case _Distortion.jumpingToConclusions:
        return {
          'emoji': '💭',
          'name': isZh ? '妄下結論' : 'Jumping to Conclusions',
          'desc': isZh
              ? '你常在沒有足夠證據時，就認定負面的結論（例如讀別人的心）。'
              : 'You often reach negative conclusions without enough evidence (like mind-reading).',
          'tip': isZh ? '這是事實，還是我的猜測？有沒有其他解釋？' : 'Is this a fact or my guess? Any other explanation?',
        };
      case _Distortion.emotionalReasoning:
        return {
          'emoji': '🌊',
          'name': isZh ? '情緒化推理' : 'Emotional Reasoning',
          'desc': isZh
              ? '你把「感覺」當成「事實」。但你覺得糟，不代表事情真的糟，也不代表你就是糟的。'
              : 'You treat feelings as facts. But feeling bad doesn\'t mean things are bad — or that you are.',
          'tip': isZh ? '這是我的感覺，還是真的發生的事實？' : 'Is this my feeling, or an actual fact?',
        };
      case _Distortion.catastrophizing:
        return {
          'emoji': '⛈️',
          'name': isZh ? '災難化' : 'Catastrophizing',
          'desc': isZh
              ? '你容易想到最糟的結果，把小事放大成災難。'
              : 'You tend to imagine the worst, blowing small things into disasters.',
          'tip': isZh ? '最可能發生的，其實是什麼？' : 'What\'s the most likely outcome, really?',
        };
      case _Distortion.labeling:
        return {
          'emoji': '🏷️',
          'name': isZh ? '貼標籤' : 'Labeling',
          'desc': isZh
              ? '你會用一個詞（例如「魯蛇」「失敗者」）定義整個自己。但你比一個標籤複雜太多。'
              : 'You define your whole self with one word ("loser", "failure"). But you\'re far more than a label.',
          'tip': isZh ? '如果好朋友這樣說自己，我會怎麼回應他？' : 'If a friend said this about themselves, what would I tell them?',
        };
    }
  }
}
