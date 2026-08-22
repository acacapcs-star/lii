import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/mood_theme_service.dart';

/// 🧧 過年紅包 v2：
/// - [HongbaoEnvelope]：固定安置在「更多功能」標題旁的紅包（過年氛圍才出現），
///   點它 → 開出隨機吉利金額，並通知全頁金錢層從紅包位置噴灑
/// - [HongbaoLayer]：疊在頁面上的金錢噴灑層（IgnorePointer，不擋互動）

class HongbaoBurstController extends ChangeNotifier {
  int playCount = 0;
  Offset origin = Offset.zero;
  int amount = 0;

  void burst(Offset o, int amt) {
    origin = o;
    amount = amt;
    playCount++;
    notifyListeners();
  }
}

final hongbaoBurstProvider =
    ChangeNotifierProvider<HongbaoBurstController>(
  (ref) => HongbaoBurstController(),
);

/// 金錢層的定位錨點（讓紅包能換算自己在此層中的座標）。
final GlobalKey hongbaoLayerKey = GlobalKey();

/// ── 固定在「更多功能」旁的紅包 ──────────────────────────────────
class HongbaoEnvelope extends ConsumerStatefulWidget {
  const HongbaoEnvelope({super.key});

  @override
  ConsumerState<HongbaoEnvelope> createState() => _HongbaoEnvelopeState();
}

class _HongbaoEnvelopeState extends ConsumerState<HongbaoEnvelope>
    with TickerProviderStateMixin {
  static const List<int> _luckyAmounts = [
    6, 8, 66, 88, 168, 200, 520, 666, 888, 1688,
  ];

  late final AnimationController _bob;
  late final AnimationController _open;
  final math.Random _rng = math.Random();
  int _amount = 0;
  bool _showAmount = false;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _open = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _bob.dispose();
    _open.dispose();
    super.dispose();
  }

  void _tap() {
    HapticFeedback.mediumImpact();
    _open.forward(from: 0);
    final amount = _luckyAmounts[_rng.nextInt(_luckyAmounts.length)];

    // 換算紅包中心在金錢層裡的座標
    Offset origin = Offset.zero;
    final selfBox = context.findRenderObject() as RenderBox?;
    final layerBox =
        hongbaoLayerKey.currentContext?.findRenderObject() as RenderBox?;
    if (selfBox != null && layerBox != null) {
      origin = selfBox.localToGlobal(
        selfBox.size.center(Offset.zero),
        ancestor: layerBox,
      );
    }
    ref.read(hongbaoBurstProvider).burst(origin, amount);

    setState(() {
      _amount = amount;
      _showAmount = true;
    });
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _showAmount = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final newYear = ref.watch(moodThemeProvider) == MoodTheme.newYear;
    if (!newYear) return const SizedBox.shrink();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bob, _open]),
        builder: (context, child) {
          final bobT = _bob.value;
          final openT = _open.value;
          final wob = math.sin(openT * math.pi * 4) * (1 - openT) * 0.18;
          final pop = 1 + math.sin(openT * math.pi) * 0.18;
          return Transform.translate(
            offset: Offset(0, bobT * 3 - 1.5),
            child: Transform.rotate(
              angle: (bobT - 0.5) * 0.08 + wob,
              child: Transform.scale(scale: pop, child: child),
            ),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showAmount ? 1 : 0,
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '＄$_amount',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFD54F),
                  ),
                ),
              ),
            ),
            Image.asset(
              'assets/images/mood_hongbao.png',
              width: 52,
              errorBuilder: (_, __, ___) =>
                  const Text('🧧', style: TextStyle(fontSize: 28)),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── 全頁金錢噴灑層 ──────────────────────────────────────────────
class _Money {
  _Money({
    required this.delay,
    required this.vx,
    required this.vy,
    required this.spinPhase,
    required this.spinSpeed,
    required this.type,
    required this.size,
  });

  final double delay;
  final double vx;
  final double vy;
  final double spinPhase;
  final double spinSpeed;
  final int type; // 0=金幣 1=銀幣 2=鈔票
  final double size;
}

class HongbaoLayer extends ConsumerStatefulWidget {
  const HongbaoLayer({super.key});

  @override
  ConsumerState<HongbaoLayer> createState() => _HongbaoLayerState();
}

class _HongbaoLayerState extends ConsumerState<HongbaoLayer>
    with SingleTickerProviderStateMixin {
  static const List<String> _moneyAssets = [
    'assets/images/mood_coin_gold.png',
    'assets/images/mood_coin_silver.png',
    'assets/images/mood_bill.png',
  ];

  late final Ticker _ticker;
  final math.Random _rng = math.Random();
  final List<_Money> _money = [];
  List<ui.Image>? _images;
  Future<List<ui.Image>>? _imagesFuture;
  double _elapsed = 0;
  double _totalT = 0;
  Offset _origin = Offset.zero;
  int _seenPlay = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    final imgs = _images;
    if (imgs != null) {
      for (final img in imgs) {
        img.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _ensureImages() async {
    _imagesFuture ??= () async {
      final list = <ui.Image>[];
      try {
        for (final asset in _moneyAssets) {
          final data = await rootBundle.load(asset);
          final codec =
              await ui.instantiateImageCodec(data.buffer.asUint8List());
          final frame = await codec.getNextFrame();
          list.add(frame.image);
        }
        return list;
      } catch (_) {
        for (final img in list) {
          img.dispose();
        }
        return const <ui.Image>[];
      }
    }();
    _images = await _imagesFuture!;
  }

  Future<void> _startBurst(Offset origin, int amount) async {
    await _ensureImages();
    if (!mounted) return;
    final n = (8 + math.log(amount + 1) * 3.2).round().clamp(8, 30);
    _origin = origin;
    _money.clear();
    for (int i = 0; i < n; i++) {
      final type = _rng.nextDouble() < 0.34
          ? 2
          : (_rng.nextDouble() < 0.55 ? 0 : 1);
      _money.add(_Money(
        delay: _rng.nextDouble() * 0.45,
        vx: (_rng.nextDouble() - 0.5) * 320, // 左右對稱噴灑
        vy: -(90 + _rng.nextDouble() * 220),
        spinPhase: _rng.nextDouble() * math.pi * 2,
        spinSpeed: (_rng.nextDouble() - 0.5) * 9,
        type: type,
        size:
            type == 2 ? 30 + _rng.nextDouble() * 12 : 20 + _rng.nextDouble() * 10,
      ));
    }
    _totalT = 2.6;
    _ticker.stop();
    setState(() => _elapsed = 0);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    if (t >= _totalT) {
      _ticker.stop();
      setState(() {
        _money.clear();
        _elapsed = 0;
      });
      return;
    }
    setState(() => _elapsed = t);
  }

  @override
  Widget build(BuildContext context) {
    final newYear = ref.watch(moodThemeProvider) == MoodTheme.newYear;
    final ctrl = ref.watch(hongbaoBurstProvider);
    if (ctrl.playCount != _seenPlay) {
      _seenPlay = ctrl.playCount;
      final o = ctrl.origin;
      final a = ctrl.amount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startBurst(o, a);
      });
    }
    if (!newYear) return SizedBox.expand(key: hongbaoLayerKey);

    return SizedBox.expand(
      key: hongbaoLayerKey,
      child: _money.isEmpty
          ? null
          : IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _MoneyPainter(
                    money: _money,
                    images: _images ?? const [],
                    elapsed: _elapsed,
                    totalT: _totalT,
                    origin: _origin,
                  ),
                ),
              ),
            ),
    );
  }
}

class _MoneyPainter extends CustomPainter {
  _MoneyPainter({
    required this.money,
    required this.images,
    required this.elapsed,
    required this.totalT,
    required this.origin,
  });

  final List<_Money> money;
  final List<ui.Image> images;
  final double elapsed;
  final double totalT;
  final Offset origin;

  static const double _gravity = 500;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.medium;
    final fallbackFill = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < money.length; i++) {
      final m = money[i];
      final t = elapsed - m.delay;
      if (t < 0) continue;

      double x = origin.dx + m.vx * t;
      final y = origin.dy + m.vy * t + 0.5 * _gravity * t * t;
      if (m.type == 2) {
        x += math.sin(t * 6 + i) * 9;
      }
      if (y > size.height + 50) continue;

      double alpha = 1.0;
      final fadeStart = totalT - 0.5;
      if (elapsed > fadeStart) {
        alpha = (1 - (elapsed - fadeStart) / 0.5).clamp(0.0, 1.0);
      }

      final rot = m.spinPhase + m.spinSpeed * t;
      if (m.type < images.length && images.isNotEmpty) {
        final img = images[m.type];
        final scale = m.size / img.width;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rot);
        canvas.scale(scale);
        paint.color = Colors.white.withValues(alpha: alpha);
        canvas.drawImage(img, Offset(-img.width / 2, -img.height / 2), paint);
        canvas.restore();
      } else {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rot);
        if (m.type == 2) {
          fallbackFill.color =
              const Color(0xFF66A55C).withValues(alpha: alpha);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset.zero, width: m.size, height: m.size * 0.5),
                const Radius.circular(3)),
            fallbackFill,
          );
        } else {
          fallbackFill.color = (m.type == 0
                  ? const Color(0xFFF5C242)
                  : const Color(0xFFC9CDD2))
              .withValues(alpha: alpha);
          canvas.drawCircle(Offset.zero, m.size / 2, fallbackFill);
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_MoneyPainter old) =>
      old.elapsed != elapsed || old.money != money;
}
