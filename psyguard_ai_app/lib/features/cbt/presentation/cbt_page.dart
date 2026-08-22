// ═══════════════════════════════════════════════════════════
// PsyGuard AI / lii - CBT 思考教練頁面 🧠💭
//
// 5 步驟 CBT 思考練習，由寵物溫柔引導：
//   1. 情緒評分（前）  — 現在心情幾分？
//   2. 說出困擾         — 發生什麼事、你怎麼想
//   3. AI 辨識扭曲      — 溫柔指出思考陷阱
//   4. 引導重構         — 蘇格拉底式問句，換個角度
//   5. 情緒評分（後）  — 現在感覺如何？看見變化
//
// 英文優先（demo 用），中英雙語。
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/cbt/cbt_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_strings.dart';
import '../../../core/security/local_settings_service.dart';

enum _Step { moodBefore, describe, analyzing, reframe, evidence, moodAfter, done }

class CbtPage extends ConsumerStatefulWidget {
  const CbtPage({super.key});

  @override
  ConsumerState<CbtPage> createState() => _CbtPageState();
}

class _CbtPageState extends ConsumerState<CbtPage> {
  _Step _step = _Step.moodBefore;
  int _moodBefore = 5;
  int _moodAfter = 5;
  final _controller = TextEditingController();
  final _evidenceForController = TextEditingController();
  final _evidenceAgainstController = TextEditingController();
  CbtAnalysis? _analysis;
  String _petName = 'Luna';
  String _petType = 'otter';

  @override
  void initState() {
    super.initState();
    _loadPet();
  }

  Future<void> _loadPet() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _petName = prefs.getString('pet_name') ?? 'Luna';
      _petType = prefs.getString('pet_type') ?? 'otter';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _evidenceForController.dispose();
    _evidenceAgainstController.dispose();
    super.dispose();
  }

  String get _petEmoji => _petType == 'capybara' ? '🦫' : '🦦';

  Future<void> _analyze(bool isZh) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _step = _Step.analyzing);

    final service = ref.read(cbtServiceProvider);
    final result = await service.analyzeThought(userText: text, isZh: isZh);

    if (!mounted) return;
    setState(() {
      _analysis = result;
      _step = _Step.reframe;
    });
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
        title: Text(isZh ? '思考教練' : 'Thought Coach',
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildStep(isZh),
        ),
      ),
    );
  }

  Widget _buildStep(bool isZh) {
    switch (_step) {
      case _Step.moodBefore:
        return _moodStep(
          isZh: isZh,
          title: isZh ? '現在心情幾分？' : 'How are you feeling right now?',
          value: _moodBefore,
          onChanged: (v) => setState(() => _moodBefore = v),
          onNext: () => setState(() => _step = _Step.describe),
        );
      case _Step.describe:
        return _describeStep(isZh);
      case _Step.analyzing:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_petEmoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(isZh ? '讓我想想…' : 'Let me think…',
                  style: const TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
        );
      case _Step.reframe:
        return _reframeStep(isZh);
      case _Step.evidence:
        return _evidenceStep(isZh);
      case _Step.moodAfter:
        return _moodStep(
          isZh: isZh,
          title: isZh ? '現在感覺如何？' : 'How do you feel now?',
          value: _moodAfter,
          onChanged: (v) => setState(() => _moodAfter = v),
          onNext: () => setState(() => _step = _Step.done),
        );
      case _Step.done:
        return _doneStep(isZh);
    }
  }

  // 情緒評分（前/後共用）
  Widget _moodStep({
    required bool isZh,
    required String title,
    required int value,
    required ValueChanged<int> onChanged,
    required VoidCallback onNext,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Text(_petEmoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Text('$value',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w600,
                color: _moodColor(value))),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          activeColor: _moodColor(value),
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isZh ? '很低落' : 'Very low',
                style: const TextStyle(color: Color(0xFF9AA5B1), fontSize: 12)),
            Text(isZh ? '很好' : 'Great',
                style: const TextStyle(color: Color(0xFF9AA5B1), fontSize: 12)),
          ],
        ),
        const Spacer(),
        _primaryButton(isZh ? '下一步' : 'Next', onNext),
      ],
    );
  }

  Widget _describeStep(bool isZh) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Text(_petEmoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isZh
                    ? '發生什麼事了？你心裡怎麼想的？'
                    : 'What happened? What went through your mind?',
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _controller,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: isZh
                ? '例如：我考試考差了，我覺得自己什麼都做不好…'
                : 'e.g. I failed my test, I feel like I can\'t do anything right…',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const Spacer(),
        _primaryButton(isZh ? '整理一下' : 'Sort it out', () => _analyze(isZh)),
      ],
    );
  }

  Widget _reframeStep(bool isZh) {
    final a = _analysis;
    if (a == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // 偵測到的思考陷阱
          if (a.distortion != Distortion.none)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      size: 16, color: Color(0xFFE0863A)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      (isZh ? '思考陷阱：' : 'Thinking trap: ') +
                          a.distortion.labelFor(isZh),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE0863A)),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // 寵物溫柔重構
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFB2EBE9)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_petEmoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(a.gentleReframe,
                      style: const TextStyle(fontSize: 15, height: 1.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 引導問句
          Text(isZh ? '一起想想：' : 'Let\'s reflect:',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...a.questions.map((q) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💭', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(q,
                          style: const TextStyle(fontSize: 14, height: 1.45)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          _primaryButton(
              isZh ? '想過了，繼續' : 'I\'ve reflected, continue',
              () => setState(() => _step = _Step.evidence)),
        ],
      ),
    );
  }

  Widget _doneStep(bool isZh) {
    final diff = _moodAfter - _moodBefore;
    final better = diff > 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_petEmoji, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 20),
        Text(
          better
              ? (isZh ? '你的心情從 $_moodBefore 分到 $_moodAfter 分 🌱' : 'You went from $_moodBefore to $_moodAfter 🌱')
              : (isZh ? '謝謝你願意花時間整理想法 💙' : 'Thank you for taking time to sort through this 💙'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          better
              ? (isZh
                  ? '想法換個角度，感覺就不一樣了。這就是 CBT 的力量。'
                  : 'A shift in perspective changes how you feel. That\'s the power of CBT.')
              : (isZh
                  ? '有時候光是說出來，就已經是照顧自己了。'
                  : 'Sometimes just naming it is already taking care of yourself.'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
        ),
        const SizedBox(height: 40),
        _primaryButton(isZh ? '完成' : 'Done', () => Navigator.of(context).pop()),
      ],
    );
  }

  Widget _evidenceStep(bool isZh) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              Text(_petEmoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isZh ? '這個想法，證據夠嗎？' : 'Is there real evidence?',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isZh
                ? '寫下來、用看的檢視，比在腦中相信更清楚。'
                : 'Writing it down lets you examine the thought at reading speed.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
          ),
          const SizedBox(height: 20),
          Text(isZh ? '✅ 支持這個想法的證據' : '✅ Evidence FOR this thought',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF66BB6A))),
          const SizedBox(height: 8),
          TextField(
            controller: _evidenceForController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: isZh ? '例如：我這次真的沒準備好' : 'e.g. I really didn\'t prepare this time',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(isZh ? '🔍 反對這個想法的證據' : '🔍 Evidence AGAINST this thought',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF5A9B9E))),
          const SizedBox(height: 8),
          TextField(
            controller: _evidenceAgainstController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: isZh ? '例如：上次數學我其實進步了' : 'e.g. I actually improved in math last time',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _primaryButton(isZh ? '完成檢視' : 'Done examining', () {
            if (_evidenceForController.text.trim().isEmpty ||
                _evidenceAgainstController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(isZh
                    ? '兩邊都寫一點，才能看得更清楚喔 🌱'
                    : 'Write a little on both sides to see more clearly 🌱'),
                duration: const Duration(seconds: 2),
              ));
              return;
            }
            setState(() => _step = _Step.moodAfter);
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: LumiTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Color _moodColor(int v) {
    if (v <= 3) return const Color(0xFFEF5350);
    if (v <= 6) return const Color(0xFFFFA726);
    return const Color(0xFF66BB6A);
  }
}
