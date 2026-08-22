import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/mood_theme_service.dart';

/// ☀️ 夏天角落：一片迷你海灘。
/// - 4 隻魚在海裡游來游去（會上下擺動、碰到邊緣折返）
/// - 按住魚可以「拿起來」拖著走，放開會撲通掉回海裡、從那裡繼續游
/// - 沙灘上的排球點一下會彈跳翻滾
class BeachCorner extends StatefulWidget {
  const BeachCorner({super.key});

  @override
  State<BeachCorner> createState() => _BeachCornerState();
}

class _Fish {
  _Fish({
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
  double speed; // px/s
  int dir; // 1 = 往右, -1 = 往左
  final double bobPhase;
  final double size;
  bool picked = false;
  double? targetY; // 放開後要回到的海裡位置
}

class _BeachCornerState extends State<BeachCorner>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final math.Random _rng = math.Random();

  final List<_Fish> _fish = [];
  Size _size = Size.zero;

  // 排球狀態
  double _bx = 0, _by = 0, _bvx = 0, _bvy = 0, _bRot = 0, _bSpin = 0;
  bool _ballResting = true;

  static const double _seaTopF = 0.34; // 海面（佔卡片高度比例）
  static const double _seaBotF = 0.76; // 海底
  static const double _sandF = 0.78; // 沙灘起點

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
    _size = size;
    if (_fish.isEmpty) {
      const assets = [
        'assets/images/mood_fish_1.png',
        'assets/images/mood_fish_2.png',
        'assets/images/mood_fish_3.png',
        'assets/images/mood_fish_4.png',
      ];
      for (int i = 0; i < assets.length; i++) {
        final seaTop = size.height * _seaTopF;
        final seaBot = size.height * _seaBotF;
        _fish.add(_Fish(
          asset: assets[i],
          x: _rng.nextDouble() * size.width,
          y: seaTop + _rng.nextDouble() * (seaBot - seaTop),
          speed: 14 + _rng.nextDouble() * 22,
          dir: _rng.nextBool() ? 1 : -1,
          bobPhase: _rng.nextDouble() * math.pi * 2,
          size: 20 + _rng.nextDouble() * 8,
        ));
      }
      _bx = size.width * 0.78;
      _by = size.height * _sandF;
    }
  }

  void _onTick(Duration elapsed) {
    final dt =
        ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    if (_size.isEmpty) return;

    final t = elapsed.inMicroseconds / 1e6;
    final seaTop = _size.height * _seaTopF;
    final seaBot = _size.height * _seaBotF;

    for (final f in _fish) {
      if (f.picked) continue;
      if (f.targetY != null) {
        // 放開後游回海裡（撲通）
        f.y += (f.targetY! - f.y) * math.min(1, dt * 8);
        if ((f.y - f.targetY!).abs() < 1.5) {
          f.y = f.targetY!;
          f.targetY = null;
        }
      } else {
        f.x += f.speed * f.dir * dt;
        f.y = (f.y + math.sin(t * 1.6 + f.bobPhase) * 6 * dt)
            .clamp(seaTop, seaBot);
        if (f.x < 4) {
          f.x = 4;
          f.dir = 1;
        } else if (f.x > _size.width - 4) {
          f.x = _size.width - 4;
          f.dir = -1;
        }
      }
    }

    // 排球物理
    if (!_ballResting) {
      _bvy += 700 * dt;
      _bx += _bvx * dt;
      _by += _bvy * dt;
      _bRot += _bSpin * dt;
      final rest = _size.height * _sandF;
      if (_bx < 14) {
        _bx = 14;
        _bvx = -_bvx * 0.7;
      } else if (_bx > _size.width - 14) {
        _bx = _size.width - 14;
        _bvx = -_bvx * 0.7;
      }
      if (_by >= rest) {
        _by = rest;
        _bvy = -_bvy * 0.55;
        _bvx *= 0.8;
        if (_bvy.abs() < 50) {
          _ballResting = true;
          _bvx = 0;
          _bvy = 0;
        }
      }
    }
    setState(() {});
  }

  void _kickBall() {
    HapticFeedback.lightImpact();
    _ballResting = false;
    _bvy = -(220 + _rng.nextDouble() * 90);
    _bvx = (_rng.nextDouble() - 0.5) * 140;
    _bSpin = (_rng.nextDouble() - 0.5) * 12;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: LayoutBuilder(builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _layout(size);
        return Stack(
          children: [
            // 天空/大海/沙灘背景
            Positioned.fill(
              child: CustomPaint(painter: _BeachPainter()),
            ),
            // 魚（可拖曳）
            for (final f in _fish)
              Positioned(
                left: f.x - f.size / 2,
                top: f.y - f.size / 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      f.picked = true;
                      f.targetY = null;
                    });
                  },
                  onPanUpdate: (d) {
                    setState(() {
                      f.x = (f.x + d.delta.dx).clamp(4.0, size.width - 4);
                      f.y = (f.y + d.delta.dy).clamp(4.0, size.height - 4);
                    });
                  },
                  onPanEnd: (_) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      f.picked = false;
                      // 放回旁邊的水流：落回海裡、從這個位置繼續游
                      f.targetY = f.y.clamp(
                        size.height * _seaTopF,
                        size.height * _seaBotF,
                      );
                      f.dir = _rng.nextBool() ? 1 : -1;
                    });
                  },
                  child: Transform.scale(
                    scaleX: f.dir > 0 ? -1 : 1,
                    child: Transform.scale(
                      scale: f.picked ? 1.25 : 1.0, // 拿起來會變大一點
                      child: Image.asset(
                        f.asset,
                        width: f.size,
                        errorBuilder: (_, __, ___) =>
                            Text('🐟', style: TextStyle(fontSize: f.size * 0.8)),
                      ),
                    ),
                  ),
                ),
              ),
            // 排球
            Positioned(
              left: _bx - 13,
              top: _by - 26,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _kickBall,
                child: Transform.rotate(
                  angle: _bRot,
                  child: Image.asset(
                    'assets/images/mood_volleyball.png',
                    width: 26,
                    errorBuilder: (_, __, ___) =>
                        const Text('🏐', style: TextStyle(fontSize: 20)),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _BeachPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 天空
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.36),
      Paint()..color = const Color(0xFFBFE7FA),
    );
    // 太陽
    canvas.drawCircle(
        Offset(w * 0.14, h * 0.14), 9, Paint()..color = const Color(0xFFFFD54F));
    // 大海
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.30, w, h * 0.50),
      Paint()..color = const Color(0xFF6EC6E8),
    );
    // 海面波浪線
    final wave = Paint()
      ..color = const Color(0xFFB8E5F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..moveTo(0, h * 0.31);
    for (double x = 0; x <= w; x += 14) {
      path.quadraticBezierTo(
          x + 3.5, h * 0.31 - 3, x + 7, h * 0.31);
      path.quadraticBezierTo(
          x + 10.5, h * 0.31 + 3, x + 14, h * 0.31);
    }
    canvas.drawPath(path, wave);
    // 沙灘
    final sand = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.84)
      ..quadraticBezierTo(w * 0.5, h * 0.74, w, h * 0.82)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(sand, Paint()..color = const Color(0xFFF5DFA9));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 🏖️ 暑假角落：清涼冰品，輕輕搖晃，點一下會開心晃動。
/// （之後有漂亮的飲料圖可以直接換圖）
class TreatCorner extends StatefulWidget {
  const TreatCorner({super.key});

  @override
  State<TreatCorner> createState() => _TreatCornerState();
}

class _TreatCornerState extends State<TreatCorner>
    with TickerProviderStateMixin {
  late final AnimationController _sway;
  late final AnimationController _wob;

  @override
  void initState() {
    super.initState();
    _sway = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _wob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
  }

  @override
  void dispose() {
    _sway.dispose();
    _wob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _wob.forward(from: 0);
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([_sway, _wob]),
        builder: (context, child) {
          final s = (_sway.value - 0.5) * 0.07;
          final t = _wob.value;
          final wob = math.sin(t * math.pi * 4) * (1 - t) * 0.09;
          return Transform.rotate(angle: s + wob, child: child);
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Image.asset(
            'assets/images/mood_icecream.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('🍦', style: TextStyle(fontSize: 44)),
            ),
          ),
        ),
      ),
    );
  }
}

/// ☀️ 夏天角落：海灘上的墨鏡貓與喝飲料的兔兔。
/// 點一下會慵懶地晃一晃（跟秋天的燈下狐狸同一種做法）。
class SummerBeachCorner extends StatefulWidget {
  const SummerBeachCorner({super.key});

  @override
  State<SummerBeachCorner> createState() => _SummerBeachCornerState();
}

class _SummerBeachCornerState extends State<SummerBeachCorner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sway;
  int _summerCatIndex = 0;
  static const _summerCats = [
    'assets/images/summer_cat_1.png',
    'assets/images/summer_cat_2.png',
    'assets/images/summer_cat_3.png',
  ];

  @override
  void initState() {
    super.initState();
    _sway = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _summerCatIndex =
            (_summerCatIndex + 1) % _summerCats.length);
        _sway.forward(from: 0);
      },
      child: ListenableBuilder(
        listenable: _sway,
        builder: (context, child) {
          final t = _sway.value;
          final wob = math.sin(t * math.pi * 3) * (1 - t) * 0.035;
          final pop = 1 + math.sin(t * math.pi) * 0.04;
          return Transform.scale(
            scale: pop,
            child: Transform.rotate(angle: wob, child: child),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            _summerCats[_summerCatIndex],
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('🐱', style: TextStyle(fontSize: 44)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 🥤 你選中的那杯飲料，掛在「更多功能」標題右邊。
/// 還沒選就不顯示；換杯時會彈跳一下。
class ChosenDrinkBadge extends ConsumerWidget {
  const ChosenDrinkBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = ref.watch(moodThemeProvider);
    if (mood != MoodTheme.summer && mood != MoodTheme.summerBreak) {
      return const SizedBox.shrink();
    }
    final selected = ref.watch(selectedDrinkProvider);
    if (selected == null) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      // key 綁選中的杯子 → 換杯就重播一次彈跳
      key: ValueKey<int>(selected),
      tween: Tween<double>(begin: 0.55, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Image.asset(
          kDrinkAssets[selected],
          height: 46,
          errorBuilder: (_, __, ___) =>
              const Text('🍹', style: TextStyle(fontSize: 30)),
        ),
      ),
    );
  }
}

/// 🏖️ 暑假：四杯飲料的素材。
const List<String> kDrinkAssets = [
  'assets/images/mood_drink_1.png', // 粉紅氣泡
  'assets/images/mood_drink_2.png', // 萊姆綠
  'assets/images/mood_drink_3.png', // 冰藍檸檬
  'assets/images/mood_drink_4.png', // 桃紅
];

/// 🏖️ 暑假：目前選中的是第幾杯（null = 還沒選）。
/// 角落的排球男孩與「更多功能」旁的飲料吧共用這個狀態。
final selectedDrinkProvider = StateProvider<int?>((ref) => null);

/// 🏖️ 暑假角落：排球男孩 + 他選中的那杯飲料。
/// 飲料吧本體搬到「更多功能」標題右邊了，見 [DrinkBarStrip]。
/// （角落卡片只有約 160x103，飲料放不大；搬出去才擺得下大杯的。）
class DrinkBarCorner extends ConsumerStatefulWidget {
  const DrinkBarCorner({super.key});

  @override
  ConsumerState<DrinkBarCorner> createState() => _DrinkBarCornerState();
}

class _DrinkBarCornerState extends ConsumerState<DrinkBarCorner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 右邊選了新的一杯 → 這裡彈跳一下
    ref.listen<int?>(selectedDrinkProvider, (prev, next) {
      if (next != null) _pop.forward(from: 0);
    });
    final selected = ref.watch(selectedDrinkProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEF),
          border: Border.all(color: const Color(0xFFF2E3B3)),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/mood_hq_boy.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('🏐', style: TextStyle(fontSize: 34)),
                ),
              ),
            ),
            if (selected != null)
              Align(
                alignment: Alignment.centerRight,
                child: ScaleTransition(
                  scale:
                      CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Image.asset(
                      kDrinkAssets[selected],
                      height: 62, // 角落只剩一杯，可以放大
                      errorBuilder: (_, __, ___) =>
                          const Text('🍹', style: TextStyle(fontSize: 36)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 🏖️ 暑假飲料吧：一整排大飲料，掛在「更多功能」標題的右邊。
/// 點一杯 → 那杯會跳到角落陪排球男孩。
/// 其他氛圍時回傳空 widget，標題那一列看起來跟以前一模一樣。
class DrinkBarStrip extends ConsumerWidget {
  const DrinkBarStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = ref.watch(moodThemeProvider);
    if (mood != MoodTheme.summer && mood != MoodTheme.summerBreak) {
      return const SizedBox.shrink();
    }
    final selected = ref.watch(selectedDrinkProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < kDrinkAssets.length; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(selectedDrinkProvider.notifier).state = i;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(left: 5),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              decoration: BoxDecoration(
                color:
                    selected == i ? const Color(0xFFFFE082) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected == i
                      ? const Color(0xFFF5B942)
                      : Colors.transparent,
                  width: 1.6,
                ),
              ),
              child: Image.asset(
                kDrinkAssets[i],
                height: 52, // 大杯的！
                errorBuilder: (_, __, ___) =>
                    const Text('🥤', style: TextStyle(fontSize: 26)),
              ),
            ),
          ),
      ],
    );
  }
}
