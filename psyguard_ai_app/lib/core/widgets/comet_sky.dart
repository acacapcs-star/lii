/// Drawer 頂部的彗星夜空，星星可以點。
///
/// ── 為什麼夜空固定深藍，不跟著主題走 ───────────────────
///
/// 那塊區域的意義是「一片天空」。使用者選了淺色主題，
/// 不代表他想把天空換成白天——而且彗星在淺色背景上根本看不見。
///
/// 所以夜空是固定的，任何主題下都成立。
///
/// ── 亮星為什麼只有幾顆 ─────────────────────────────────
///
/// 四十顆星全部能點的話，使用者會一直點，那就變成一個遊戲。
/// 只有三到五顆會脈動、有光芒的亮星能點，那些才像「藏在天上的東西」。
///
/// 數量是 min(卡片數, 5)——沒有卡片就沒有亮星，
/// 不要給一顆點了說「你還沒有格言卡」的星星。
///
/// ── 殘影是點不是線 ─────────────────────────────────────
///
/// 畫一串逐漸縮小變淡的圓點，不是漸層的線條。
/// 線條看起來像雷射；點串起來才有粒子感，尾端也會自然散開。
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../features/card_studio/presentation/my_cards_store.dart';

class CometSky extends StatefulWidget {
  const CometSky({
    super.key,
    this.child,
    this.starCount = 40,
  });

  /// 疊在星空上面的東西（例如「Luna」那行字）
  final Widget? child;

  final int starCount;

  @override
  State<CometSky> createState() => _CometSkyState();
}

class _CometSkyState extends State<CometSky>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// 背景的星點。位置和相位在 initState 決定，之後不再變——
  /// 每次重建都重算的話，星星會在畫面上跳來跳去。
  late final List<_Star> _stars;

  /// 可以點的那幾顆
  List<_BrightStar> _bright = [];

  /// 極光的光帶
  late final List<_AuroraBand> _aurora;

  /// 目前這一顆彗星。null 表示現在是空檔。
  _Comet? _comet;

  /// 現在正在顯示的那句話
  String? _quote;
  String? _quoteAuthor;
  int? _quoteStar;

  final _rnd = math.Random();

  @override
  void initState() {
    super.initState();

    // 星星不是平均散布的。
    //
    // 純隨機看起來像雜訊——真的星空有疏有密，成團成帶。
    // 所以先挑四個中心，多數星星圍著它們生成，
    // 剩下的才隨機散落填空。
    final centers = List.generate(
      4,
      (_) => Offset(0.12 + _rnd.nextDouble() * 0.76,
                    0.12 + _rnd.nextDouble() * 0.76),
    );

    _stars = List.generate(widget.starCount, (i) {
      double x, y;
      if (i % 4 != 0) {
        final c = centers[_rnd.nextInt(centers.length)];
        x = (c.dx + _gauss() * 0.16).clamp(0.02, 0.98);
        y = (c.dy + _gauss() * 0.16).clamp(0.02, 0.98);
      } else {
        x = _rnd.nextDouble();
        y = _rnd.nextDouble();
      }

      // 平方讓小星星佔多數——那才像真的天空
      final t = _rnd.nextDouble();
      final r = 0.7 + t * t * 2.1;

      return _Star(
        x: x,
        y: y,
        r: r,
        phase: _rnd.nextDouble() * math.pi * 2,
        speed: 0.5 + _rnd.nextDouble() * 0.55,
        color: _starColor(),
      );
    });

    // 極光：兩條扁平的橫帶，掛在上半部。
    //
    // 顏色用藍——綠色的極光在這個夜空上太搶眼。
    final auroraColors = [
      const Color(0xFF5BA8E0),   // 天藍
      const Color(0xFF6FC4E8),   // 淺藍偏青
      const Color(0xFF7C9FE0),   // 藍偏紫
    ];
    _aurora = List.generate(2, (i) {
      return _AuroraBand(
        y: 0.18 + _rnd.nextDouble() * 0.26,
        thickness: 0.09 + _rnd.nextDouble() * 0.07,
        color: auroraColors[i % auroraColors.length],
        phase: _rnd.nextDouble() * math.pi * 2,
        speed: 0.12 + _rnd.nextDouble() * 0.12,
        // 起伏壓很小——那樣才是一排橫的，不是翻滾的
        waveAmp: 0.008 + _rnd.nextDouble() * 0.010,
        waveFreq: 1.4 + _rnd.nextDouble() * 1.6,
      );
    });

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    _ctrl.addListener(_tick);
    _scheduleComet(first: true);
    _loadCards();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_tick);
    _ctrl.dispose();
    super.dispose();
  }

  /// 載入 Pacer 卡，挑幾顆星當亮星。
  Future<void> _loadCards() async {
    List<MyCard> cards;
    try {
      cards = await MyCardsStore.load();
    } catch (_) {
      return;   // 讀不到就沒有亮星，夜空照常運作
    }
    if (!mounted || cards.isEmpty) return;

    // 最多五顆。太多的話整片天空都能點，
    // 那就失去「找到藏起來的東西」的感覺了。
    final n = cards.length < 5 ? cards.length : 5;
    final picked = <_BrightStar>[];
    final used = <int>{};

    for (int i = 0; i < n; i++) {
      // 從背景星裡挑，但避開太靠邊的位置——點不到
      int idx;
      int guard = 0;
      do {
        idx = _rnd.nextInt(_stars.length);
        guard++;
      } while ((used.contains(idx) ||
              _stars[idx].x < 0.12 ||
              _stars[idx].x > 0.88 ||
              _stars[idx].y < 0.18 ||
              _stars[idx].y > 0.82) &&
          guard < 60);
      used.add(idx);
      picked.add(_BrightStar(
        star: _stars[idx],
        card: cards[i],
        phase: _rnd.nextDouble() * math.pi * 2,
      ));
    }

    setState(() => _bright = picked);
  }

  /// 近似高斯分布。兩個均勻亂數相加就夠接近了。
  double _gauss() => (_rnd.nextDouble() + _rnd.nextDouble() - 1.0);

  /// 星星的色溫。七成偏冷白，兩成中性，一成偏暖。
  Color _starColor() {
    final t = _rnd.nextDouble();
    if (t < 0.70) return const Color(0xFFDCE8FF);
    if (t < 0.90) return const Color(0xFFFFFFFF);
    return const Color(0xFFFFE3C2);
  }

  double _lastT = 0;

  void _tick() {
    final t = _ctrl.value * 60;   // 換算成秒
    final dt = t - _lastT;
    _lastT = t;
    // repeat 繞回去時 dt 會是負的，跳過那一幀
    if (dt <= 0 || dt > 0.2) return;

    final c = _comet;
    if (c != null) {
      c.progress += dt / c.duration;
      if (c.progress >= 1.0) {
        _comet = null;
        _scheduleComet();
      }
    }
    if (mounted) setState(() {});
  }

  /// 排下一顆彗星。間隔三到六秒隨機——固定間隔會有機械感。
  void _scheduleComet({bool first = false}) {
    final wait = first
        ? 1.2 + _rnd.nextDouble() * 2
        : 3.0 + _rnd.nextDouble() * 3;
    Future.delayed(Duration(milliseconds: (wait * 1000).round()), () {
      if (!mounted) return;
      setState(() {
        _comet = _Comet(
          startX: 0.75 + _rnd.nextDouble() * 0.45,
          startY: -0.12 - _rnd.nextDouble() * 0.15,
          dx: -0.85 - _rnd.nextDouble() * 0.35,
          dy: 0.62 + _rnd.nextDouble() * 0.25,
          duration: 0.85 + _rnd.nextDouble() * 0.4,
        );
      });
    });
  }

  /// 點在哪裡。找最近的亮星，超過門檻就當作沒點到。
  void _handleTap(TapUpDetails d, Size size) {
    if (_bright.isEmpty) return;

    final p = d.localPosition;
    double best = double.infinity;
    int bestIdx = -1;

    for (int i = 0; i < _bright.length; i++) {
      final s = _bright[i].star;
      final dx = s.x * size.width - p.dx;
      final dy = s.y * size.height - p.dy;
      final dist = dx * dx + dy * dy;
      if (dist < best) {
        best = dist;
        bestIdx = i;
      }
    }

    // 32px 的觸控半徑。星星本身只有幾 px，
    // 照實際大小算的話根本點不到。
    if (best > 32 * 32 || bestIdx < 0) {
      // 點在空處 = 收起現在這句
      if (_quote != null) setState(() => _quote = null);
      return;
    }

    final b = _bright[bestIdx];
    setState(() {
      // 點同一顆 = 收起
      if (_quoteStar == bestIdx && _quote != null) {
        _quote = null;
        _quoteStar = null;
      } else {
        _quote = b.card.text;
        _quoteAuthor = b.card.author;
        _quoteStar = bestIdx;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return GestureDetector(
          onTapUp: (d) => _handleTap(d, size),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 夜空的底色。固定的——那塊區域是一片天空，
              // 不該因為使用者選了淺色主題就變成白天。
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color(0xFF060D1F),
                      Color(0xFF0D2340),
                      Color(0xFF143D54),
                    ],
                  ),
                ),
              ),
              // 星星和彗星
              Positioned.fill(
                child: CustomPaint(
                  painter: _SkyPainter(
                    stars: _stars,
                    aurora: _aurora,
                    bright: _bright,
                    comet: _comet,
                    time: _ctrl.value * 60,
                    activeStar: _quoteStar,
                  ),
                ),
              ),
              // 點出來的那句話
              if (_quote != null)
                Positioned(
                  left: 14,
                  right: 14,
                  top: 12,
                  child: _quoteCard(),
                ),
              if (widget.child != null) widget.child!,
            ],
          ),
        );
      },
    );
  }

  Widget _quoteCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _quote ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Colors.white,
            ),
          ),
          if ((_quoteAuthor ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '— ${_quoteAuthor!}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  資料
// ══════════════════════════════════════════════════════

class _Star {
  _Star({
    required this.x,
    required this.y,
    required this.r,
    required this.phase,
    required this.speed,
    required this.color,
  });

  /// 0 到 1 的相對位置
  final double x, y;
  final double r;
  final double phase;
  final double speed;

  /// 星星的色溫。
  ///
  /// 純白的點看起來像雜訊。真的星空裡星星有顏色——
  /// 多數偏冷白，少數偏暖偏橙，那個差異才讓它像天空。
  final Color color;
}

/// 可以點的星星，綁著一張 Pacer 卡
class _BrightStar {
  _BrightStar({
    required this.star,
    required this.card,
    required this.phase,
  });

  final _Star star;
  final MyCard card;
  final double phase;
}

/// 一條極光光幕。
///
/// 極光是橫掛在天上的光簾，不是垂直的光柱——
/// 垂直加上下淡的漸層就變成聚光燈了。
class _AuroraBand {
  _AuroraBand({
    required this.y,
    required this.thickness,
    required this.color,
    required this.phase,
    required this.speed,
    required this.waveAmp,
    required this.waveFreq,
  });

  /// 掛在畫面的哪個高度（0 到 1）
  final double y;

  /// 厚度，佔畫面高度的比例
  final double thickness;

  final Color color;

  /// 波動的相位，錯開才不會幾條一起晃
  final double phase;
  final double speed;

  /// 起伏的幅度與頻率
  final double waveAmp;
  final double waveFreq;
}

class _Comet {
  _Comet({
    required this.startX,
    required this.startY,
    required this.dx,
    required this.dy,
    required this.duration,
  });

  final double startX, startY;
  final double dx, dy;
  final double duration;

  /// 0 到 1，走到哪了
  double progress = 0;
}

// ══════════════════════════════════════════════════════
//  繪製
// ══════════════════════════════════════════════════════

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.stars,
    required this.aurora,
    required this.bright,
    required this.comet,
    required this.time,
    required this.activeStar,
  });

  final List<_Star> stars;
  final List<_AuroraBand> aurora;
  final List<_BrightStar> bright;
  final _Comet? comet;
  final double time;
  final int? activeStar;

  /// 拖尾畫幾顆點
  static const _tailDots = 12;

  @override
  void paint(Canvas canvas, Size size) {
    // 順序就是圖層：極光在最後面，星星穿過它，彗星在最前面
    _paintAurora(canvas, size);
    _paintStars(canvas, size);
    _paintBright(canvas, size);
    if (comet != null) _paintComet(canvas, size, comet!);
  }


  /// 畫極光。
  ///
  /// 下緣是鋸齒狀的——那是極光最好認的特徵。
  /// 真實的極光下緣是一道道垂直的褶皺，像布簾被風吹出來的皺褶。
  ///
  /// 跟聚光燈的差別在漸層方向：聚光燈上濃下淡（光源在上），
  /// 極光相反——下緣有明確的輪廓，上緣散進夜空。
  void _paintAurora(Canvas canvas, Size size) {
    const spikes = 22;

    for (final b in aurora) {
      final path = Path();
      final baseY = b.y * size.height;
      final th = b.thickness * size.height;

      double waveAt(double t) {
        return math.sin(t * b.waveFreq * math.pi * 2 +
                    time * b.speed + b.phase) *
                b.waveAmp +
            math.sin(t * b.waveFreq * 2.7 * math.pi * 2 +
                    time * b.speed * 0.7) *
                b.waveAmp *
                0.4;
      }

      // 上緣：平滑，散進夜空
      for (int i = 0; i <= spikes; i++) {
        final t = i / spikes;
        final x = t * size.width;
        final y = baseY + waveAt(t) * size.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      // 下緣：鋸齒，從右往左走回來
      for (int i = spikes; i >= 0; i--) {
        final t = i / spikes;
        final x = t * size.width;
        final topY = baseY + waveAt(t) * size.height;

        // 用索引當種子，同一個尖角每幀都一樣長。
        // 乘數要小——太大在 web 上會超過安全整數範圍。
        final seed = ((i * 7919) % 1000) / 1000.0;
        final seed2 = ((i * 40503 + 17) % 1000) / 1000.0;

        // 長短交錯，那個節奏讓它像褶皺不像鋸子
        final lenFactor =
            (i % 2 == 0) ? 0.75 + seed * 0.55 : 0.35 + seed2 * 0.35;
        final envelope = 0.6 + 0.4 * math.sin(t * 2.6 + b.phase);

        path.lineTo(x, topY + th * lenFactor * envelope);
      }
      path.close();

      final rect = Rect.fromLTWH(0, baseY - th * 0.2, size.width, th * 1.9);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            b.color.withValues(alpha: 0.0),
            b.color.withValues(alpha: 0.07),
            b.color.withValues(alpha: 0.13),
            b.color.withValues(alpha: 0.02),
          ],
          stops: const [0.0, 0.30, 0.72, 1.0],
        ).createShader(rect)
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, th * 0.16);

      canvas.drawPath(path, paint);
    }
  }

  void _paintStars(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;

    for (final s in stars) {
      // 每顆星用自己的相位和週期明滅，所以不會同步
      final breath = 0.5 + 0.5 * math.sin(time * s.speed + s.phase);
      final alpha = 0.38 + breath * 0.52;

      final c = Offset(s.x * size.width, s.y * size.height);

      // 用星星自己的色溫，不是純白
      p.color = s.color.withValues(alpha: alpha);
      canvas.drawCircle(c, s.r, p);

      // 比較大的星星：光暈加四道很短的光芒。
      // 光芒要短——長了就變成裝飾圖案。
      if (s.r > 1.7) {
        p.color = s.color.withValues(alpha: alpha * 0.13);
        canvas.drawCircle(c, s.r * 3.0, p);

        final ray = Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 0.7
          ..color = s.color.withValues(alpha: alpha * 0.42);
        final len = s.r * 2.6;
        canvas.drawLine(c.translate(-len, 0), c.translate(len, 0), ray);
        canvas.drawLine(c.translate(0, -len), c.translate(0, len), ray);
      }
    }
  }

  /// 亮星：比一般星星大，有脈動的光暈，四道星芒。
  ///
  /// 那四道光芒是「這顆可以點」的訊號——
  /// 光靠大小和亮度不夠，使用者分不出哪顆特別。
  void _paintBright(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < bright.length; i++) {
      final b = bright[i];
      final c = Offset(b.star.x * size.width, b.star.y * size.height);
      final isActive = activeStar == i;

      // 脈動
      final pulse = 0.5 + 0.5 * math.sin(time * 1.15 + b.phase);
      final scale = isActive ? 1.35 : 1.0;
      final base = (2.3 + pulse * 0.9) * scale;

      // 外層光暈
      p.color = Colors.white.withValues(alpha: (0.10 + pulse * 0.10) * scale);
      canvas.drawCircle(c, base * 4.2, p);

      p.color = Colors.white.withValues(alpha: (0.22 + pulse * 0.16) * scale);
      canvas.drawCircle(c, base * 2.1, p);

      // 核心
      p.color = Colors.white.withValues(alpha: 0.96);
      canvas.drawCircle(c, base, p);

      // 四道星芒
      final rayLen = base * (4.5 + pulse * 1.6);
      final rayPaint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: 0.30 + pulse * 0.22);

      canvas.drawLine(c.translate(-rayLen, 0), c.translate(rayLen, 0), rayPaint);
      canvas.drawLine(c.translate(0, -rayLen), c.translate(0, rayLen), rayPaint);

      // 斜的兩道短一點，那樣才像星芒不像十字
      final d = rayLen * 0.52;
      rayPaint.color = Colors.white.withValues(alpha: 0.16 + pulse * 0.12);
      canvas.drawLine(c.translate(-d, -d), c.translate(d, d), rayPaint);
      canvas.drawLine(c.translate(-d, d), c.translate(d, -d), rayPaint);
    }
  }

  void _paintComet(Canvas canvas, Size size, _Comet c) {
    final p = Paint()..style = PaintingStyle.fill;

    // 進場和退場都淡入淡出，不要突然出現又突然消失
    final fade = c.progress < 0.12
        ? c.progress / 0.12
        : (c.progress > 0.82 ? (1 - c.progress) / 0.18 : 1.0);

    final hx = (c.startX + c.dx * c.progress) * size.width;
    final hy = (c.startY + c.dy * c.progress) * size.height;

    // 拖尾：往回畫一串點，越後面越小越淡。
    // 尾巴的長度跟畫面大小有關，不是寫死的像素——
    // 不然在平板上會顯得太短。
    final tailLen = size.width * 0.16;
    final ux = -c.dx, uy = -c.dy;
    final norm = math.sqrt(ux * ux + uy * uy);

    for (int i = _tailDots; i >= 1; i--) {
      final f = i / _tailDots;           // 1 = 尾端，接近 0 = 靠近頭部
      final dist = tailLen * f;
      final x = hx + ux / norm * dist;
      final y = hy + uy / norm * dist;

      final a = (1 - f) * (1 - f) * 0.85 * fade;
      final r = 2.4 * (1 - f * 0.78);

      p.color = Colors.white.withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), r, p);
    }

    // 頭部：核心加兩層光暈
    p.color = Colors.white.withValues(alpha: 0.14 * fade);
    canvas.drawCircle(Offset(hx, hy), 9, p);

    p.color = Colors.white.withValues(alpha: 0.34 * fade);
    canvas.drawCircle(Offset(hx, hy), 4.6, p);

    p.color = Colors.white.withValues(alpha: 0.95 * fade);
    canvas.drawCircle(Offset(hx, hy), 2.2, p);
  }

  @override
  bool shouldRepaint(_SkyPainter old) => true;
}
