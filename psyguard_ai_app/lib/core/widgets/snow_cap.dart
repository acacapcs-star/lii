import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/mood_theme_service.dart';
import 'mood_fall_overlay.dart';

/// 全域積雪計數：每點一次球球下雪就 +1。
class SnowAccumulationController extends StateNotifier<int> {
  SnowAccumulationController() : super(0);

  void addSnow() => state = state + 1;
}

final snowAccumulationProvider =
    StateNotifierProvider<SnowAccumulationController, int>(
  (ref) => SnowAccumulationController(),
);

/// 秋天躲貓貓狐狸：所有「icon 口袋」向這裡登記，
/// 每一輪隨機選一個口袋當狐狸的藏身處；找到後換下一輪（換口袋躲）。
class FoxHideoutController extends ChangeNotifier {
  final List<int> _spots = [];
  final math.Random _rng = math.Random();
  int _salt = math.Random().nextInt(1 << 31);

  /// 每一輪用亂數挑一個藏身處（真隨機，不可預測）。
  int? get chosenSpot =>
      _spots.isEmpty ? null : _spots[_salt % _spots.length];

  /// 本輪亂數種子（春天用來決定這輪藏的是哪一顆彩蛋）。
  int get salt => _salt;

  void register(int id) {
    if (_spots.contains(id)) return;
    _spots.add(id);
    Future.microtask(notifyListeners);
  }

  void unregister(int id) {
    _spots.remove(id);
    Future.microtask(notifyListeners);
  }

  /// 被找到了！重新抽一個地方躲。
  void found() {
    _salt = _rng.nextInt(1 << 31);
    Future.microtask(notifyListeners);
  }
}

final foxHideoutProvider = ChangeNotifierProvider<FoxHideoutController>(
  (ref) => FoxHideoutController(),
);

/// 卡片裡的「icon 口袋」：秋天氛圍時，小狐狸會隨機躲進某一張卡片的
/// 方形 icon 後面——那個 icon 會微微晃動（口袋裡有東西在動！），
/// 右下角還露出一小截尾巴尖。
/// 點那個 icon，狐狸就蹦出來說「u find me!」，然後換一個口袋躲。
class FoxPocket extends ConsumerStatefulWidget {
  const FoxPocket({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FoxPocket> createState() => _FoxPocketState();
}

class _FoxPocketState extends ConsumerState<FoxPocket>
    with TickerProviderStateMixin {
  late final AnimationController _wiggle; // 口袋微微晃動
  late final AnimationController _pop; // 蹦出動畫
  late final int _seed;
  bool _found = false;
  FoxHideoutController? _ctrl;

  @override
  void initState() {
    super.initState();
    _seed = math.Random().nextInt(1 << 31);
    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ctrl = ref.read(foxHideoutProvider);
      _ctrl!.register(_seed);
    });
  }

  @override
  void dispose() {
    _ctrl?.unregister(_seed);
    _wiggle.dispose();
    _pop.dispose();
    super.dispose();
  }

  void _onFound() {
    if (_found) return;
    HapticFeedback.mediumImpact();
    setState(() => _found = true);
    _pop.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      setState(() => _found = false);
      ref.read(foxHideoutProvider).found(); // 換口袋躲
    });
  }

  @override
  Widget build(BuildContext context) {
    final effect = ref.watch(moodThemeProvider).fallEffect;
    final seeking = effect == FallEffectType.leaves ||
        effect == FallEffectType.petals; // 秋找狐狸、春找彩蛋
    final foxState = ref.watch(foxHideoutProvider);
    final hiding = seeking && foxState.chosenSpot == _seed;
    final isEgg = effect == FallEffectType.petals;
    final eggAsset =
        'assets/images/mood_egg_${(foxState.salt % 4) + 1}.png';

    // 只有狐狸在的口袋才需要晃動的 ticker，其他口袋完全零成本
    if (hiding && !_found) {
      if (!_wiggle.isAnimating) _wiggle.repeat();
    } else if (_wiggle.isAnimating) {
      _wiggle.stop();
      _wiggle.value = 0;
    }

    if (!hiding && !_found) return widget.child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // icon 本體：狐狸在裡面時微微晃動
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: hiding && !_found ? _onFound : null,
          child: AnimatedBuilder(
            animation: _wiggle,
            builder: (context, child) {
              final angle = hiding && !_found
                  ? math.sin(_wiggle.value * math.pi * 2) * 0.055
                  : 0.0;
              return Transform.rotate(angle: angle, child: child);
            },
            child: widget.child,
          ),
        ),
        // 被找到：從口袋蹦出來 + 「u find me!」
        if (_found)
          Positioned(
            top: -84,
            left: -10,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    margin: const EdgeInsets.only(bottom: 4, left: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8B27D)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'u found me!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB4652F),
                      ),
                    ),
                  ),
                  Image.asset(
                    isEgg ? eggAsset : 'assets/images/mood_fox_hide.png',
                    width: isEgg ? 48 : 64,
                    errorBuilder: (_, __, ___) => Text(isEgg ? '🥚' : '🦊',
                        style: const TextStyle(fontSize: 40)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 包住任何卡片/區塊：雪系氛圍時卡片頂端積雪，
/// 按住雪堆用手溫融化（放開會凍回去），融完化成半透明的水再蒸發。
class SnowCap extends ConsumerStatefulWidget {
  const SnowCap({super.key, required this.child, this.cornerInset = 18});

  final Widget child;

  /// 左右兩端內縮距離，避開卡片圓角。
  final double cornerInset;

  @override
  ConsumerState<SnowCap> createState() => _SnowCapState();
}

class _SnowCapState extends ConsumerState<SnowCap>
    with TickerProviderStateMixin {
  Timer? _snowGrow; // 每 3 秒往上積一點雪
  int _extraLevel = 0; // 額外累積的雪量（有上限）
  late final AnimationController _melt;
  late final AnimationController _fade;
  late final AnimationController _wiggle; // 狐狸躲在後面時，整張卡片微微晃動
  late final AnimationController _foxPop;
  late final int _seed;
  int _meltedAtCount = 0;
  bool _evaporating = false;
  bool _foxFound = false;
  FoxHideoutController? _foxCtrl;

  @override
  void initState() {
    super.initState();
    _seed = math.Random().nextInt(1 << 31);
    _melt = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      reverseDuration: const Duration(milliseconds: 500),
    )..addStatusListener(_onMeltStatus);
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addStatusListener(_onFadeStatus);
    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _foxPop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _foxCtrl = ref.read(foxHideoutProvider);
      _foxCtrl!.register(_seed); // 整張卡片也是可能的藏身處
    });
  }

  @override
  void dispose() {
    _foxCtrl?.unregister(_seed);
    _melt.dispose();
    _fade.dispose();
    _wiggle.dispose();
    _foxPop.dispose();
    super.dispose();
  }

  void _onFoxFound() {
    if (_foxFound) return;
    HapticFeedback.mediumImpact();
    setState(() => _foxFound = true);
    _foxPop.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      setState(() => _foxFound = false);
      ref.read(foxHideoutProvider).found();
    });
  }

  void _onMeltStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    HapticFeedback.mediumImpact();
    _evaporating = true;
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && _evaporating) _fade.forward();
    });
  }

  void _onFadeStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    setState(() {
      _meltedAtCount = ref.read(snowAccumulationProvider);
      _evaporating = false;
      _melt.reset();
      _fade.reset();
    });
  }

  void _maybeRefreeze() {
    if (!_evaporating && _melt.status != AnimationStatus.completed) {
      _melt.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child; // 積雪已移除，改用觸碰冰霜 ❄️
    final effect = ref.watch(moodThemeProvider).fallEffect;
    final snowy = effect == FallEffectType.snow;
    final seeking = effect == FallEffectType.leaves ||
        effect == FallEffectType.petals; // 秋找狐狸、春找彩蛋
    final count = ref.watch(snowAccumulationProvider);
    // 第 2 次下雪才開始積（第一場雪只是飄過）
    final level = snowy ? ((count - _meltedAtCount) - 1).clamp(0, 3) : 0;
    final foxState = ref.watch(foxHideoutProvider);
    final hiding = seeking && foxState.chosenSpot == _seed;
    final isEgg = effect == FallEffectType.petals;
    final eggAsset =
        'assets/images/mood_egg_${(foxState.salt % 4) + 1}.png';

    // 只有藏著狐狸的卡片才需要晃動 ticker
    if (hiding && !_foxFound) {
      if (!_wiggle.isAnimating) _wiggle.repeat();
    } else if (_wiggle.isAnimating) {
      _wiggle.stop();
      _wiggle.value = 0;
    }

    if (level == 0 && !hiding && !_foxFound) return widget.child;

    final thickness = 6.0 + (level + _extraLevel) * 3.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 卡片本體：狐狸躲在後面時，整張微微晃動 + 輕輕浮動
        if (hiding && !_foxFound)
          AnimatedBuilder(
            animation: _wiggle,
            builder: (context, child) {
              final t = _wiggle.value * math.pi * 2;
              return Transform.translate(
                offset: Offset(0, math.sin(t) * 1.6),
                child: Transform.rotate(
                  angle: math.sin(t) * 0.009,
                  child: child,
                ),
              );
            },
            child: widget.child,
          )
        else
          widget.child,
        // 狐狸在這張卡片後面：點整張卡片揭曉（這一下不會進入功能頁）
        if (hiding && !_foxFound)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onFoxFound,
              child: const SizedBox.expand(),
            ),
          ),
        // 被找到：從卡片後面蹦出來
        if (_foxFound)
          Positioned(
            top: -96,
            left: 18,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _foxPop, curve: Curves.elasticOut),
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    margin: const EdgeInsets.only(bottom: 4, left: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8B27D)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'u found me!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB4652F),
                      ),
                    ),
                  ),
                  Image.asset(
                    isEgg ? eggAsset : 'assets/images/mood_fox_hide.png',
                    width: isEgg ? 52 : 72,
                    errorBuilder: (_, __, ___) => Text(isEgg ? '🥚' : '🦊',
                        style: const TextStyle(fontSize: 40)),
                  ),
                ],
              ),
            ),
          ),
        if (level > 0)
        Positioned(
          // 高度給足，雪的隨機圓才不會超出容器被裁掉（右半消失的元兇）
          top: -thickness - 6,
          left: 0,
          right: 0,
          height: thickness * 2 + 24,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPressStart: (_) {
              if (!_evaporating) _melt.forward();
            },
            onLongPressEnd: (_) => _maybeRefreeze(),
            onLongPressCancel: _maybeRefreeze,
            child: AnimatedBuilder(
              animation: Listenable.merge([_melt, _fade]),
              builder: (context, _) => Opacity(
                opacity: 1 - _fade.value,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _SnowCapPainter(
                    thickness: thickness,
                    meltT: _melt.value,
                    inset: widget.cornerInset,
                    seed: _seed,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SnowCapPainter extends CustomPainter {
  _SnowCapPainter({
    required this.thickness,
    required this.meltT,
    required this.inset,
    required this.seed,
  });

  final double thickness;
  final double meltT;
  final double inset;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height - 4;
    final hEff = thickness * (1 - meltT * 0.55);
    final left = inset;
    final right = size.width - inset;
    if (right - left < 20) return;

    final fillColor = Color.lerp(
      const Color(0xFFFDFEFF),
      const Color(0x8C86C9F2),
      meltT,
    )!;
    final fill = Paint()..color = fillColor;

    final path = Path()
      ..addRRect(RRect.fromLTRBR(
        left,
        baseline - hEff * 0.5,
        right,
        baseline,
        Radius.circular(hEff * 0.4),
      ));
    final rng = math.Random(seed);
    double x = left + 10;
    while (x < right - 10) {
      final r = hEff * 0.42 + rng.nextDouble() * hEff * 0.45;
      path.addOval(Rect.fromCircle(
        center: Offset(x, baseline - hEff * 0.48),
        radius: r,
      ));
      x += r * 1.3 + 5;
    }
    canvas.drawPath(path, fill);

    if (meltT < 0.6) {
      final line = Paint()
        ..color = const Color(0xFFB8D6EA)
            .withValues(alpha: (0.6 - meltT).clamp(0.0, 1.0))
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
          Offset(left + 3, baseline), Offset(right - 3, baseline), line);
    }

    if (meltT > 0.55) {
      final dt = ((meltT - 0.55) / 0.45).clamp(0.0, 1.0);
      final drop = Paint()
        ..color = const Color(0x9973B9E8).withValues(alpha: 0.6 * dt);
      final dropRng = math.Random(seed + 7);
      for (int i = 0; i < 3; i++) {
        final dx = left + 14 + dropRng.nextDouble() * (right - left - 28);
        final dy = baseline + dt * (4 + dropRng.nextDouble() * 5);
        canvas.drawCircle(Offset(dx, dy), 1.8 + dropRng.nextDouble(), drop);
      }
    }
  }

  @override
  bool shouldRepaint(_SnowCapPainter old) =>
      old.meltT != meltT || old.thickness != thickness;
}
