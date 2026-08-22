import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

// ── 版面比例：畫面與物理共用同一組，才不會「看起來進了卻沒算分」──
const double _kSeaTopF = 0.30; // 海平面
const double _kFloorF = 0.86; // 沙灘地面（球心停的高度）
const double _kHoopXF = 0.74; // 籃框中心 x
const double _kHoopYF = 0.31; // 籃框高度 y
const double _kRimHalfF = 0.13; // 籃框半徑（相對寬度）
const double _kBallRF = 0.075; // 球半徑（相對寬度）
const double _kLaunchK = 6.5; // 拉的距離 → 初速倍率

double _ballR(Size s) => math.max(7.0, s.width * _kBallRF);
double _rimHalf(Size s) => math.max(12.0, s.width * _kRimHalfF);
Offset _hoop(Size s) => Offset(s.width * _kHoopXF, s.height * _kHoopYF);
double _boardX(Size s) => _hoop(s).dx + _rimHalf(s) + 1.5;
double _boardTop(Size s) => _hoop(s).dy - s.height * 0.24;
double _boardBot(Size s) => _hoop(s).dy + s.height * 0.04;
Offset _homePos(Size s) => Offset(s.width * 0.15, s.height * _kFloorF);
double _gravityOf(Size s) => s.height * 7.0;
double _maxPullOf(Size s) => s.width * 0.55;

/// 🏀 沙灘投籃角落。
/// 按住籃球往「反方向」拉 →（白色拋物線預測點）→ 放開發射，
/// 撞牆 / 籃板 / 籃框都會反彈；從框上方穿過就 GOAL！🎉
class HoopCorner extends StatefulWidget {
  const HoopCorner({super.key});

  @override
  State<HoopCorner> createState() => _HoopCornerState();
}

/// 進球時炸開的小星星。
class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.hue);
  double x, y, vx, vy;
  final int hue;
  double life = 1;
}

class _HoopCornerState extends State<HoopCorner>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final math.Random _rng = math.Random();

  final List<_Spark> _sparks = [];
  Size _size = Size.zero;

  double _bx = 0, _by = 0, _bvx = 0, _bvy = 0, _bRot = 0, _bSpin = 0;
  bool _flying = false; // 正在飛
  bool _aiming = false; // 正在拉弓
  bool _scored = false; // 這一球算過分了嗎
  bool _hasShot = false; // 投過第一球了嗎（決定要不要顯示提示）
  Offset _anchor = Offset.zero; // 這一球從哪裡發射
  Offset _aim = Offset.zero; // 往後拉的位移
  double _restTimer = 0; // 停下來後多久自動回原位
  double _prevY = 0;
  double _time = 0; // 給提示脈動用

  int _score = 0;
  double _goalFlash = 0; // GOAL 橫幅殘留秒數

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _layout(Size size) {
    if (_size == size || size.isEmpty) return;
    final first = _size.isEmpty;
    _size = size;
    if (first || !_flying) _resetBall();
  }

  void _resetBall() {
    final hp = _homePos(_size);
    _bx = hp.dx;
    _by = hp.dy;
    _bvx = 0;
    _bvy = 0;
    _bSpin = 0;
    _bRot = 0;
    _anchor = hp;
    _aim = Offset.zero;
    _flying = false;
    _aiming = false;
    _scored = false;
    _restTimer = 0;
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    if (_size.isEmpty) return;
    _time = elapsed.inMicroseconds / 1e6;

    _updateBall(dt);
    _updateSparks(dt);
    if (_goalFlash > 0) _goalFlash = math.max(0, _goalFlash - dt);
    setState(() {});
  }

  void _updateBall(double dt) {
    final s = _size;
    if (!_flying) {
      if (!_aiming && _restTimer > 0) {
        _restTimer -= dt;
        if (_restTimer <= 0) _resetBall();
      }
      return;
    }

    final r = _ballR(s);
    final floor = s.height * _kFloorF;
    final g = _gravityOf(s);
    final hp = _hoop(s);
    final rim = _rimHalf(s);

    _prevY = _by;
    final prevX = _bx;

    _bvy += g * dt;
    _bx += _bvx * dt;
    _by += _bvy * dt;
    _bRot += _bSpin * dt;

    // ── 左右牆 ──
    if (_bx < r) {
      _bx = r;
      _bvx = -_bvx * 0.55;
      _bSpin = -_bSpin * 0.6;
    } else if (_bx > s.width - r) {
      _bx = s.width - r;
      _bvx = -_bvx * 0.55;
      _bSpin = -_bSpin * 0.6;
    }

    // ── 籃板（從左邊撞上去才擋）──
    final bdX = _boardX(s);
    if (_bvx > 0 &&
        prevX + r <= bdX &&
        _bx + r >= bdX &&
        _by > _boardTop(s) &&
        _by < _boardBot(s)) {
      _bx = bdX - r;
      _bvx = -_bvx * 0.5;
      HapticFeedback.selectionClick();
    }

    // ── 籃框兩端當成圓形碰撞點（框噹！）──
    for (final p in [
      Offset(hp.dx - rim, hp.dy),
      Offset(hp.dx + rim, hp.dy),
    ]) {
      final d = Offset(_bx, _by) - p;
      final dist = d.distance;
      if (dist < r && dist > 0.001) {
        final n = d / dist;
        _bx = p.dx + n.dx * r;
        _by = p.dy + n.dy * r;
        final dot = _bvx * n.dx + _bvy * n.dy;
        _bvx = (_bvx - 2 * dot * n.dx) * 0.6;
        _bvy = (_bvy - 2 * dot * n.dy) * 0.6;
        _bSpin += (_rng.nextDouble() - 0.5) * 8;
      }
    }

    // ── 得分：從上方往下穿過籃框 ──
    if (!_scored &&
        _bvy > 0 &&
        _prevY < hp.dy &&
        _by >= hp.dy &&
        (_bx - hp.dx).abs() < rim) {
      _scored = true;
      _onGoal(hp);
    }

    // ── 地面 ──
    if (_by >= floor) {
      _by = floor;
      _bvy = -_bvy * 0.45;
      _bvx *= 0.78;
      _bSpin *= 0.7;
      if (_bvy.abs() < s.height * 0.28 && _bvx.abs() < s.width * 0.18) {
        _flying = false;
        _bvx = 0;
        _bvy = 0;
        _bSpin = 0;
        _restTimer = 0.6;
      }
    }

    // 飛出天際就收回來
    if (_by < -s.height) {
      _flying = false;
      _restTimer = 0.2;
    }
  }

  void _onGoal(Offset hp) {
    HapticFeedback.heavyImpact();
    _score++;
    _goalFlash = 1.3;
    for (int i = 0; i < 18; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final sp = 45 + _rng.nextDouble() * 95;
      _sparks.add(_Spark(
        hp.dx,
        hp.dy + 4,
        math.cos(a) * sp,
        math.sin(a) * sp - 40,
        _rng.nextInt(3),
      ));
    }
  }

  void _updateSparks(double dt) {
    final g = _gravityOf(_size) * 0.45;
    for (final sp in _sparks) {
      sp.vy += g * dt;
      sp.x += sp.vx * dt;
      sp.y += sp.vy * dt;
      sp.life -= dt * 1.25;
    }
    _sparks.removeWhere((sp) => sp.life <= 0);
  }

  Offset get _ballPos => _aiming ? _anchor + _aim : Offset(_bx, _by);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: LayoutBuilder(builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _layout(size);
        final r = _ballR(size);
        final bp = _ballPos;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 天空 / 海 / 沙灘 / 籃框
            Positioned.fill(
              child: CustomPaint(painter: const _CourtPainter()),
            ),
            // 球、拉弓線、預測點、星星、GOAL、計分
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PlayPainter(
                    ball: bp,
                    ballR: r,
                    rot: _bRot,
                    aiming: _aiming,
                    anchor: _anchor,
                    aim: _aim,
                    sparks: _sparks,
                    score: _score,
                    goalFlash: _goalFlash,
                    hint: !_hasShot && !_aiming && !_flying,
                    time: _time,
                  ),
                ),
              ),
            ),
            // 球的手勢範圍（飛行中不吃手勢，才不會誤觸）
            if (!_flying)
              Positioned(
                left: bp.dx - r * 2.0,
                top: bp.dy - r * 2.0,
                width: r * 4.0,
                height: r * 4.0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _anchor = Offset(_bx, _by);
                      _aim = Offset.zero;
                      _aiming = true;
                      _scored = false;
                      _restTimer = 0;
                    });
                  },
                  onPanUpdate: (d) {
                    if (!_aiming) return;
                    setState(() {
                      var a = _aim + d.delta;
                      final maxPull = _maxPullOf(size);
                      if (a.distance > maxPull) {
                        a = a / a.distance * maxPull;
                      }
                      _aim = a;
                    });
                  },
                  onPanEnd: (_) {
                    if (!_aiming) return;
                    final pull = _aim.distance;
                    setState(() {
                      _aiming = false;
                      if (pull < 6) {
                        _aim = Offset.zero;
                        return; // 只是輕輕碰到，不發射
                      }
                      HapticFeedback.mediumImpact();
                      _bx = _anchor.dx + _aim.dx;
                      _by = _anchor.dy + _aim.dy;
                      _bvx = -_aim.dx * _kLaunchK;
                      _bvy = -_aim.dy * _kLaunchK;
                      _bSpin = -_bvx * 0.02;
                      _aim = Offset.zero;
                      _flying = true;
                      _scored = false;
                      _hasShot = true;
                    });
                  },
                ),
              ),
          ],
        );
      }),
    );
  }
}

/// 背景：天空、太陽、海、沙灘、籃框。
class _CourtPainter extends CustomPainter {
  const _CourtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // 天空
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * _kSeaTopF + 2),
      Paint()..color = const Color(0xFFBFE7FA),
    );
    // 太陽
    canvas.drawCircle(
      Offset(w * 0.12, h * 0.12),
      9,
      Paint()..color = const Color(0xFFFFD54F),
    );
    // 海
    canvas.drawRect(
      Rect.fromLTWH(0, h * _kSeaTopF, w, h * 0.52),
      Paint()..color = const Color(0xFF6EC6E8),
    );
    // 海面波浪線
    final wave = Paint()
      ..color = const Color(0xFFB8E5F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final y0 = h * _kSeaTopF + 1;
    final path = Path()..moveTo(0, y0);
    for (double x = 0; x <= w; x += 14) {
      path.quadraticBezierTo(x + 3.5, y0 - 3, x + 7, y0);
      path.quadraticBezierTo(x + 10.5, y0 + 3, x + 14, y0);
    }
    canvas.drawPath(path, wave);
    // 沙灘
    final sand = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.82)
      ..quadraticBezierTo(w * 0.5, h * 0.73, w, h * 0.80)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(sand, Paint()..color = const Color(0xFFF5DFA9));

    _drawHoop(canvas, size);
  }

  void _drawHoop(Canvas canvas, Size size) {
    final hp = _hoop(size);
    final rim = _rimHalf(size);
    final bdX = _boardX(size);
    final bdTop = _boardTop(size);
    final bdBot = _boardBot(size);

    // 柱子
    canvas.drawRect(
      Rect.fromLTWH(bdX + 1.5, bdTop + 4, 3.5, size.height * _kFloorF - bdTop),
      Paint()..color = const Color(0xFFB0BEC5),
    );
    // 籃板（側視是一片薄板）
    final board = RRect.fromRectAndRadius(
      Rect.fromLTRB(bdX, bdTop, bdX + 5, bdBot),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      board,
      Paint()..color = Colors.white.withValues(alpha: 0.94),
    );
    canvas.drawRRect(
      board,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFE0552B),
    );

    // 網子
    final net = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final netH = size.height * 0.10;
    for (int i = 0; i <= 4; i++) {
      final t = i / 4;
      final topX = hp.dx - rim + rim * 2 * t;
      final botX = hp.dx - rim * 0.45 + rim * 0.9 * t;
      canvas.drawLine(Offset(topX, hp.dy), Offset(botX, hp.dy + netH), net);
    }
    for (int j = 1; j <= 2; j++) {
      final f = j / 3;
      final y = hp.dy + netH * f;
      final half = rim * (1 - 0.55 * f);
      canvas.drawLine(Offset(hp.dx - half, y), Offset(hp.dx + half, y), net);
    }

    // 籃框
    canvas.drawLine(
      Offset(hp.dx - rim, hp.dy),
      Offset(hp.dx + rim, hp.dy),
      Paint()
        ..color = const Color(0xFFE85D1F)
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 前景：籃球、拉弓線、拋物線預測、星星、GOAL、計分、第一次提示。
class _PlayPainter extends CustomPainter {
  _PlayPainter({
    required this.ball,
    required this.ballR,
    required this.rot,
    required this.aiming,
    required this.anchor,
    required this.aim,
    required this.sparks,
    required this.score,
    required this.goalFlash,
    required this.hint,
    required this.time,
  });

  final Offset ball;
  final double ballR;
  final double rot;
  final bool aiming;
  final Offset anchor;
  final Offset aim;
  final List<_Spark> sparks;
  final int score;
  final double goalFlash;
  final bool hint;
  final double time;

  static const List<Color> _sparkColors = [
    Color(0xFFFFD54F),
    Color(0xFFFF8A65),
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // ── 第一次玩的提示光圈 ──
    if (hint) {
      final pulse = 0.5 + 0.5 * math.sin(time * 3.2);
      canvas.drawCircle(
        ball,
        ballR * (1.6 + pulse * 0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: 0.28 + pulse * 0.3),
      );
      _text(canvas, '拉我 →', Offset(ball.dx, ball.dy - ballR * 2.6),
          size: 9, color: Colors.white.withValues(alpha: 0.85));
    }

    // ── 拉弓線 + 拋物線預測 ──
    if (aiming && aim.distance > 6) {
      canvas.drawLine(
        anchor,
        anchor + aim,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.75)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        anchor,
        3,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );

      double x = anchor.dx + aim.dx, y = anchor.dy + aim.dy;
      double vx = -aim.dx * _kLaunchK, vy = -aim.dy * _kLaunchK;
      final g = _gravityOf(size);
      const dt = 0.045;
      final dot = Paint();
      for (int i = 0; i < 22; i++) {
        vy += g * dt;
        x += vx * dt;
        y += vy * dt;
        if (y > size.height + 10 || x < -10 || x > size.width + 10) break;
        dot.color = Colors.white.withValues(alpha: (1 - i / 22) * 0.75);
        canvas.drawCircle(Offset(x, y), 1.9, dot);
      }
    }

    // ── 球的影子 ──
    final shadowY = size.height * _kFloorF + ballR * 0.55;
    final fall = ((shadowY - ball.dy) / size.height).clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(ball.dx, shadowY),
        width: ballR * 2 * (1 - fall * 0.45),
        height: ballR * 0.7 * (1 - fall * 0.45),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.14 * (1 - fall * 0.7)),
    );

    _drawBall(canvas, ball, ballR, rot);

    // ── 星星 ──
    final sp = Paint();
    for (final s in sparks) {
      final a = s.life.clamp(0.0, 1.0);
      sp.color =
          _sparkColors[s.hue % _sparkColors.length].withValues(alpha: a);
      canvas.drawCircle(Offset(s.x, s.y), 2.4 * a + 0.6, sp);
    }

    // ── 計分 ──
    _text(canvas, '🏀 $score', const Offset(8, 6),
        size: 11, center: false, color: Colors.white);

    // ── GOAL 橫幅 ──
    if (goalFlash > 0) {
      final age = 1.3 - goalFlash;
      final pop = math.min(1.0, age / 0.18);
      final scale = 0.55 + 0.45 * pop + math.sin(pop * math.pi) * 0.22;
      final alpha = goalFlash < 0.35 ? goalFlash / 0.35 : 1.0;
      canvas.save();
      canvas.translate(size.width / 2, size.height * 0.5);
      canvas.scale(scale);
      _text(canvas, 'GOAL!', Offset.zero,
          size: 20,
          color: const Color(0xFFFFC107).withValues(alpha: alpha),
          weight: FontWeight.w600);
      canvas.restore();
    }
  }

  /// 橘身 + 黑縫線 + 高光的籃球。
  void _drawBall(Canvas c, Offset p, double r, double rotation) {
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(rotation);

    c.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFFE8722C));
    c.drawCircle(
      Offset(-r * 0.3, -r * 0.32),
      r * 0.55,
      Paint()..color = const Color(0xFFFF9A4D).withValues(alpha: 0.55),
    );

    final line = Paint()
      ..color = const Color(0xFF5D2E0C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, r * 0.13)
      ..strokeCap = StrokeCap.round;

    c.drawCircle(Offset.zero, r, line);
    c.drawLine(Offset(-r, 0), Offset(r, 0), line);
    c.drawLine(Offset(0, -r), Offset(0, r), line);
    c.drawArc(
      Rect.fromCircle(center: Offset(-r * 1.5, 0), radius: r * 1.6),
      -0.653,
      1.306,
      false,
      line,
    );
    c.drawArc(
      Rect.fromCircle(center: Offset(r * 1.5, 0), radius: r * 1.6),
      math.pi - 0.653,
      1.306,
      false,
      line,
    );

    c.restore();
  }

  void _text(
    Canvas c,
    String s,
    Offset at, {
    double size = 11,
    Color color = Colors.white,
    FontWeight weight = FontWeight.w600,
    bool center = true,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: weight,
          shadows: const [Shadow(blurRadius: 3, color: Color(0x88000000))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
  }

  @override
  bool shouldRepaint(covariant _PlayPainter old) => true;
}
