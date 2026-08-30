// ═══════════════════════════════════════════════════════════
// lii · 呼吸會話畫面
//
// 這一層負責「時間」：跑 ticker、算到第幾秒、把 BreathPlan 的結果
// 餵給 LiiOrb，並在段落轉換時輕震一下。
//
// 只 import flutter + 上面那兩個新檔，不碰你的 riverpod / mood / router，
// 所以接壞了也只會壞這一頁。
//
// 用法：
//   showLiiBreath(context, mood: BreathMood.anxious);
//   showLiiBreath(context, mood: BreathMood.low, mode: LiiBreathMode.safety,
//                 onAskForHelp: () => context.push('/safety'));
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../crystals/crystal_collection_page.dart';
import '../audio/tide_sound.dart';
import '../crystals/crystal_store.dart';
import '../pacer/bookmark_quick_add.dart';
import '../pacer/breath_plan.dart';
import 'luna_orb.dart';
import 'lii_orb.dart';

/// 決定「怎麼出現」。ERS 越高，序曲越短 ——
/// 一個 ERS 78 的人不會坐著看 20 秒沒有指令的動畫，他會直接關掉。
enum LiiBreathMode { daily, checkIn, safety, silent }

extension LiiBreathModeX on LiiBreathMode {
  double get overtureScale {
    switch (this) {
      case LiiBreathMode.daily:
        return 1.0;
      case LiiBreathMode.checkIn:
        return 0.6;
      case LiiBreathMode.safety:
      case LiiBreathMode.silent:
        return 0;
    }
  }

  double get lunaGlow {
    switch (this) {
      case LiiBreathMode.daily:
        return 0.65;
      case LiiBreathMode.checkIn:
        return 0.90;
      case LiiBreathMode.safety:
        return 1.0;
      case LiiBreathMode.silent:
        return 0.42;
    }
  }

  String get idleText {
    switch (this) {
      case LiiBreathMode.daily:
        return 'Luna is here';
      case LiiBreathMode.checkIn:
        return 'Luna noticed you';
      case LiiBreathMode.safety:
        return 'You are not alone';
      case LiiBreathMode.silent:
        return 'Silent company';
    }
  }
}

Future<void> showLiiBreath(
  BuildContext context, {
  required BreathMood mood,
  LiiBreathMode mode = LiiBreathMode.daily,
  VoidCallback? onAskForHelp,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (_, __, ___) => LiiBreathPage(
        mood: mood,
        mode: mode,
        onAskForHelp: onAskForHelp,
      ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class LiiBreathPage extends StatefulWidget {
  final BreathMood mood;
  final LiiBreathMode mode;
  final VoidCallback? onAskForHelp;

  const LiiBreathPage({
    super.key,
    required this.mood,
    this.mode = LiiBreathMode.daily,
    this.onAskForHelp,
  });

  @override
  State<LiiBreathPage> createState() => _LiiBreathPageState();
}

class _LiiBreathPageState extends State<LiiBreathPage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final OrbSplit _split = OrbSplit();
  final SilentBreath _silent = SilentBreath();

  BreathPlan? _plan;
  Duration _t0 = Duration.zero;
  bool _running = false;

  double _breath = 0, _meet = 0, _amp = 1;
  Duration _lastTideUpdate = Duration.zero; // 潮聲音量節流用
  GlassTone _tone = GlassTone.ice;

  // 預設關 —— 他可能在課堂上、公車上，聲音會暴露他正在做這件事。
  final TideSound _tide = TideSound();
  double _luna = 1, _you = 1, _stars = 1, _cue = 0;
  String _cueText = '', _status = '', _tempo = '';
  BreathSegment? _lastSeg;

  bool get _isSilent => widget.mode == LiiBreathMode.silent;

  @override
  void initState() {
    super.initState();
    _status = widget.mode.idleText;
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tide.dispose();
    super.dispose();
  }

  void _start() {
    _plan = BreathPlan.build(
      mood: widget.mood,
      overtureScale: widget.mode.overtureScale,
      hardOvertureSeconds: widget.mode == LiiBreathMode.safety ? 5 : null,
    );
    _t0 = Duration.zero;
    _running = true;
    _lastSeg = null;
    setState(() {});
  }

  void _stop([String? msg]) {
    _running = false;
    _plan = null;
    _lastSeg = null;
    setState(() {
      _status = msg ?? widget.mode.idleText;
      _tempo = '';
    });
  }

  void _tick(Duration now) {
    var wantLuna = 1.0, wantYou = 1.0, wantStars = 1.0, wantCue = 0.0;

    if (_isSilent) {
      _breath = _silent.valueAt(now.inMicroseconds / 1e6);
      _meet = 0.55 * _peak(_breath);
      _amp = 1;
      _tempo = 'Irregular \u2014 8 to 12 s \u2014 no guidance';
    } else if (_running && _plan != null) {
      if (_t0 == Duration.zero) _t0 = now;
      final el = (now - _t0).inMicroseconds / 1e6;
      final tick = _plan!.at(el);

      if (tick.finished) {
        _stop('Take your time');
        _leaveWords();
        return;
      }

      _breath = tick.value;
      _meet = tick.meet;
      _amp = tick.amplitude;
      wantLuna = tick.showLuna ? 1 : 0;
      wantYou = tick.showYou ? 1 : 0;
      wantStars = tick.showStars ? 1 : 0;
      wantCue = tick.showCue ? 1 : 0;
      _cueText = tick.cueText;
      _tempo = tick.pattern.label;

      switch (tick.stage) {
        case BreathStage.overture:
          _status = 'Just watch for now \u2014 no need to follow';
          break;
        case BreathStage.ramp:
          _status = 'Follow my pace when you are ready';
          break;
        case BreathStage.main:
          _status = widget.mode.idleText;
          break;
        case BreathStage.outro:
          _status = 'Coming back, slowly';
          break;
      }

      // 段落換了才震一下。序曲不震 —— 那段的意思是「你先看著」，震動等於在催他。
      if (tick.segment != _lastSeg) {
        if (tick.stage != BreathStage.overture) _buzz();
        _lastSeg = tick.segment;
      }
    } else {
      _breath += (0 - _breath) * 0.05;
      _meet = 0;
    }

    // 🌊 潮聲音量跟著呼吸漲退（吸氣漲、吐氣退）；每 60ms 更新一次避免音訊卡頓
    if (_tide.isOn && (now - _lastTideUpdate).inMilliseconds >= 60) {
      _lastTideUpdate = now;
      _tide.update(_breath.clamp(0.0, 1.0));
    }

    _luna += (wantLuna - _luna) * 0.045;
    _you += (wantYou - _you) * 0.045;
    _stars += (wantStars - _stars) * 0.045;
    _cue += (wantCue - _cue) * 0.045;

    final spinning = _split.step();
    final moving =
        _running || _isSilent || _breath > 0.002 || spinning || _cue > 0.002;
    if (mounted && moving) setState(() {});
  }

  double _peak(double v) {
    final u = (v - 0.72) / 0.28;
    return u <= 0 ? 0 : u;
  }

  // BREATH_TO_LIFT 做完呼吸 → Luna 依心情留一句話，掛成一台纜車。
  // 用 SnackBar 不用彈窗：剛做完呼吸的人不該被打斷。
  Future<void> _leaveWords() async {
    final quote = await BookmarkQuickAdd.addFromBreath(widget.mood);
    final newCrystals = await CrystalStore.recordSession();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF16264C),
        duration: const Duration(seconds: 6),
        content: Text(
          'Luna left you a line\n$quote',
          style: const TextStyle(color: Colors.white, height: 1.6),
        ),
        action: newCrystals.isEmpty
            ? null
            : SnackBarAction(
                label: 'New crystal',
                textColor: const Color(0xFFFFD166),
                onPressed: () => showCrystalCollection(context),
              ),
      ),
    );
  }

  void _buzz() {
    // safety flow 要更輕，不是更強。一個已經被淹沒的人不需要更多刺激。
    if (widget.mode == LiiBreathMode.safety) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final side = MediaQuery.of(context).size.width.clamp(200.0, 320.0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF080E18),
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white38),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Close',
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: side,
                    height: side,
                    child: LiiOrb(
                      breath: _breath,
                      split: _split,
                      meet: _meet,
                      amplitude: reduce ? _amp * 0.5 : _amp,
                      lunaOpacity: _luna,
                      youOpacity: _you,
                      starsOpacity: _stars,
                      lunaGlow: widget.mode.lunaGlow,
                      tone: _tone,
                      onTap: () => _running ? _stop() : _start(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // BTN_MOVED 按鈕放在球正下方 —— 原本被擠到六色圓點後面看不到
                  if (!_isSilent)
                    TextButton(
                      onPressed: () => _running ? _stop() : _start(),
                      child: Text(
                        _running ? 'Stop' : 'Start breathing',
                        style: const TextStyle(
                          color: Color(0xFFFFD166),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 22,
                    child: AnimatedOpacity(
                      opacity: _cue > 0.35 ? 1 : 0,
                      duration: const Duration(milliseconds: 350),
                      child: Text(
                        _cueText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          letterSpacing: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _status,
                    style: const TextStyle(
                      color: Colors.white30,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _tempo,
                    style: const TextStyle(
                      color: Colors.white24,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // TONE_PICKER 六色水晶。顏色是練習換來的，不是設定裡挑的。
                  Wrap(
                    spacing: 12,
                    children: GlassTone.values.map((t) {
                      final got = CrystalStore.isUnlocked(t);
                      final on = t == _tone;
                      const cols = [
                        Color(0xFF337FB0),
                        Color(0xFF2A8A88),
                        Color(0xFF7A54B0),
                        Color(0xFFA65F14),
                        Color(0xFF2C7247),
                        Color(0xFFB04E6C),
                      ];
                      return GestureDetector(
                        onTap: () {
                          if (got == false) {
                            final r = kCrystalRules
                                .firstWhere((e) => e.tone == t);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('${t.labelEn}: ${r.requirementEn}'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          setState(() => _tone = t);
                        },
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: got
                                ? cols[t.index]
                                : const Color(0x26FFFFFF),
                            border: Border.all(
                              color: on
                                  ? Colors.white
                                  : const Color(0x33FFFFFF),
                              width: on ? 2.5 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // TIDE_TOGGLE 潮聲開關。預設關，開了音量會跟著呼吸漲退。
                  TextButton.icon(
                    onPressed: () async {
                      if (_tide.isOn) {
                        await _tide.disable();
                      } else {
                        await _tide.enable();
                      }
                      if (mounted) setState(() {});
                    },
                    icon: Icon(
                      _tide.isOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      size: 17,
                      color: _tide.isOn
                          ? const Color(0xFFC8E8FF)
                          : Colors.white38,
                    ),
                    label: Text(
                      _tide.isOn ? 'Tide on' : 'Tide off',
                      style: TextStyle(
                        fontSize: 13,
                        color: _tide.isOn
                            ? const Color(0xFFC8E8FF)
                            : Colors.white38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // safety flow：求助入口從第一秒就在，不用等練習結束。
                  // 呼吸是當下降溫，不是處理，兩個要並存。
                  if (widget.mode == LiiBreathMode.safety)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton(
                        onPressed: widget.onAskForHelp,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0x66C8E8FF), width: 0.5),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 26, vertical: 12),
                        ),
                        child: const Text(
                          'I want to talk to someone',
                          style: TextStyle(
                              color: Color(0xFFC8E8FF),
                              fontSize: 12,
                              letterSpacing: 1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
