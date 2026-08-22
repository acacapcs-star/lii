import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/mood_theme_service.dart';

/// ☀️ 夏天全頁樂園：
/// - 魚在整個首頁游泳（卡片後面），按住可撈起、放開回水流
/// - 🏀 Angry Birds 式投籃：按住左下角的籃球往後拉瞄準（顯示軌跡預測點），
///   放開發射！投進右上的籃框 = GOAL 🎉（有計分）
///
/// [FishVisualLayer] 墊在卡片後面、[FishTouchLayer] 浮在最上層只攔魚和球。

class PondFish {
  PondFish({
    required this.asset,
    required this.x,
    required this.y,
    required this.speed,
    required this.dir,
    required this.bobPhase,
    required this.size,
  });

  final String asset;
  double x;
  double y;
  double speed;
  int dir;
  final double bobPhase;
  final double size;
  bool picked = false;
}

enum BallPhase { resting, aiming, flying, returning }

class FishPondController extends ChangeNotifier {
  final math.Random _rng = math.Random();
  Size pageSize = Size.zero;
  final List<PondFish> fish = [];

  // ── 籃球 ──
  BallPhase phase = BallPhase.resting;
  double bx = 0, by = 0, bvx = 0, bvy = 0, bRot = 0, bSpin = 0;
  double _prevBy = 0;
  Offset aimPos = Offset.zero; // 瞄準時球被拉到的位置
  bool _ballInit = false;
  int score = 0;
  double lastGoalAt = -99; // 進球時刻（秒）
  double _now = 0;

  static const double swimTopF = 0.015; // 魚缸頂（狀態卡以上區域）
  static const double swimBotF = 0.155; // 魚缸底（Doing ok 卡片上緣附近）
  static const double ballR = 15;
  static const double aimMaxPull = 120; // 最大拉弓距離
  static const double launchK = 11.0; // 拉距 → 初速倍率（加大，飛得起來）
  static const double gravity = 950;

  Offset get restAnchor =>
      Offset(pageSize.width * 0.20, pageSize.height * 0.80); // 發射台上移，拉弓空間加倍

  // 籃框幾何（右上）
  double get rimCx => pageSize.width - 64;
  double get rimCy => pageSize.height * 0.42; // 籃框在下半場
  static const double rimR = 27; // 框半徑（開口）
  double get boardX => pageSize.width - 26; // 籃板

  void ensureInit(Size size) {
    if (size.isEmpty) return;
    pageSize = size;
    if (fish.isEmpty) {
      const assets = [
        'assets/images/mood_fish_1.png',
        'assets/images/mood_fish_2.png',
        'assets/images/mood_fish_3.png',
        'assets/images/mood_fish_4.png',
      ];
      final top = size.height * swimTopF;
      final bot = size.height * swimBotF;
      for (final a in assets) {
        fish.add(PondFish(
          asset: a,
          x: _rng.nextDouble() * size.width,
          y: top + _rng.nextDouble() * (bot - top),
          speed: 16 + _rng.nextDouble() * 26,
          dir: _rng.nextBool() ? 1 : -1,
          bobPhase: _rng.nextDouble() * math.pi * 2,
          size: 26 + _rng.nextDouble() * 10, // 魚缸魚小巧一點
        ));
      }
    }
    if (!_ballInit) {
      _ballInit = true;
      bx = restAnchor.dx;
      by = restAnchor.dy;
    }
  }

  /// 依目前拉弓位置計算發射初速。
  Offset launchVelocity() {
    final pull = restAnchor - aimPos;
    return Offset(pull.dx * launchK, pull.dy * launchK);
  }

  /// 瞄準時的拋物線預測點。
  List<Offset> trajectory() {
    final v = launchVelocity();
    final pts = <Offset>[];
    for (int i = 1; i <= 8; i++) {
      final t = i * 0.075;
      pts.add(Offset(
        aimPos.dx + v.dx * t,
        aimPos.dy + v.dy * t + 0.5 * gravity * t * t,
      ));
    }
    return pts;
  }

  void step(double dt, double t) {
    if (pageSize.isEmpty) return;
    _now = t;
    final top = pageSize.height * swimTopF;
    final bot = pageSize.height * swimBotF;

    for (final f in fish) {
      if (f.picked) continue;
      f.x += f.speed * f.dir * dt;
      f.y = (f.y + math.sin(t * 1.4 + f.bobPhase) * 10 * dt).clamp(top, bot);
      if (f.dir > 0 && f.x > pageSize.width + f.size) {
        f.x = -f.size;
      } else if (f.dir < 0 && f.x < -f.size) {
        f.x = pageSize.width + f.size;
      }
    }

    if (phase == BallPhase.flying) {
      _prevBy = by;
      bvy += gravity * dt;
      bx += bvx * dt;
      by += bvy * dt;
      bRot += bSpin * dt;

      // 牆壁與天花板
      if (bx < ballR) {
        bx = ballR;
        bvx = -bvx * 0.7;
      } else if (bx > pageSize.width - ballR) {
        bx = pageSize.width - ballR;
        bvx = -bvx * 0.7;
      }
      final tankGlass = pageSize.height * swimBotF + ballR + 4;
      if (by < tankGlass) {
        by = tankGlass;
        bvy = -bvy * 0.7; // 撞到魚缸底部玻璃反彈，球進不了魚缸
      }

      // 籃板（右側垂直板）
      if (bx > boardX - ballR &&
          by > rimCy - 62 &&
          by < rimCy + 8 &&
          bvx > 0) {
        bx = boardX - ballR;
        bvx = -bvx * 0.62;
        bSpin = -bSpin * 0.5;
      }

      // 框緣碰撞（框的左右兩端當作小圓柱）
      for (final rimX in [rimCx - rimR, rimCx + rimR]) {
        final dx = bx - rimX;
        final dy = by - rimCy;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < ballR + 3 && d > 0.1) {
          final nx = dx / d, ny = dy / d;
          final dot = bvx * nx + bvy * ny;
          if (dot < 0) {
            bvx = (bvx - 2 * dot * nx) * 0.65;
            bvy = (bvy - 2 * dot * ny) * 0.65;
            bx = rimX + nx * (ballR + 3.2);
            by = rimCy + ny * (ballR + 3.2);
          }
        }
      }

      // GOAL 判定：由上往下穿過框中線
      if (_prevBy < rimCy &&
          by >= rimCy &&
          bvy > 0 &&
          (bx - rimCx).abs() < rimR - ballR * 0.35) {
        score++;
        lastGoalAt = t;
        HapticFeedback.heavyImpact();
      }

      // 落地
      final rest = pageSize.height - ballR - 8;
      if (by >= rest) {
        by = rest;
        bvy = -bvy * 0.55;
        bvx *= 0.85;
        if (bvy.abs() < 60) {
          phase = BallPhase.returning; // 自動飛回發射點
          bSpin = 0;
        }
      }
    } else if (phase == BallPhase.returning) {
      final a = restAnchor;
      bx += (a.dx - bx) * math.min(1, dt * 5);
      by += (a.dy - by) * math.min(1, dt * 5);
      bRot *= 0.9;
      if ((Offset(bx, by) - a).distance < 2) {
        bx = a.dx;
        by = a.dy;
        bRot = 0;
        phase = BallPhase.resting;
      }
    }
    notifyListeners();
  }

  // ── 瞄準（Angry Birds 拉弓）──
  void aimStart() {
    if (phase != BallPhase.resting) return;
    phase = BallPhase.aiming;
    aimPos = restAnchor;
    notifyListeners();
  }

  void aimUpdate(Offset delta) {
    if (phase != BallPhase.aiming) return;
    var p = aimPos + delta;
    final pull = p - restAnchor;
    if (pull.distance > aimMaxPull) {
      p = restAnchor + pull / pull.distance * aimMaxPull;
    }
    aimPos = Offset(
      p.dx.clamp(ballR, pageSize.width - ballR),
      p.dy.clamp(
          pageSize.height * swimBotF + ballR + 4, pageSize.height - ballR),
    );
    bx = aimPos.dx;
    by = aimPos.dy;
    notifyListeners();
  }

  void aimRelease() {
    if (phase != BallPhase.aiming) return;
    final v = launchVelocity();
    if (v.distance < 140) {
      // 拉太短：放回去不發射
      phase = BallPhase.returning;
      notifyListeners();
      return;
    }
    HapticFeedback.mediumImpact();
    phase = BallPhase.flying;
    bvx = v.dx.clamp(-1500.0, 1500.0);
    bvy = v.dy.clamp(-1600.0, 1200.0);
    bSpin = (bvx >= 0 ? 1 : -1) * 9;
    _prevBy = by;
    notifyListeners();
  }

  // ── 魚 ──
  void pick(PondFish f) {
    f.picked = true;
    notifyListeners();
  }

  void dragBy(PondFish f, Offset delta) {
    f.x = (f.x + delta.dx).clamp(0.0, pageSize.width);
    f.y = (f.y + delta.dy).clamp(0.0, pageSize.height);
    notifyListeners();
  }

  void release(PondFish f) {
    f.picked = false;
    f.y = f.y.clamp(pageSize.height * swimTopF, pageSize.height * swimBotF);
    f.dir = _rng.nextBool() ? 1 : -1;
    notifyListeners();
  }

  bool get goalFlash => _now - lastGoalAt < 1.2;
  double get goalT => _now - lastGoalAt;
}

final fishPondProvider = ChangeNotifierProvider<FishPondController>(
  (ref) => FishPondController(),
);

/// 視覺層：墊在首頁內容下面。IgnorePointer，純顯示。
class FishVisualLayer extends ConsumerStatefulWidget {
  const FishVisualLayer({super.key});

  @override
  ConsumerState<FishVisualLayer> createState() => _FishVisualLayerState();
}

class _FishVisualLayerState extends ConsumerState<FishVisualLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    ref.read(fishPondProvider).step(dt, elapsed.inMicroseconds / 1e6);
  }

  @override
  Widget build(BuildContext context) {
    final summer = ref.watch(moodThemeProvider) == MoodTheme.summer;
    if (!summer) {
      if (_ticker.isActive) _ticker.stop();
      return const SizedBox.shrink();
    }
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
    final pond = ref.watch(fishPondProvider);
    return LayoutBuilder(builder: (context, constraints) {
      pond.ensureInit(Size(constraints.maxWidth, constraints.maxHeight));
      return IgnorePointer(
        child: Stack(
          children: [
            // （籃框+籃球已搬到最上層 FishTouchLayer，浮在卡片上）
            // 這層只留魚，讓魚半遮半掩在卡片後面
            for (final f in pond.fish)
              Positioned(
                left: f.x - f.size / 2,
                top: f.y - f.size / 2,
                child: Transform.scale(
                  scaleX: f.dir > 0 ? -1 : 1,
                  child: Transform.scale(
                    scale: f.picked ? 1.3 : 1.0,
                    child: Image.asset(
                      f.asset,
                      width: f.size,
                      errorBuilder: (_, __, ___) => Text('🐟',
                          style: TextStyle(fontSize: f.size * 0.8)),
                    ),
                  ),
                ),
              ),
            // GOAL 橫幅
            if (pond.goalFlash)
              Positioned(
                right: 24,
                top: pond.pageSize.height * 0.50, // 靠近下半場籃框
                child: Transform.scale(
                  scale: Curves.elasticOut
                      .transform((pond.goalT / 0.5).clamp(0.0, 1.0)),
                  child: Opacity(
                    opacity: pond.goalT > 0.9
                        ? (1 - (pond.goalT - 0.9) / 0.3).clamp(0.0, 1.0)
                        : 1.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8F3C),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'GOAL! 🏀',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _HoopBallPainter extends CustomPainter {
  _HoopBallPainter(this.pond) : super(repaint: pond);

  final FishPondController pond;

  @override
  void paint(Canvas canvas, Size size) {
    if (pond.pageSize.isEmpty) return;

    // ── 魚缸（頂部半透明水藍缸）──
    final tankRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        8,
        size.height * FishPondController.swimTopF - 6,
        size.width - 16,
        size.height *
                (FishPondController.swimBotF -
                    FishPondController.swimTopF) +
            14,
      ),
      const Radius.circular(16),
    );
    canvas.drawRRect(
        tankRect,
        Paint()..color = const Color(0xFF6EC6E8).withValues(alpha: 0.12));
    canvas.drawRRect(
        tankRect,
        Paint()
          ..color = const Color(0xFF6EC6E8).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);

    final rimCx = pond.rimCx, rimCy = pond.rimCy;
    const rimR = FishPondController.rimR;

    // ── 籃板 ──
    final board = Paint()..color = Colors.white.withValues(alpha: 0.9);
    final boardBorder = Paint()
      ..color = const Color(0xFF9AA7B5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final boardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pond.boardX - 4, rimCy - 62, 12, 64),
      const Radius.circular(3),
    );
    canvas.drawRRect(boardRect, board);
    canvas.drawRRect(boardRect, boardBorder);

    // ── 框（橘色）──
    final rim = Paint()
      ..color = const Color(0xFFE8622C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(rimCx - rimR, rimCy), Offset(rimCx + rimR, rimCy), rim);
    // 連接籃板的小桿
    canvas.drawLine(
        Offset(rimCx + rimR, rimCy), Offset(pond.boardX - 3, rimCy - 4), rim);

    // ── 網子 ──
    final net = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const netH = 26.0;
    for (int i = 0; i <= 4; i++) {
      final x1 = rimCx - rimR + i * (rimR * 2 / 4);
      final x2 = rimCx - rimR * 0.6 + i * (rimR * 1.2 / 4);
      canvas.drawLine(Offset(x1, rimCy), Offset(x2, rimCy + netH), net);
    }
    final netPath = Path()
      ..moveTo(rimCx - rimR * 0.6, rimCy + netH)
      ..lineTo(rimCx + rimR * 0.6, rimCy + netH);
    canvas.drawPath(netPath, net);

    // ── 計分 ──
    if (pond.score > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: '🏀 ×${pond.score}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFFE8622C),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rimCx - tp.width / 2, rimCy + netH + 6));
    }

    // ── 瞄準：拉弓線 + 軌跡預測點 ──
    if (pond.phase == BallPhase.aiming) {
      final sling = Paint()
        ..color = const Color(0xFF8D6E63).withValues(alpha: 0.7)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(pond.restAnchor, Offset(pond.bx, pond.by), sling);
      final dots = pond.trajectory();
      for (int i = 0; i < dots.length; i++) {
        final a = (1 - i / dots.length) * 0.75;
        canvas.drawCircle(
          dots[i],
          4 - i * 0.3,
          Paint()..color = const Color(0xFFE8622C).withValues(alpha: a),
        );
      }
    }

    // ── 籃球 ──
    canvas.save();
    canvas.translate(pond.bx, pond.by);
    canvas.rotate(pond.bRot);
    const r = FishPondController.ballR;
    canvas.drawCircle(
        Offset.zero, r, Paint()..color = const Color(0xFFE8783C));
    final seam = Paint()
      ..color = const Color(0xFF7A3A16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(Offset.zero, r, seam);
    canvas.drawLine(const Offset(-r, 0), const Offset(r, 0), seam);
    canvas.drawLine(const Offset(0, -r), const Offset(0, r), seam);
    canvas.drawArc(Rect.fromCircle(center: const Offset(-r * 1.1, 0), radius: r),
        -math.pi / 3, math.pi * 2 / 3, false, seam);
    canvas.drawArc(Rect.fromCircle(center: const Offset(r * 1.1, 0), radius: r),
        math.pi - math.pi / 3, math.pi * 2 / 3, false, seam);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 觸控層：只在魚/籃球的位置放手勢感應區，其他區域完全穿透。
class FishTouchLayer extends ConsumerWidget {
  const FishTouchLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summer = ref.watch(moodThemeProvider) == MoodTheme.summer;
    if (!summer) return const SizedBox.shrink();
    final pond = ref.watch(fishPondProvider);

    return Stack(
      children: [
        // 🏀 籃框+籃球浮在卡片上面（純顯示，不擋手勢）
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _HoopBallPainter(pond)),
          ),
        ),
        for (final f in pond.fish)
          Positioned(
            left: f.x - f.size / 2 - 6,
            top: f.y - f.size / 2 - 6,
            width: f.size + 12,
            height: f.size + 12,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) {
                HapticFeedback.selectionClick();
                ref.read(fishPondProvider).pick(f);
              },
              onPanUpdate: (d) =>
                  ref.read(fishPondProvider).dragBy(f, d.delta),
              onPanEnd: (_) {
                HapticFeedback.lightImpact();
                ref.read(fishPondProvider).release(f);
              },
              onPanCancel: () => ref.read(fishPondProvider).release(f),
            ),
          ),
        // 籃球（拉弓瞄準）— 整頁接收，只有按在球附近才搶手勢，
        // 其他地方穿透放行給卡片/捲動，才不會「碰不到球」。
        if (pond.phase == BallPhase.resting ||
            pond.phase == BallPhase.aiming)
          Positioned.fill(
            child: RawGestureDetector(
              behavior: HitTestBehavior.translucent,
              gestures: <Type, GestureRecognizerFactory>{
                _BallDragRecognizer:
                    GestureRecognizerFactoryWithHandlers<_BallDragRecognizer>(
                  () => _BallDragRecognizer(),
                  (rec) {
                    rec.ballPos = Offset(pond.bx, pond.by);
                    rec.grabRadius = FishPondController.ballR * 4.5;
                    rec.onStart = (_) {
                      HapticFeedback.selectionClick();
                      ref.read(fishPondProvider).aimStart();
                    };
                    rec.onUpdate = (d) {
                      ref.read(fishPondProvider).aimUpdate(d.delta);
                    };
                    rec.onEnd = (_) {
                      ref.read(fishPondProvider).aimRelease();
                    };
                    rec.onCancel = () {
                      ref.read(fishPondProvider).aimRelease();
                    };
                  },
                ),
              },
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
  }
}


/// 籃球專用手勢辨識器：手指按在球附近才拿下手勢，其他地方放行給頁面。
/// 內建 PanGestureRecognizer 要移動 36px 才出手，會被卡片/捲動搶走；
/// 這裡在 pointer down 當下就判斷離球多遠，近就 accept、遠就不進場。
class _BallDragRecognizer extends PanGestureRecognizer {
  Offset ballPos = Offset.zero;
  double grabRadius = 64;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if ((event.localPosition - ballPos).distance > grabRadius) return;
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
