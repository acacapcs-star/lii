// ═══════════════════════════════════════════════════════════
// lii · 呼吸入口
//
// 首頁角落的一顆小球，自己輕輕呼吸，點下去進入呼吸會話。
//
// 對應規則沿用你 risk_engine 裡本來就有的門檻，不另外發明：
//   ERS >= 70 → safety flow（序曲壓成 5 秒 + 求助入口）
//   ERS >= 45 → check-in（序曲縮到 60%）
//   門檻和 ers_engine 一致：0–44 綠、45–69 黃、70 以上紅。
//   其餘      → daily（完整序曲）
// ═══════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pacer/breath_plan.dart';
import 'lii_breath_page.dart';
import 'package:go_router/go_router.dart';
import 'lii_orb.dart';
import 'luna_orb.dart' show GlassTone;
import '../crystals/crystal_collection_page.dart';

/// 入口按鈕的位置。撞到你其他浮動元件的話改這裡就好。
const double kLiiEntryRight = 18;
const double kLiiEntryBottom = 350;
const double kLiiEntrySize = 110;

/// 球可以調的大小範圍。
///
/// 上限從 240 收到 180：之前存到過大的尺寸，整顆球會蓋住首頁，
/// 只好把讀取存檔整個關掉。現在讀回來時一律夾在這個範圍裡，
/// 存檔就可以重新打開了。
const double kLiiOrbMin = 44;
const double kLiiOrbMax = 180;

/// Joy-Con 控制器固定在畫面下方中間，離底部多遠。
/// 撞到底部導覽列的話，把這個數字調大。
const double kJoyBottom = 110;

/// ERS 分數 → 用哪種模式出現。門檻跟 risk_engine 一致。
LiiBreathMode liiModeFromErs(int ers) {
  if (ers >= 70) return LiiBreathMode.safety;
  if (ers >= 45) return LiiBreathMode.checkIn;
  return LiiBreathMode.daily;
}

/// 心情 / 壓力 / 活力 → 用哪一組節奏（0–100）。
///
/// 低落和焦慮要分開，因為處理方式是相反的：
/// 焦慮用長吐氣壓交感神經；低落用長吐氣只會更往下沉，要等長節奏提振。
// BREATH_ERS 用 ERS 分數決定節奏，門檻和 ers_engine、首頁狀態文字同一組：
// 0–44 綠 / 45–69 黃 / 70 以上紅。以前這裡是 40 / 70，
// 導致 70 分時序曲用安全模式、節奏卻是黃燈的，同一個分數兩種說法。
//   綠 calm     4-2-4-2 -> 4-4-4-4   維持
//   黃 low      3-0-3-0 -> 4-0-4-0   短促，先讓身體動起來
//   紅 anxious  4-2-4-0 -> 4-7-8-0   吐氣拉長，把喚起度壓下來
BreathMood liiMoodFromErs(int ers) {
  if (ers < 45) return BreathMood.calm;
  if (ers < 70) return BreathMood.low;
  return BreathMood.anxious;
}

BreathMood liiMoodFromSignals({
  required int mood,
  required int stress,
  required int energy,
}) {
  if (mood <= 35 && energy <= 30) return BreathMood.low;
  if (stress >= 65) return BreathMood.anxious;
  if (mood <= 35) return BreathMood.low;
  return BreathMood.calm;
}

class LiiBreathButton extends StatefulWidget {
  /// 目前的 ERS（riskScore）。給 null 就當 daily。
  final int? ers;

  /// 目前的情緒訊號。給 null 就當 calm。
  final int? mood;
  final int? stress;
  final int? energy;

  // BREATH_ERS 有 ERS 就優先用它，沒有才回退到三個滑桿分數
  final int? ersScore;

  /// safety flow 那顆「我現在想找人說話」按下去要做什麼
  final VoidCallback? onAskForHelp;

  const LiiBreathButton({
    super.key,
    this.ers,
    this.mood,
    this.stress,
    this.energy,
    this.ersScore,
    this.onAskForHelp,
  });

  @override
  State<LiiBreathButton> createState() => _LiiBreathButtonState();
}

class _LiiBreathButtonState extends State<LiiBreathButton>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final SilentBreath _silent = SilentBreath();
  final OrbSplit _split = OrbSplit();
  double _b = 0;

  // RESIZABLE_ORB 球的大小由使用者決定，記在本機。
  double _size = 90; // 暫時寫死，把存起來的過大尺寸蓋掉
  Offset? _pos;
  double _moved = 0;
  double _sizeAtStart = kLiiEntrySize;
  int _skip = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    SharedPreferences.getInstance().then((p) {
      final v = p.getDouble('lii_orb_size');
      final ti = p.getInt(kOrbTonePrefKey);
      final x = p.getDouble('lii_orb_x');
      final y = p.getDouble('lii_orb_y');
      if (!mounted) return;
      setState(() {
        if (v != null) _size = v.clamp(kLiiOrbMin, kLiiOrbMax);
        if (ti != null && ti >= 0 && ti < GlassTone.values.length) {
          _tone = GlassTone.values[ti];
        }
        if (x != null && y != null) _pos = Offset(x, y);
      });
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _hideSlider?.cancel();
    _stickTimer?.cancel();
    _zoomTimer?.cancel();
    super.dispose();
  }

  // ── 大小拉桿 ─────────────────────────────────────────
  //
  // 四個角可以拉，但把手是透明的，第一次用的人不會知道。
  // 點兩下球就跳出一條拉桿，看得到、也調得準；
  // 停手 3 秒自己收起來，不會一直留在首頁上。
  bool _sliderOpen = false;
  Timer? _hideSlider;

  void _openSizeSlider() {
    setState(() => _sliderOpen = true);
    _keepSliderOpen();
  }

  void _keepSliderOpen() {
    _hideSlider?.cancel();
    _hideSlider = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _sliderOpen = false);
    });
  }

  // ── Joy-Con 控制器 ───────────────────────────────────
  //
  // 左邊是搖桿：往哪推球就往哪走，推越多走越快，放開就停。
  // 右邊兩顆鍵：按住「＋」一直放大、按住「－」一直縮小。
  // 小的 ◎ 是回到原本右下角的位置。
  Timer? _stickTimer;
  Timer? _zoomTimer;
  Offset _stick = Offset.zero; // 每個方向 -1 ~ 1
  double _curLeft = 0, _curTop = 0;

  static const double _stickR = 32;

  void _stickStart() {
    _hideSlider?.cancel();
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
    _savePos();
    _keepSliderOpen();
  }

  void _zoomOnce(double d) =>
      setState(() => _size = (_size + d).clamp(kLiiOrbMin, kLiiOrbMax));

  void _zoomStart(double d) {
    _hideSlider?.cancel();
    _zoomOnce(d);
    _zoomTimer?.cancel();
    _zoomTimer = Timer.periodic(
        const Duration(milliseconds: 60), (_) => _zoomOnce(d));
  }

  void _zoomEnd() {
    _zoomTimer?.cancel();
    _saveSize();
    _keepSliderOpen();
  }

  /// 回到原本的預設位置（右下角）
  Future<void> _resetPos() async {
    setState(() => _pos = null);
    final p = await SharedPreferences.getInstance();
    await p.remove('lii_orb_x');
    await p.remove('lii_orb_y');
    _keepSliderOpen();
  }

  /// Joy-Con 上的圓鍵。按住會一直觸發（放大縮小用）。
  Widget _joyButton(IconData icon, String tip,
      {required VoidCallback onDown, VoidCallback? onUp, double size = 32}) {
    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTapDown: (_) => onDown(),
        onTapUp: (_) => onUp?.call(),
        onTapCancel: () => onUp?.call(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.14),
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, size: size * 0.5, color: Colors.white),
        ),
      ),
    );
  }

  Widget _sizeSlider({required double orbLeft, required double orbTop,
      required double w, required double h}) {
    const panelW = 168.0, panelH = 84.0;
    // 固定在畫面下方中間，不跟著球跑——球移動時控制器不會跟著晃
    final left = ((w - panelW) / 2).clamp(8.0, w);
    final top = (h - panelH - kJoyBottom).clamp(8.0, h);
    const knob = 28.0;
    return Positioned(
      left: left,
      top: top,
      width: panelW,
      height: panelH,
      child: Container(
        // Joy-Con 的膠囊外型
        decoration: BoxDecoration(
          color: const Color(0xFF1B2233).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(panelH / 2),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 6)),
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
                      left: _stickR - knob / 2 + _stick.dx * (_stickR - knob / 2),
                      top: _stickR - knob / 2 + _stick.dy * (_stickR - knob / 2),
                      width: knob,
                      height: knob,
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: Alignment(-0.3, -0.35),
                            colors: [Color(0xFFFFE9A8), Color(0xFFFFB84A)],
                          ),
                          boxShadow: [
                            BoxShadow(color: Color(0x66FFD166), blurRadius: 10),
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
                _joyButton(Icons.add_rounded, '放大',
                    onDown: () => _zoomStart(4), onUp: _zoomEnd),
                const SizedBox(height: 4),
                _joyButton(Icons.remove_rounded, '縮小',
                    onDown: () => _zoomStart(-4), onUp: _zoomEnd),
              ],
            ),
            const SizedBox(width: 8),
            // 回到原位
            _joyButton(Icons.center_focus_strong_outlined, '回到原位',
                onDown: _resetPos, size: 24),
          ],
        ),
      ),
    );
  }

  void _tick(Duration now) {
    _b = _silent.valueAt(now.inMicroseconds / 1e6);
    // 首頁常駐的東西不需要 60fps。8–12 秒一次的呼吸，30fps 完全看不出差別。
    _skip = (_skip + 1) % 2;
    if (_skip != 0) return;
    if (mounted) setState(() {});
  }

  void _open() {
    final mode = widget.ers == null
        ? LiiBreathMode.daily
        : liiModeFromErs(widget.ers!);
    // BREATH_ERS 優先用 ERS（跟首頁的紅黃綠同一組門檻），
    // 沒有 ERS 紀錄才回退到三個滑桿分數的舊規則。
    final BreathMood mood;
    if (widget.ersScore != null) {
      mood = liiMoodFromErs(widget.ersScore!);
    } else if (widget.mood == null ||
        widget.stress == null ||
        widget.energy == null) {
      mood = BreathMood.calm;
    } else {
      mood = liiMoodFromSignals(
        mood: widget.mood!,
        stress: widget.stress!,
        energy: widget.energy!,
      );
    }
    showLiiBreath(
      context,
      mood: mood,
      mode: mode,
      onAskForHelp: widget.onAskForHelp,
    ).then((_) => _reloadTone());
  }

  /// 首頁浮球的顏色 = 呼吸頁最後選的那顆水晶。
  /// 解鎖的成就要在首頁看得到，不然練習換來的顏色只存在呼吸頁裡。
  GlassTone _tone = GlassTone.ice;

  Future<void> _reloadTone() async {
    final p = await SharedPreferences.getInstance();
    final i = p.getInt(kOrbTonePrefKey);
    if (!mounted || i == null || i < 0 || i >= GlassTone.values.length) return;
    setState(() => _tone = GlassTone.values[i]);
  }

  // CARD_PREVIEW 長按 → Pacer Lift（你原本就有的那個）
  // 長按 → 水晶收藏
  void _openCard() => showCrystalCollection(context);

  Future<void> _savePos() async {
    if (_pos == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setDouble('lii_orb_x', _pos!.dx);
    await p.setDouble('lii_orb_y', _pos!.dy);
  }

  Future<void> _saveSize() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('lii_orb_size', _size);
  }

  /// FOUR_CORNERS 四個角都能拉。把手是透明的 ——
  /// 手機上不留一個圖示在畫面裡，用法寫在 welcome page。
  Widget _corner({
    required bool left,
    required bool top,
    required double grip,
  }) {
    return Positioned(
      left: left ? 0 : null,
      right: left ? null : 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      width: grip,
      height: grip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          // 往「離開球心」的方向拖 = 變大，不管抓的是哪一個角
          final dx = left ? -d.delta.dx : d.delta.dx;
          final dy = top ? -d.delta.dy : d.delta.dy;
          setState(() {
            _size = (_size + (dx + dy)).clamp(kLiiOrbMin, kLiiOrbMax);
          });
        },
        onPanEnd: (_) => _saveSize(),
        child: const SizedBox.expand(),
      ),
    );
  }

  // ONE_GESTURE 四個功能共用一層手勢，用「起點在哪」和「先往哪個方向動」
  // 決定要做什麼。一旦決定就不中途變卦 —— 這樣它們不會互搶。
  //   四角      → 縮放
  //   中間左右  → 水晶／夜空切換
  //   中間上下  → 移動位置
  //   點著不動  → 進呼吸頁
  String _mode = '';        // '' | 'resize' | 'split' | 'move'
  Offset _start = Offset.zero;
  bool _cornerStart = false;
  bool _flipLeft = false, _flipTop = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      final grip = (_size * 0.22).clamp(18.0, 32.0);
      final pos = _pos ??
          Offset(w - kLiiEntryRight - _size, h - kLiiEntryBottom - _size);
      final left = pos.dx.clamp(0.0, (w - _size).clamp(0.0, w));
      final top = pos.dy.clamp(0.0, (h - _size).clamp(0.0, h));
      _curLeft = left;
      _curTop = top;

      return Stack(children: [
        Positioned(
          left: left,
          top: top,
          width: _size,
          height: _size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (_) {
              if (_mode.isEmpty) _open();
            },
            // 點兩下：跳出大小拉桿
            onDoubleTap: _openSizeSlider,
            onPanStart: (d) {
              _mode = '';
              _start = d.localPosition;
              _flipLeft = d.localPosition.dx < _size / 2;
              _flipTop = d.localPosition.dy < _size / 2;
              final dx = _flipLeft
                  ? d.localPosition.dx
                  : _size - d.localPosition.dx;
              final dy = _flipTop
                  ? d.localPosition.dy
                  : _size - d.localPosition.dy;
              _cornerStart = dx < grip && dy < grip;
            },
            onPanUpdate: (d) {
              final off = d.localPosition - _start;
              // 還沒決定要做什麼：等移動超過 6px 再判斷
              if (_mode.isEmpty) {
                if (off.distance < 6) return;
                if (_cornerStart) {
                  _mode = 'resize';
                } else {
                  _mode = off.dx.abs() > off.dy.abs() ? 'split' : 'move';
                }
              }
              setState(() {
                switch (_mode) {
                  case 'resize':
                    final gx = _flipLeft ? -d.delta.dx : d.delta.dx;
                    final gy = _flipTop ? -d.delta.dy : d.delta.dy;
                    _size = (_size + gx + gy).clamp(kLiiOrbMin, kLiiOrbMax);
                    break;
                  case 'split':
                    _split.dragBy(d.delta.dx, _size);
                    break;
                  case 'move':
                    _pos = Offset(left, top) + d.delta;
                    break;
                }
              });
            },
            onPanEnd: (_) {
              if (_mode == 'resize') _saveSize();
              if (_mode == 'move') _savePos();
              if (_mode == 'split') _split.end();
              _mode = '';
            },
            child: IgnorePointer(
              child: LiiOrb(
                tone: _tone,
                breath: _b,
                split: _split,
                amplitude: 1,
                lunaGlow: 0.42,
              ),
            ),
          ),
        ),
        if (_sliderOpen)
          _sizeSlider(orbLeft: left, orbTop: top, w: w, h: h),
      ]);
    });
  }

}
