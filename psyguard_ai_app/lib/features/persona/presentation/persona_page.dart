// ═══════════════════════════════════════════════════════════
// lii - 每週情緒人設卡 🦦🦫🐢🐿️🐻🦋
//
// 根據這週實際的心情/壓力/活力記錄，自動給一張當週的動物人設。
// 不用做題，系統自己算。6 隻動物，每週可能不同，有收集感。
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_strings.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../core/storage/database_provider.dart';

enum _Persona { otter, capybara, turtle, squirrel, bear, butterfly }

class WeeklyPersonaPage extends ConsumerStatefulWidget {
  const WeeklyPersonaPage({super.key});
  @override
  ConsumerState<WeeklyPersonaPage> createState() => _WeeklyPersonaPageState();
}

class _WeeklyPersonaPageState extends ConsumerState<WeeklyPersonaPage> {
  bool _loading = true;
  _Persona _persona = _Persona.capybara;
  double _avgMood = 0, _avgStress = 0, _avgEnergy = 0;
  int _days = 0;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  Future<void> _compute() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final since = _normalizeDay(DateTime.now().subtract(const Duration(days: 6)));
      final checkins = await db.getCheckinsSince(since);
      if (checkins.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      double mood = 0, stress = 0, energy = 0;
      double minMood = 100, maxMood = 0;
      for (final c in checkins) {
        mood += c.moodScore;
        stress += c.stressScore;
        energy += c.energyScore;
        if (c.moodScore < minMood) minMood = c.moodScore.toDouble();
        if (c.moodScore > maxMood) maxMood = c.moodScore.toDouble();
      }
      final n = checkins.length;
      _avgMood = mood / n;
      _avgStress = stress / n;
      _avgEnergy = energy / n;
      _days = n;
      final swing = maxMood - minMood;
      _persona = _decide(_avgMood, _avgStress, _avgEnergy, swing);
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _normalizeDay(DateTime d) => DateTime(d.year, d.month, d.day);

  _Persona _decide(double mood, double stress, double energy, double swing) {
    // 情緒起伏很大 -> 蝴蝶
    if (swing >= 40) return _Persona.butterfly;
    // 心情低 + 活力低 -> 睏睏熊（需要休息）
    if (mood < 45 && energy < 45) return _Persona.bear;
    // 壓力高 + 風險/心情還撐著 -> 松鼠（想很多）或烏龜（有韌性）
    if (stress >= 60) {
      return mood < 50 ? _Persona.squirrel : _Persona.turtle;
    }
    // 心情高 + 壓力低 -> 悠悠水獺
    if (mood >= 60 && stress < 45) return _Persona.otter;
    // 其他（平和）-> 淡定水豚
    return _Persona.capybara;
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
        title: Text(isZh ? '本週人設' : 'This Week\'s You',
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (_days == 0 ? _buildEmpty(isZh) : _buildCard(isZh)),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isZh) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            isZh
                ? '這週還沒有足夠的心情記錄～\n先去打卡幾天，我就能給你當週的動物人設！'
                : 'Not enough check-ins this week yet.\nLog a few days and I\'ll reveal your animal!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(bool isZh) {
    final info = _personaInfo(_persona, isZh);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [info.color1, info.color2],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(info.emoji, style: const TextStyle(fontSize: 80)),
                const SizedBox(height: 12),
                Text(isZh ? '本週的你是' : 'This week you are',
                    style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.9))),
                const SizedBox(height: 4),
                Text(info.name,
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(info.desc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 這週數據小結
          Text(isZh ? '這週的你（$_days 天記錄）' : 'Your week ($_days days logged)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _statRow(isZh ? '心情' : 'Mood', _avgMood, const Color(0xFF66BB6A)),
          _statRow(isZh ? '壓力' : 'Stress', _avgStress, const Color(0xFFFFA726)),
          _statRow(isZh ? '活力' : 'Energy', _avgEnergy, const Color(0xFF42A5F5)),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: LumiTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
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

  Widget _statRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 52, child: Text(label, style: const TextStyle(fontSize: 14))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0.0, 1.0),
                backgroundColor: const Color(0xFFE3E8EF),
                color: color,
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text('${value.round()}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  _PersonaInfo _personaInfo(_Persona p, bool isZh) {
    switch (p) {
      case _Persona.otter:
        return _PersonaInfo('🦦', isZh ? '悠悠水獺' : 'Chill Otter',
            isZh ? '這週的你像浮在水面的水獺，放鬆又自在～繼續保持這份輕盈 🤍'
                : 'Floating and easy this week, like an otter on the water. Keep that lightness 🤍',
            const Color(0xFF7BB8A8), const Color(0xFF4E8C7E));
      case _Persona.capybara:
        return _PersonaInfo('🦫', isZh ? '淡定水豚' : 'Zen Capybara',
            isZh ? '這週的你像泡溫泉的水豚，穩穩的、暖暖的，把自己照顧得很好。'
                : 'Steady and warm this week, like a capybara in a hot spring. You took good care of yourself.',
            const Color(0xFFC9A87C), const Color(0xFF9E7B4F));
      case _Persona.turtle:
        return _PersonaInfo('🐢', isZh ? '堅韌小龜' : 'Resilient Turtle',
            isZh ? '這週壓力不小，但你像小烏龜一樣，慢慢走、穩穩撐住了，真的很棒。'
                : 'A heavy week, but like a turtle you kept going slow and steady. That took real strength.',
            const Color(0xFF88C0A0), const Color(0xFF5C9478));
      case _Persona.squirrel:
        return _PersonaInfo('🐿️', isZh ? '忙碌松鼠' : 'Busy Squirrel',
            isZh ? '這週的你像囤東西的小松鼠，想了好多事～記得也留點空間給自己休息。'
                : 'You carried a lot this week, like a squirrel hoarding acorns. Remember to leave space to rest.',
            const Color(0xFFD3A87E), const Color(0xFFA87B50));
      case _Persona.bear:
        return _PersonaInfo('🐻', isZh ? '睏睏熊' : 'Sleepy Bear',
            isZh ? '這週有點累吧？像想冬眠的小熊。休息不是偷懶，是充電 🤍'
                : 'A tiring week? Like a bear ready to hibernate. Rest isn\'t lazy — it\'s recharging 🤍',
            const Color(0xFFB79B82), const Color(0xFF8A7059));
      case _Persona.butterfly:
        return _PersonaInfo('🦋', isZh ? '翩翩蝴蝶' : 'Fluttering Butterfly',
            isZh ? '這週心情像蝴蝶飛上飛下～起伏是正常的，你已經很努力在飛了。'
                : 'Your mood danced up and down this week like a butterfly. Ups and downs are normal — you\'re flying hard.',
            const Color(0xFFB79BD1), const Color(0xFF8A6BB0));
    }
  }
}

class _PersonaInfo {
  final String emoji;
  final String name;
  final String desc;
  final Color color1;
  final Color color2;
  const _PersonaInfo(this.emoji, this.name, this.desc, this.color1, this.color2);
}
