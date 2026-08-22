// ═══════════════════════════════════════════════════════════
// lii · 那顆球
//
// 左邊夜空、右邊有色玻璃，可以左右滑動轉面。
// 全部用 Gradient + Path，沒有用任何模糊/發光濾鏡 ——
// 濾鏡在 Flutter web 上要嘛沒對應要嘛掉幀，漸層和路徑則是一對一。
//
// 座標系固定在 160×160（跟原始 SVG 一樣），最後才等比縮放到實際尺寸，
// 所以所有數字都可以直接對照網頁版，改一邊另一邊照抄就好。
// ═══════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'luna_orb.dart';

const double _kUnit = 160;
const double _kR = 80;
const Offset _kC = Offset(80, 80);

/// 轉面的狀態。放在 widget 外面，讓已經有 ticker 的父層每幀呼叫 [step]，
/// 才不會為了一個歸位動畫多開一個 AnimationController。
class OrbSplit {
  /// -80 = 整片玻璃，0 = 對半，+80 = 整片夜空
  double w = 0;
  double target = 0;
  bool dragging = false;
  bool moved = false;
  double _travel = 0;

  void begin() {
    dragging = true;
    moved = false;
    _travel = 0;
  }

  /// [deltaDx] 是這一次的位移增量，[width] 是 widget 寬度
  void dragBy(double deltaDx, double width) {
    _travel += deltaDx.abs();
    if (_travel > 4) moved = true;
    final k = _kUnit / (width <= 0 ? _kUnit : width);
    w = (w + deltaDx * k).clamp(-_kR, _kR);
    target = w;
  }

  /// 放手後吸附到最近的三個位置：全玻璃 / 對半 / 全夜空
  void end() {
    if (!dragging) return;
    dragging = false;
    var best = 0.0;
    for (final v in <double>[-_kR, 0, _kR]) {
      if ((v - w).abs() < (best - w).abs()) best = v;
    }
    target = best;
  }

  /// 每幀呼叫。回傳 true 表示畫面需要重畫。
  bool step() {
    if (dragging) return false;
    if ((target - w).abs() < 0.05) return false;
    w += (target - w) * 0.12;
    return true;
  }
}

class LiiOrb extends StatefulWidget {
  /// 0 = 吐盡，1 = 吸滿
  final double breath;

  /// 水火交融的強度 0..1（BreathTick.meet）
  final double meet;

  /// 呼吸幅度倍率（BreathTick.amplitude）
  final double amplitude;

  /// 序曲用的分層顯示，0..1，父層自己做平滑
  final double lunaOpacity;
  final double youOpacity;
  final double starsOpacity;

  /// Luna 光暈強度，跟著模式走（daily .65 / check-in .90 / safety 1.0 / silent .42）
  final double lunaGlow;

  /// 水晶色。夜空的漸層會跟著它走。
  final GlassTone tone;

  /// 秒數。序曲時兩顆點會飄，主段收攏定位。
  final double time;

  final OrbSplit split;
  final VoidCallback? onTap;

  const LiiOrb({
    super.key,
    required this.breath,
    required this.split,
    this.meet = 0,
    this.amplitude = 1,
    this.lunaOpacity = 1,
    this.youOpacity = 1,
    this.starsOpacity = 1,
    this.lunaGlow = 0.65,
    this.tone = GlassTone.ice,
    this.time = 0,
    this.onTap,
  });

  @override
  State<LiiOrb> createState() => _LiiOrbState();
}

class _LiiOrbState extends State<LiiOrb> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.min(box.maxWidth, box.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => widget.split.begin(),
          onHorizontalDragUpdate: (d) {
            widget.split.dragBy(d.delta.dx, side);
            setState(() {}); // 沒在呼吸的時候也要能轉
          },
          onHorizontalDragEnd: (_) => widget.split.end(),
          onHorizontalDragCancel: () => widget.split.end(),
          onTap: () {
            if (widget.split.moved) return; // 剛剛是在滑，不是點
            widget.onTap?.call();
          },
          child: CustomPaint(
            size: Size(side, side),
            painter: _OrbPainter(
              breath: widget.breath,
              meet: widget.meet,
              amplitude: widget.amplitude,
              w: widget.split.w,
              luna: widget.lunaOpacity,
              you: widget.youOpacity,
              stars: widget.starsOpacity,
              lunaGlow: widget.lunaGlow,
              tone: widget.tone,
              time: widget.time,
            ),
          ),
        );
      },
    );
  }
}

class _Star {
  final double x, y, r;
  final Color c;
  const _Star(this.x, this.y, this.r, this.c);
}

const List<_Star> _kBgStars = <_Star>[
  _Star(30, 22, 0.35, Color.fromRGBO(255, 255, 255, 0.32)),
  _Star(112, 18, 0.35, Color.fromRGBO(255, 255, 255, 0.40)),
  _Star(136, 24, 0.30, Color.fromRGBO(255, 232, 176, 0.32)),
  _Star(148, 38, 0.35, Color.fromRGBO(255, 255, 255, 0.34)),
  _Star(24, 55, 0.30, Color.fromRGBO(255, 255, 255, 0.28)),
  _Star(132, 50, 0.35, Color.fromRGBO(255, 232, 176, 0.34)),
  _Star(18, 88, 0.30, Color.fromRGBO(255, 255, 255, 0.30)),
  _Star(148, 72, 0.35, Color.fromRGBO(255, 255, 255, 0.36)),
  _Star(22, 118, 0.35, Color.fromRGBO(255, 255, 255, 0.26)),
  _Star(138, 100, 0.30, Color.fromRGBO(255, 255, 255, 0.32)),
  _Star(40, 145, 0.30, Color.fromRGBO(255, 255, 255, 0.24)),
  _Star(26, 36, 0.75, Color.fromRGBO(255, 255, 255, 0.52)),
  _Star(128, 26, 0.80, Color.fromRGBO(255, 232, 176, 0.60)),
  _Star(150, 48, 0.75, Color.fromRGBO(255, 255, 255, 0.52)),
  _Star(18, 72, 0.80, Color.fromRGBO(255, 255, 255, 0.48)),
  _Star(146, 68, 0.75, Color.fromRGBO(255, 255, 255, 0.54)),
  _Star(148, 98, 0.75, Color.fromRGBO(255, 255, 255, 0.52)),
  _Star(28, 136, 0.80, Color.fromRGBO(255, 255, 255, 0.44)),
  _Star(140, 136, 0.75, Color.fromRGBO(255, 255, 255, 0.46)),
];

class _OrbPainter extends CustomPainter {
  final double breath, meet, amplitude, w, luna, you, stars, lunaGlow;
  final double time;
  final GlassTone tone;

  _OrbPainter({
    required this.breath,
    required this.meet,
    required this.amplitude,
    required this.w,
    required this.luna,
    required this.you,
    required this.stars,
    required this.lunaGlow,
    this.tone = GlassTone.ice,
    this.time = 0,
  });

  // ── 幾何 ──────────────────────────────────────────────
  // 一顆半邊上色的球轉起來，分界的投影是通過上下極點的橢圓，
  // 橫向半寬 = R·cos(轉角)。轉到正中間時橢圓自己退化成直線，不用寫特例。

  List<Offset> _seamPts(double w) {
    final out = <Offset>[];
    for (var i = 0; i < 26; i++) {
      final a = (-90 + 180 * i / 25) * math.pi / 180;
      out.add(Offset(_kC.dx + w * math.cos(a), _kC.dy + _kR * math.sin(a)));
    }
    return out;
  }

  List<Offset> _rimPts(double a0, double a1) {
    final out = <Offset>[];
    for (var i = 0; i < 30; i++) {
      final a = (a0 + (a1 - a0) * i / 29) * math.pi / 180;
      out.add(Offset(_kC.dx + _kR * math.cos(a), _kC.dy + _kR * math.sin(a)));
    }
    return out;
  }

  Path _poly(List<Offset> pts, {bool close = true}) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      p.lineTo(pts[i].dx, pts[i].dy);
    }
    if (close) p.close();
    return p;
  }

  // ── 小工具 ────────────────────────────────────────────

  void _rectGrad(Canvas c, ui.Gradient g) {
    c.drawRect(const Rect.fromLTWH(0, 0, _kUnit, _kUnit), Paint()..shader = g);
  }

  /// 用畫布縮放畫出「橢圓形的放射漸層」，避免去組 matrix4
  void _radialOval(Canvas c, Offset center, double rx, double ry, double rotDeg,
      List<Color> colors, List<double> stops) {
    c.save();
    c.translate(center.dx, center.dy);
    if (rotDeg != 0) c.rotate(rotDeg * math.pi / 180);
    c.scale(1, ry / rx);
    c.drawCircle(
      Offset.zero,
      rx,
      Paint()..shader = ui.Gradient.radial(Offset.zero, rx, colors, stops),
    );
    c.restore();
  }

  void _layer(Canvas c, double opacity, void Function() body) {
    if (opacity >= 0.999) {
      body();
      return;
    }
    if (opacity <= 0.002) return;
    c.saveLayer(
      const Rect.fromLTWH(0, 0, _kUnit, _kUnit),
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    body();
    c.restore();
  }

  void _dot(Canvas c, Offset o, double r, Color col) {
    c.drawCircle(o, r, Paint()..color = col);
  }

  // ── 主繪製 ────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _kUnit);
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: _kC, radius: _kR)));

    final seam = _seamPts(w);
    final skyPath = _poly(seam + _rimPts(90, 270));
    final glassPath = _poly(seam + _rimPts(90, -90));

    _paintGlassBody(canvas, glassPath);
    _paintSky(canvas, skyPath);
    _paintHeroStars(canvas);
    _paintCapsules(canvas);
    _paintDots(canvas);
    _paintBloom(canvas);
    _paintWordmark(canvas);
    _paintGlassSurface(canvas, glassPath, seam);

    canvas.restore();
  }

  void _paintGlassBody(Canvas c, Path glass) {
    c.save();
    c.clipPath(glass);

    // 有色玻璃：越往下越濃，因為光要穿過的厚度變厚
    _rectGrad(
      c,
      ui.Gradient.linear(
        const Offset(28.8, 0),
        const Offset(115.2, 160),
        const [
          Color(0x57CFEDFF),
          Color(0x4D8FBEE8),
          Color(0x476E7FC6),
          Color(0x574C4E92),
        ],
        const [0.0, 0.38, 0.72, 1.0],
      ),
    );

    _layer(c, (0.72 + 0.28 * breath).clamp(0.0, 1.0), () {
      // 靠近交界處被 Luna 的金光染暖 —— 光源在夜空那側
      _radialOval(c, const Offset(101, 62), 34, 46, 0, const [
        Color(0x6BFFD166),
        Color(0x29FFB830),
        Color(0x00FF9500),
      ], const [0.0, 0.45, 1.0]);

      // 底部焦散光：實心玻璃的招牌。交融時收窄變高，像焦點被對準
      _radialOval(
        c,
        const Offset(113, 119),
        26 - 7 * meet,
        15 + 5 * meet,
        -18,
        const [Color(0x99FFF8E8), Color(0x42FFD8A0), Color(0x00FFC46A)],
        const [0.0, 0.40, 1.0],
      );
    });

    c.restore();
  }

  void _paintSky(Canvas c, Path sky) {
    c.save();
    c.clipPath(sky);

    _rectGrad(
      c,
      ui.Gradient.linear(const Offset(24, 0), const Offset(136, 160),
          [tone.stops[1], tone.stops[2], tone.stops[3]],
          const [0.0, 0.45, 1.0]),
    );
    _rectGrad(
      c,
      ui.Gradient.radial(const Offset(70.4, 40), 144, const [
        Color(0x59FFD166),
        Color(0x2EFFB830),
        Color(0x0FFF9500),
        Color(0x00FF9500),
      ], const [0.0, 0.25, 0.60, 1.0]),
    );
    _rectGrad(
      c,
      ui.Gradient.radial(const Offset(136, 8), 96,
          const [Color(0x1F7AB8E8), Color(0x007AB8E8)], const [0.0, 1.0]),
    );
    _rectGrad(
      c,
      ui.Gradient.radial(const Offset(80, 144), 80,
          const [Color(0x66000000), Color(0x00000000)], const [0.0, 1.0]),
    );
    _rectGrad(
      c,
      ui.Gradient.radial(const Offset(0, 160), 72,
          const [Color(0x80000000), Color(0x00000000)], const [0.0, 1.0]),
    );

    // 背景星只留在夜空側 —— 玻璃那邊要乾淨，才看得出是透的
    for (final s in _kBgStars) {
      _dot(c, Offset(s.x, s.y), s.r, s.c);
    }
    c.restore();
  }

  void _paintHeroStars(Canvas c) {
    _layer(c, stars, () {
      _heroStar(c, const Offset(118, 36), 5, const [
        Color(0xE6FFFFFF),
        Color(0x38FFFFFF),
        Color(0x00FFFFFF),
      ], const Color(0xF5FFFFFF), 1.3, 4.5, 0.5);
      _heroStar(c, const Offset(26, 118), 9, const [
        Color(0xFFFFD166),
        Color(0x8CF5A030),
        Color(0x00E88820),
      ], const Color(0xFFFFD166), 1.8, 5.0, 0.65);
      _heroStar(c, const Offset(132, 128), 8, const [
        Color(0xFFC8E8FF),
        Color(0x66A0C8F0),
        Color(0x00C8E8FF),
      ], const Color(0xFFC8E8FF), 1.8, 5.0, 0.62);
    });
  }

  void _heroStar(Canvas c, Offset o, double halo, List<Color> cols, Color core,
      double coreR, double spike, double sw) {
    c.drawCircle(
      o,
      halo,
      Paint()
        ..shader = ui.Gradient.radial(o, halo, cols, const [0.0, 0.32, 1.0]),
    );
    _dot(c, o, coreR, core);
    final p = Paint()
      ..color = core.withAlpha(200)
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    c.drawLine(o.translate(0, -spike), o.translate(0, spike), p);
    c.drawLine(o.translate(-spike - 0.5, 0), o.translate(spike + 0.5, 0), p);
  }

  void _paintCapsules(Canvas c) {
    // l i i：吸氣時長高一點點。原本很含蓄，amplitude 讓主段明顯一些。
    const specs = <List<double>>[
      [42, 18, 64, 2.0, 0.97],
      [74, 18, 50, 1.5, 0.93],
      [100, 18, 50, 1.0, 0.86],
    ];
    for (final s in specs) {
      final h = s[2] + s[3] * amplitude * breath;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(s[0], 102 - h, s[1], h),
        const Radius.circular(8),
      );
      c.drawRRect(r, Paint()..color = Color.fromRGBO(255, 255, 255, s[4]));
    }
  }

  void _paintDots(Canvas c) {
    final shift = 3.6 * meet;

    // Luna：暖金。她先在。
    _layer(c, luna, () {
      c.save();
      c.translate(shift, 0);
      const o = Offset(83, 28);
      final glow = lunaGlow * 0.38 + (lunaGlow - lunaGlow * 0.38) * breath;
      c.drawCircle(
        o,
        20,
        Paint()
          ..shader = ui.Gradient.radial(o, 20, [
            Color.fromRGBO(255, 209, 102, 0.60 * glow),
            const Color(0x00FFD166),
          ], const [0.0, 1.0]),
      );
      final hs = 0.80 + 0.34 * breath;
      final cs = 0.70 + 0.44 * breath;
      _dot(c, o, 13 * hs, const Color.fromRGBO(255, 209, 102, 0.08));
      _dot(c, o, 10 * hs, const Color.fromRGBO(255, 209, 102, 0.16));
      _dot(c, o, 7 * hs, const Color.fromRGBO(255, 209, 102, 0.32));
      _dot(c, o, 4.5 * cs, const Color.fromRGBO(255, 209, 102, 0.62));
      _dot(c, o, 2.5 * cs, const Color.fromRGBO(255, 209, 102, 0.90));
      _dot(c, o, 1.2, const Color(0xFFFFD166));
      c.restore();
    });

    // 你：冷霧白。你也在。
    _layer(c, you, () {
      c.save();
      c.translate(-shift, 0);
      const o = Offset(109, 28);
      final yb = 0.26 + 0.44 * breath;
      c.drawCircle(
        o,
        20,
        Paint()
          ..shader = ui.Gradient.radial(o, 20, [
            Color.fromRGBO(232, 240, 255, (0.32 * yb * 0.55).clamp(0.0, 1.0)),
            const Color(0x00C8E8FF),
          ], const [0.0, 1.0]),
      );
      final hs = 0.82 + 0.28 * breath;
      final cs = 0.76 + 0.34 * breath;
      _dot(c, o, 13 * hs, const Color.fromRGBO(200, 232, 255, 0.08));
      _dot(c, o, 10 * hs, const Color.fromRGBO(200, 232, 255, 0.16));
      _dot(c, o, 7 * hs, const Color.fromRGBO(200, 232, 255, 0.32));
      _dot(c, o, 4.5 * cs, const Color.fromRGBO(200, 232, 255, 0.62));
      _dot(c, o, 2.5 * cs, const Color.fromRGBO(200, 232, 255, 0.90));
      _dot(c, o, 1.2, const Color(0xFFC8E8FF));
      c.restore();
    });
  }

  void _paintBloom(Canvas c) {
    if (meet <= 0.002) return;
    // 水火交融：暖核冷緣，不是把金色藍色平均混成一團灰
    const o = Offset(96, 28);
    final r = 9 + 7.5 * meet;
    _layer(c, (meet * 0.9).clamp(0.0, 1.0), () {
      c.drawCircle(
        o,
        r,
        Paint()
          ..shader = ui.Gradient.radial(o, r, const [
            Color(0xEBFFF6E2),
            Color(0x85FFE1A8),
            Color(0x42DCEBFF),
            Color(0x00C8E8FF),
          ], const [0.0, 0.26, 0.58, 1.0]),
      );
    });
  }

  void _paintWordmark(Canvas c) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'Luna Pacer',
        style: GoogleFonts.cormorantGaramond(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: const Color(0x66FFFFFF),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (tp.width <= 0) return;
    c.save();
    c.translate(80 - 38, 122 - tp.height * 0.82);
    c.scale(76 / tp.width, 1); // 對應 SVG 的 textLength="76"
    tp.paint(c, Offset.zero);
    c.restore();
  }

  void _paintGlassSurface(Canvas c, Path glass, List<Offset> seam) {
    _layer(c, (0.55 + 0.45 * breath).clamp(0.0, 1.0), () {
      c.save();
      c.clipPath(glass);
      // 邊光：光從球體背面繞過來。只有高光沒有邊光會像貼紙。
      c.drawCircle(
        _kC,
        78.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..shader = ui.Gradient.linear(
              const Offset(48, 0),
              const Offset(152, 147.2),
              const [Color(0x00DFF0FF), Color(0x1ADFF0FF), Color(0x9EEAF6FF)],
              const [0.0, 0.55, 1.0]),
      );
      // 鏡面高光：這一個元素做掉八成的工作，人眼看到高光就判定為曲面
      _radialOval(c, const Offset(119, 52), 15, 27, 24, const [
        Color(0x57FFFFFF),
        Color(0x17FFFFFF),
        Color(0x00FFFFFF),
      ], const [0.0, 0.55, 1.0]);
      c.restore();

      // 交界的折射線，交融那一刻最亮
      c.drawPath(
        _poly(seam, close: false),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3 + 1.1 * meet
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(
              const Offset(0, 0),
              const Offset(0, 160),
              const [Color(0x00DFF0FF), Color(0x8CF4FBFF), Color(0x00DFF0FF)],
              const [0.0, 0.46, 1.0]),
      );
    });
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.breath != breath ||
      old.meet != meet ||
      old.w != w ||
      old.luna != luna ||
      old.you != you ||
      old.stars != stars ||
      old.amplitude != amplitude ||
      old.lunaGlow != lunaGlow ||
      old.tone != tone ||
      old.time != time;
}
