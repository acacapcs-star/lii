// ═══════════════════════════════════════════════════════════
// Luna Pacer · 水晶球
//
// 左邊夜空、右邊有色玻璃，中間的分界可以左右滑動轉面。
// 玻璃裡有三層流動的水、化在水裡的金光與藍光；
// 兩顆光點在玻璃側會慢慢飄，在夜空側維持 logo 原本的位置。
//
// 全部用 Gradient + Path，沒有用任何模糊濾鏡 —— 濾鏡在 Flutter web 上
// 要嘛沒對應要嘛掉幀，漸層和路徑則是一對一。
//
// 座標系固定 160×160（跟原始 SVG 一樣），最後才等比縮放，
// 所以所有數字都可以直接對照網頁原型。
// ═══════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

const double _u = 160; // 座標系邊長
const double _r = 80; // 半徑
const Offset _c = Offset(80, 80);

/// 水晶。四個色階：透光的頂端 → 中段 → 下段 → 沉到底。
/// 只能靠呼吸取得 —— 不是課金也不是隨機，是「你照顧自己幾次」的紀錄。
enum GlassTone { ice, sea, amethyst, amber, moss, dawn }

extension GlassToneX on GlassTone {
  String get labelEn {
    switch (this) {
      case GlassTone.ice:
        return 'Ice';
      case GlassTone.sea:
        return 'Sea';
      case GlassTone.amethyst:
        return 'Amethyst';
      case GlassTone.amber:
        return 'Amber';
      case GlassTone.moss:
        return 'Moss';
      case GlassTone.dawn:
        return 'Dawn';
    }
  }

  String labelFor(bool zh) => zh ? label : labelEn;

  String get label {
    switch (this) {
      case GlassTone.ice:
        return '冰藍';
      case GlassTone.sea:
        return '海藍';
      case GlassTone.amethyst:
        return '紫水晶';
      case GlassTone.amber:
        return '琥珀';
      case GlassTone.moss:
        return '苔綠';
      case GlassTone.dawn:
        return '曙光';
    }
  }

  /// 產生句子的那塊底，用同一顆水晶的深色 ——
  /// 卡片和球才是一套，不然底板是死黑色，跟球各講各的。
  List<Color> get plate {
    final s = stops;
    return [s[2].withAlpha(0x8A), s[3].withAlpha(0xC7)];
  }

  List<Color> get stops {
    switch (this) {
      case GlassTone.ice:
        return const [
          Color(0xF5EDF9FF),
          Color(0xED337FB0),
          Color(0xF20E3F72),
          Color(0xFA04101F),
        ];
      case GlassTone.sea:
        return const [
          Color(0xF5ECFBF8),
          Color(0xED2A8A88),
          Color(0xF208536A),
          Color(0xFA02161F),
        ];
      case GlassTone.amethyst:
        return const [
          Color(0xF5F5EEFF),
          Color(0xED7A54B0),
          Color(0xF2412580),
          Color(0xFA100A26),
        ];
      case GlassTone.amber:
        return const [
          Color(0xF5FFF3D6),
          Color(0xEDE0A94A),
          Color(0xF2A65F14),
          Color(0xFA2A1405),
        ];
      case GlassTone.moss:
        return const [
          Color(0xF5EFFBEA),
          Color(0xED6FB878),
          Color(0xF22C7247),
          Color(0xFA0A2415),
        ];
      case GlassTone.dawn:
        return const [
          Color(0xF5FFF0F2),
          Color(0xEDEE9AA6),
          Color(0xF2B04E6C),
          Color(0xFA2E1024),
        ];
    }
  }
}

class _Star {
  final double x, y, r;
  final Color c;
  const _Star(this.x, this.y, this.r, this.c);
}

const List<_Star> _stars = [
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

class LunaOrb extends StatelessWidget {
  /// 從開始算起的秒數，用來驅動呼吸、水流、飄動
  final double time;

  /// 分界的橫向半寬：+80 整片夜空、0 對半、-80 整片水晶球
  final double w;

  final GlassTone tone;

  const LunaOrb({
    super.key,
    required this.time,
    required this.w,
    this.tone = GlassTone.ice,
  });

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _OrbPainter(time: time, w: w, tone: tone));
}

class _OrbPainter extends CustomPainter {
  final double time, w;
  final GlassTone tone;

  _OrbPainter({required this.time, required this.w, required this.tone});

  // ── 幾何 ────────────────────────────────────────────
  // 一顆半邊上色的球轉起來，分界的投影是通過上下極點的橢圓，
  // 橫向半寬 = R·cos(轉角)。轉到正中間時橢圓自己退化成直線。

  List<Offset> _seam() {
    final o = <Offset>[];
    for (var i = 0; i < 26; i++) {
      final a = (-90 + 180 * i / 25) * math.pi / 180;
      o.add(Offset(_c.dx + w * math.cos(a), _c.dy + _r * math.sin(a)));
    }
    return o;
  }

  List<Offset> _rim(double a0, double a1) {
    final o = <Offset>[];
    for (var i = 0; i < 30; i++) {
      final a = (a0 + (a1 - a0) * i / 29) * math.pi / 180;
      o.add(Offset(_c.dx + _r * math.cos(a), _c.dy + _r * math.sin(a)));
    }
    return o;
  }

  Path _poly(List<Offset> p, {bool close = true}) {
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    for (var i = 1; i < p.length; i++) {
      path.lineTo(p[i].dx, p[i].dy);
    }
    if (close) path.close();
    return path;
  }

  /// 兩個週期、寬 320，平移 160 剛好接回原點，所以流動看不出接縫
  Path _wave(double y0, double amp) {
    final p = Path()..moveTo(0, y0);
    for (var x = 0.0; x <= 320; x += 6) {
      p.lineTo(x, y0 + amp * math.sin(2 * math.pi * x / 160));
    }
    p.lineTo(320, 176);
    p.lineTo(0, 176);
    p.close();
    return p;
  }

  // ── 小工具 ──────────────────────────────────────────

  void _fillAll(Canvas c, ui.Gradient g) =>
      c.drawRect(const Rect.fromLTWH(0, 0, _u, _u), Paint()..shader = g);

  void _oval(Canvas c, Offset o, double rx, double ry, double rot,
      List<Color> cols, List<double> st,
      {BlendMode? blend}) {
    c.save();
    c.translate(o.dx, o.dy);
    if (rot != 0) c.rotate(rot * math.pi / 180);
    c.scale(1, ry / rx);
    final p = Paint()..shader = ui.Gradient.radial(Offset.zero, rx, cols, st);
    if (blend != null) p.blendMode = blend;
    c.drawCircle(Offset.zero, rx, p);
    c.restore();
  }

  void _dot(Canvas c, Offset o, double r, Color col) =>
      c.drawCircle(o, r, Paint()..color = col);

  void _layer(Canvas c, double a, VoidCallback body) {
    if (a >= .999) {
      body();
      return;
    }
    if (a <= .002) return;
    c.saveLayer(const Rect.fromLTWH(0, 0, _u, _u),
        Paint()..color = Color.fromRGBO(255, 255, 255, a));
    body();
    c.restore();
  }

  // ── 主繪製 ──────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final b = (1 - math.cos(time / 9 * 2 * math.pi)) / 2; // 9 秒呼吸一次
    final mRaw = (b - 0.72) / 0.28;
    final m = mRaw <= 0 ? 0.0 : math.pow(mRaw, 1.4).toDouble();

    canvas.save();
    canvas.scale(size.width / _u);
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: _c, radius: _r)));

    final seam = _seam();
    final sky = _poly(seam + _rim(90, 270));
    final glass = _poly(seam + _rim(90, -90));

    _paintGlass(canvas, glass, b, m);
    _paintSky(canvas, sky);
    _paintHeroStars(canvas);
    _paintCapsules(canvas, b);
    _paintDots(canvas, sky, glass, b, m);
    _paintSurface(canvas, glass, seam, b, m);
    _paintWordmark(canvas);

    canvas.restore();
  }

  void _paintGlass(Canvas c, Path glass, double b, double m) {
    c.save();
    c.clipPath(glass);

    // 玻璃本體：越往下越濃，因為光要穿過的厚度變厚
    _fillAll(
      c,
      ui.Gradient.linear(const Offset(28.8, 0), const Offset(115.2, 160),
          tone.stops, const [0.0, 0.38, 0.72, 1.0]),
    );

    // 三層水，速度都不一樣所以永遠不會同步
    final lift = b * 2.5 - 1.2;
    void wave(Path p, Color col, double periodSec, {bool back = false}) {
      final k = (time % periodSec) / periodSec;
      final dx = back ? -160 + k * 160 : -k * 160;
      c.save();
      c.translate(dx, lift);
      c.drawPath(p, Paint()..color = col);
      c.restore();
    }

    wave(_wave(100, 4.5), const Color(0x851C6FA8), 15);
    wave(_wave(110, 6.5), const Color(0x990E4E80), 23, back: true);
    wave(_wave(121, 3.5), const Color(0xB806305A), 31);

    // 金光和藍光化在水裡，慢慢晃。四個週期不整除，看不出循環。
    final iy = Offset(80 + math.sin(time / 7.3) * 5,
        126 + lift + math.sin(time / 5.2) * 2);
    final ib = Offset(110 + math.sin(time / 9.1 + 2) * 5,
        130 + lift + math.sin(time / 6.1 + 1) * 2);
    _oval(c, iy, 32, 21, 0, const [
      Color(0xD1FFD45C),
      Color(0x4DFFB81A),
      Color(0x00FFA800),
    ], const [0, .45, 1], blend: BlendMode.screen);
    _oval(c, ib, 32, 21, 0, const [
      Color(0xD174D0FF),
      Color(0x4D38A8F5),
      Color(0x001E8FE8),
    ], const [0, .45, 1], blend: BlendMode.screen);

    // 水面上的光池
    _oval(c, Offset(83, 102 + lift), 27, 8, 0,
        const [Color(0xB8FFD34A), Color(0x00FFA800)], const [0, 1],
        blend: BlendMode.screen);
    _oval(c, Offset(109, 104 + lift), 27, 8, 0,
        const [Color(0xB84FC0FF), Color(0x008FD0FF)], const [0, 1],
        blend: BlendMode.screen);

    // 靠交界處被 Luna 的金光染暖 —— 光源在夜空那側
    _layer(c, .78 + .22 * b, () {
      _oval(c, const Offset(101, 62), 34, 46, 0, const [
        Color(0x4DFFD166),
        Color(0x1CFFB830),
        Color(0x00FF9500),
      ], const [0, .45, 1]);
      // 底部焦散光：實心玻璃的招牌
      _oval(c, const Offset(113, 119), 26 - 7 * 0, 15, -18, const [
        Color(0xC7FFFDF6),
        Color(0x52FFE0AE),
        Color(0x00FFC46A),
      ], const [0, .40, 1]);
    });

    c.restore();
  }

  void _paintSky(Canvas c, Path sky) {
    c.save();
    c.clipPath(sky);
    _fillAll(
        c,
        ui.Gradient.linear(const Offset(24, 0), const Offset(136, 160),
            const [Color(0xFF2A5F8F), Color(0xFF1A3D6E), Color(0xFF0F2444)],
            const [0, .45, 1]));
    _fillAll(
        c,
        ui.Gradient.radial(const Offset(70.4, 40), 144, const [
          Color(0x59FFD166),
          Color(0x2EFFB830),
          Color(0x0FFF9500),
          Color(0x00FF9500),
        ], const [0, .25, .60, 1]));
    _fillAll(
        c,
        ui.Gradient.radial(const Offset(136, 8), 96,
            const [Color(0x1F7AB8E8), Color(0x007AB8E8)], const [0, 1]));
    _fillAll(
        c,
        ui.Gradient.radial(const Offset(80, 144), 80,
            const [Color(0x66000000), Color(0x00000000)], const [0, 1]));
    _fillAll(
        c,
        ui.Gradient.radial(const Offset(0, 160), 72,
            const [Color(0x80000000), Color(0x00000000)], const [0, 1]));
    for (final s in _stars) {
      _dot(c, Offset(s.x, s.y), s.r, s.c);
    }
    c.restore();
  }

  void _paintHeroStars(Canvas c) {
    _hero(c, const Offset(118, 36), 5, const [
      Color(0xE6FFFFFF),
      Color(0x38FFFFFF),
      Color(0x00FFFFFF),
    ], const Color(0xF5FFFFFF), 1.3, 4.5, .5);
    _hero(c, const Offset(26, 118), 9, const [
      Color(0xFFFFD166),
      Color(0x8CF5A030),
      Color(0x00E88820),
    ], const Color(0xFFFFD166), 1.8, 5, .65);
    _hero(c, const Offset(132, 128), 8, const [
      Color(0xFFC8E8FF),
      Color(0x66A0C8F0),
      Color(0x00C8E8FF),
    ], const Color(0xFFC8E8FF), 1.8, 5, .62);
  }

  void _hero(Canvas c, Offset o, double halo, List<Color> cols, Color core,
      double coreR, double spike, double sw) {
    c.drawCircle(
        o,
        halo,
        Paint()
          ..shader = ui.Gradient.radial(o, halo, cols, const [0, .32, 1]));
    _dot(c, o, coreR, core);
    final p = Paint()
      ..color = core.withAlpha(200)
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    c.drawLine(o.translate(0, -spike), o.translate(0, spike), p);
    c.drawLine(o.translate(-spike - .5, 0), o.translate(spike + .5, 0), p);
  }

  void _paintCapsules(Canvas c, double b) {
    const spec = <List<double>>[
      [42, 18, 64, 2.0, .97],
      [74, 18, 50, 1.5, .93],
      [100, 18, 50, 1.0, .86],
    ];
    for (final s in spec) {
      final h = s[2] + s[3] * 1.4 * b;
      c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s[0], 102 - h, s[1], h), const Radius.circular(8)),
        Paint()..color = Color.fromRGBO(255, 255, 255, s[4]),
      );
    }
  }

  /// 兩顆光點畫兩份：夜空側待在 logo 原本的位置，玻璃側在球裡飄。
  void _paintDots(Canvas c, Path sky, Path glass, double b, double m) {
    final yx = math.sin(time / 6.1) * 15 + math.sin(time / 9.7 + 1.3) * 6;
    final yy = math.sin(time / 7.9 + .6) * 12 + 14;
    final bx = math.sin(time / 8.3 + 2.1) * 15 + math.sin(time / 5.9) * 6;
    final by = math.sin(time / 6.7 + 1.7) * 12 + 14;

    void pair(Offset drift) {
      c.save();
      c.translate(drift.dx, drift.dy);
      _luna(c, b, m);
      c.restore();
    }

    void pairYou(Offset drift) {
      c.save();
      c.translate(drift.dx, drift.dy);
      _you(c, b, m);
      c.restore();
    }

    void bloom(Offset d) {
      if (m <= .002) return;
      final o = Offset(96 + d.dx, 28 + d.dy);
      final rr = 9 + 7.5 * m;
      _layer(c, (m * .9).clamp(0.0, 1.0), () {
        c.drawCircle(
            o,
            rr,
            Paint()
              ..shader = ui.Gradient.radial(o, rr, const [
                Color(0xEBFFF6E2),
                Color(0x85FFE1A8),
                Color(0x42DCEBFF),
                Color(0x00C8E8FF),
              ], const [0, .26, .58, 1]));
      });
    }

    c.save();
    c.clipPath(sky);
    pair(Offset.zero);
    pairYou(Offset.zero);
    bloom(Offset.zero);
    c.restore();

    c.save();
    c.clipPath(glass);
    pair(Offset(yx, yy));
    pairYou(Offset(bx, by));
    bloom(Offset((yx + bx) / 2, (yy + by) / 2));
    c.restore();
  }

  void _luna(Canvas c, double b, double m) {
    c.save();
    c.translate(3.6 * m, 0);
    const o = Offset(83, 28);
    final glow = .25 + .4 * b;
    c.drawCircle(
        o,
        20,
        Paint()
          ..shader = ui.Gradient.radial(o, 20, [
            Color.fromRGBO(255, 209, 102, .6 * glow),
            const Color(0x00FFD166),
          ], const [0, 1]));
    final hs = .80 + .34 * b, cs = .70 + .44 * b;
    _dot(c, o, 13 * hs, const Color.fromRGBO(255, 209, 102, .08));
    _dot(c, o, 10 * hs, const Color.fromRGBO(255, 209, 102, .16));
    _dot(c, o, 7 * hs, const Color.fromRGBO(255, 209, 102, .32));
    _dot(c, o, 4.5 * cs, const Color.fromRGBO(255, 193, 61, .72));
    _dot(c, o, 2.5 * cs, const Color.fromRGBO(255, 184, 41, .96));
    _dot(c, o, 1.2, const Color(0xFFFFD166));
    c.restore();
  }

  void _you(Canvas c, double b, double m) {
    c.save();
    c.translate(-3.6 * m, 0);
    const o = Offset(109, 28);
    final yb = .26 + .44 * b;
    c.drawCircle(
        o,
        20,
        Paint()
          ..shader = ui.Gradient.radial(o, 20, [
            Color.fromRGBO(232, 240, 255, (.32 * yb * .55).clamp(0.0, 1.0)),
            const Color(0x00C8E8FF),
          ], const [0, 1]));
    final hs = .82 + .28 * b, cs = .76 + .34 * b;
    _dot(c, o, 13 * hs, const Color.fromRGBO(200, 232, 255, .08));
    _dot(c, o, 10 * hs, const Color.fromRGBO(200, 232, 255, .16));
    _dot(c, o, 7 * hs, const Color.fromRGBO(200, 232, 255, .32));
    _dot(c, o, 4.5 * cs, const Color.fromRGBO(143, 208, 255, .72));
    _dot(c, o, 2.5 * cs, const Color.fromRGBO(95, 182, 245, .96));
    _dot(c, o, 1.2, const Color(0xFFC8E8FF));
    c.restore();
  }

  void _paintSurface(
      Canvas c, Path glass, List<Offset> seam, double b, double m) {
    _layer(c, (.55 + .45 * b).clamp(0.0, 1.0), () {
      c.save();
      c.clipPath(glass);
      // 邊光：光從球體背面繞過來。只有高光沒有邊光會像貼紙。
      c.drawCircle(
          _c,
          78.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.8
            ..shader = ui.Gradient.linear(
                const Offset(48, 0),
                const Offset(152, 147.2),
                const [Color(0x00DFF0FF), Color(0x1ADFF0FF), Color(0x9EEAF6FF)],
                const [0, .55, 1]));
      // 鏡面高光：人眼看到高光就判定為曲面
      _oval(c, const Offset(119, 52), 15, 27, 24, const [
        Color(0x94FFFFFF),
        Color(0x2BFFFFFF),
        Color(0x00FFFFFF),
      ], const [0, .55, 1]);
      c.restore();

      c.drawPath(
          _poly(seam, close: false),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3 + 1.1 * m
            ..strokeCap = StrokeCap.round
            ..shader = ui.Gradient.linear(
                const Offset(0, 0),
                const Offset(0, 160),
                const [Color(0x00DFF0FF), Color(0x8CF4FBFF), Color(0x00DFF0FF)],
                const [0, .46, 1]));
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
    c.translate(80 - 38, 122 - tp.height * .82);
    c.scale(76 / tp.width, 1); // 對應 SVG 的 textLength="76"
    tp.paint(c, Offset.zero);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.time != time || old.w != w || old.tone != tone;
}

// ═══════════════════════════════════════════════════════════
// 會自己動的版本 + 逐字浮現
// 給書籤卡那種「不想自己管 ticker」的地方用。
// ═══════════════════════════════════════════════════════════

/// 自帶 ticker 的水晶球：外面只要給分界位置就好。
class LunaOrbLive extends StatefulWidget {
  final double w;
  final GlassTone tone;
  const LunaOrbLive({super.key, required this.w, this.tone = GlassTone.ice});

  @override
  State<LunaOrbLive> createState() => _LunaOrbLiveState();
}

class _LunaOrbLiveState extends State<LunaOrbLive>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;
  int _skip = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      _t = d.inMicroseconds / 1e6;
      _skip = (_skip + 1) % 2; // 30fps 就夠了，省電
      if (_skip == 0 && mounted) setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LunaOrb(time: _t, w: widget.w, tone: widget.tone);
}

/// 逐字浮現：每個字自己有門檻，所以拉到哪、話就到哪。
///
/// 顯示值會「追」目標值而不是直接跳過去 —— 放開手之後字還會飄一下才落定。
/// 那個空隙是刻意的：文字在飄的時候，人才會停下來看。
class LunaReveal extends StatefulWidget {
  final String text;
  final double progress;
  final TextStyle style;

  const LunaReveal({
    super.key,
    required this.text,
    required this.progress,
    this.style = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      height: 1.4,
      shadows: [
        Shadow(blurRadius: 8, color: Colors.black87),
        Shadow(blurRadius: 2, color: Colors.black87),
      ],
    ),
  });

  @override
  State<LunaReveal> createState() => _LunaRevealState();
}

class _LunaRevealState extends State<LunaReveal>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late double _shown = widget.progress;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final d = widget.progress - _shown;
      if (d.abs() < 0.0015) {
        if (_shown != widget.progress) {
          _shown = widget.progress;
          if (mounted) setState(() {});
        }
        return;
      }
      _shown += d * 0.085; // 慢慢追上去，這就是「飄」的那段
      if (mounted) setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }


  /// 中文一個字一單位，英文一個詞一單位 ——
  /// 逐字切在中文是對的，在英文會把 healthy 斷成 h / ealthy。
  static List<String> _units(String text) {
    final out = <String>[];
    final buf = StringBuffer();
    void flush() {
      if (buf.isNotEmpty) {
        out.add(buf.toString());
        buf.clear();
      }
    }

    // 英數字算同一個詞；緊跟在詞後的標點併進去，不然 MSLab. 會被切成兩塊。
    // 存進來的換行不照搬 —— 卡片寬度不同，硬換行會斷在奇怪的地方。
    const wordish =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'-";
    const tail = ".,!?;:";
    for (final raw in text.characters) {
      final ch = (raw == '\n' || raw == '\r' || raw == '\t') ? ' ' : raw;
      if (wordish.contains(ch)) {
        buf.write(ch);
      } else if (ch == ' ') {
        buf.write(' ');
        flush();
      } else if (buf.isNotEmpty && tail.contains(ch)) {
        buf.write(ch);
      } else {
        flush();
        out.add(ch);
      }
    }
    flush();
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final units = _units(widget.text);
    final head = _shown * (units.length + 4) - 2;
    final base = widget.style;
    final col = base.color ?? Colors.white;

    // 用 RichText 而不是 Wrap —— Wrap 會把每個字當成獨立元件排版，
    // 行距永遠對不起來。這裡是同一段文字，只是每個字的透明度不同。
    return RichText(
      textAlign: TextAlign.left,
      text: TextSpan(
        children: List.generate(units.length, (i) {
          final o = (head - i).clamp(0.0, 1.0);
          return TextSpan(
            text: units[i],
            style: base.copyWith(
              color: col.withAlpha((o * 255).round()),
              shadows: o < 0.05 ? const [] : base.shadows,
            ),
          );
        }),
      ),
    );
  }
}

// 纜車：球是支點，纜線穿過它，兩條繩子從球往下吊住車廂。
// 車廂繞著球擺盪，纜線和球本身不動。
class LunaCableCar extends StatefulWidget {
  final Widget child;
  final double childWidth;
  final double childHeight;
  final double t;
  final double pull;
  final double orbSize;
  final double ropeLen;
  final GlassTone tone;
  final void Function(double t, double pull) onChanged;

  /// false = 球完全不接手勢（推播卡要能左右滑，球不能攔）
  final bool interactive;
  final VoidCallback? onEnd;

  const LunaCableCar({
    super.key,
    required this.child,
    required this.childWidth,
    required this.childHeight,
    required this.t,
    required this.pull,
    required this.onChanged,
    this.onEnd,
    this.orbSize = 190,
    this.ropeLen = 18,
    this.tone = GlassTone.ice,
    this.interactive = true,
  });

  @override
  State<LunaCableCar> createState() => _LunaCableCarState();
}

class _LunaCableCarState extends State<LunaCableCar>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _time = 0, _last = 0;
  double _angle = 0, _vel = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration d) {
    final now = d.inMicroseconds / 1e6;
    var dt = now - _last;
    _last = now;
    if (dt <= 0 || dt > 0.05) dt = 1 / 60;
    _time = now;

    const k = 30.0;
    const c = 2.8;
    _vel += (-k * _angle - c * _vel) * dt;
    _angle += _vel * dt;

    const maxA = 5 * math.pi / 180;
    if (_angle > maxA) {
      _angle = maxA;
      _vel *= -0.2;
    } else if (_angle < -maxA) {
      _angle = -maxA;
      _vel *= -0.2;
    }

    if (_angle.abs() < 0.0004 && _vel.abs() < 0.004) {
      _angle = 0;
      _vel = 0;
    }
    if (mounted) setState(() {});
  }

  void _drag(DragUpdateDetails d) {
    final nt = (widget.t - d.delta.dx / 160).clamp(0.0, 1.0);
    final np = (widget.pull - d.delta.dy / 90).clamp(0.0, 1.0);
    _vel += d.delta.dx * 0.028;
    widget.onChanged(nt, np);
  }

  @override
  Widget build(BuildContext context) {
    final orb = widget.orbSize;
    final rope = widget.ropeLen * (1 - 0.6 * widget.pull);
    final childTop = orb + rope;
    final w = widget.childWidth;
    final pivot = Offset(w / 2, orb / 2);

    return SizedBox(
      width: w,
      height: childTop + widget.childHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -20,
            right: -20,
            top: orb / 2 - 1.5,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0x73FFFFFF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Transform(
            transform: Matrix4.rotationZ(_angle),
            origin: pivot,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RopePainter(
                      pivot: pivot,
                      orb: orb,
                      childTop: childTop,
                      childWidth: w,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: childTop,
                  width: widget.childWidth,
                  height: widget.childHeight,
                  child: widget.child,
                ),
              ],
            ),
          ),
          Positioned(
            left: w / 2 - orb / 2,
            top: 0,
            width: orb,
            height: orb,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // 用 HorizontalDrag 而不是 Pan ——
              // 巢狀在 PageView 裡時，內層的水平拖曳會贏得手勢仲裁，
              // Pan 不一定贏，所以之前在推播卡上拉不動球。
              onHorizontalDragUpdate: _drag,
              onHorizontalDragEnd: (_) => widget.onEnd?.call(),
              onVerticalDragUpdate: _drag,
              onVerticalDragEnd: (_) => widget.onEnd?.call(),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0xCCFFFFFF), width: 3.2),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x59000000),
                        blurRadius: 8,
                        offset: Offset(0, 3)),
                  ],
                ),
                padding: const EdgeInsets.all(2.5),
                child: ClipOval(
                  child: LunaOrb(
                    time: _time,
                    w: 80 - 160 * widget.t,
                    tone: widget.tone,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 兩條繩子：從球的下緣兩側分出來，扣住車廂的兩個上角。
class _RopePainter extends CustomPainter {
  final Offset pivot;
  final double orb, childTop, childWidth;

  _RopePainter({
    required this.pivot,
    required this.orb,
    required this.childTop,
    required this.childWidth,
  });

  @override
  void paint(Canvas canvas, Size box) {
    final p = Paint()
      ..color = const Color(0x99FFFFFF)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final ly = pivot.dy + orb * 0.34;
    final lx = orb * 0.26;
    const inset = 16.0;

    canvas.drawLine(Offset(pivot.dx - lx, ly), Offset(inset, childTop), p);
    canvas.drawLine(
        Offset(pivot.dx + lx, ly), Offset(childWidth - inset, childTop), p);
  }

  @override
  bool shouldRepaint(covariant _RopePainter old) => true;
}
