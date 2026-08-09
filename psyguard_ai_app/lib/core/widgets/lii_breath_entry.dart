// ═══════════════════════════════════════════════════════════
// lii · 呼吸入口
//
// 首頁角落的一顆小球，自己輕輕呼吸，點下去進入呼吸會話。
//
// 對應規則沿用你 risk_engine 裡本來就有的門檻，不另外發明：
//   ERS >= 70 → safety flow（序曲壓成 5 秒 + 求助入口）
//   ERS >= 40 → check-in（序曲縮到 60%）
//   其餘      → daily（完整序曲）
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pacer/breath_plan.dart';
import 'lii_breath_page.dart';
import 'package:go_router/go_router.dart';
import 'lii_orb.dart';
import '../crystals/crystal_collection_page.dart';

/// 入口按鈕的位置。撞到你其他浮動元件的話改這裡就好。
const double kLiiEntryRight = 18;
const double kLiiEntryBottom = 350;
const double kLiiEntrySize = 110;

/// ERS 分數 → 用哪種模式出現。門檻跟 risk_engine 一致。
LiiBreathMode liiModeFromErs(int ers) {
  if (ers >= 70) return LiiBreathMode.safety;
  if (ers >= 40) return LiiBreathMode.checkIn;
  return LiiBreathMode.daily;
}

/// 心情 / 壓力 / 活力 → 用哪一組節奏（0–100）。
///
/// 低落和焦慮要分開，因為處理方式是相反的：
/// 焦慮用長吐氣壓交感神經；低落用長吐氣只會更往下沉，要等長節奏提振。
// BREATH_ERS 用 ERS 分數決定節奏，門檻跟首頁表情顏色完全一樣
// （LumiTheme.riskColor：<=40 綠 / 41-70 黃 / >70 紅）。
//   綠 calm     4-2-4-2 -> 4-4-4-4   維持
//   黃 low      3-0-3-0 -> 4-0-4-0   短促，先讓身體動起來
//   紅 anxious  4-2-4-0 -> 4-7-8-0   吐氣拉長，把喚起度壓下來
BreathMood liiMoodFromErs(int ers) {
  if (ers <= 40) return BreathMood.calm;
  if (ers <= 70) return BreathMood.low;
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
      final x = p.getDouble('lii_orb_x');
      final y = p.getDouble('lii_orb_y');
      if (!mounted) return;
      setState(() {
        // if (v != null) _size = v; // 暫時不讀存檔，避免讀回過大的尺寸
        if (x != null && y != null) _pos = Offset(x, y);
      });
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
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
    );
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
            _size = (_size + (dx + dy)).clamp(40.0, 240.0);
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
                    _size = (_size + gx + gy).clamp(44.0, 240.0);
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
                breath: _b,
                split: _split,
                amplitude: 1,
                lunaGlow: 0.42,
              ),
            ),
          ),
        ),
      ]);
    });
  }

}
