// ═══════════════════════════════════════════════════════════
// Orb Spotlight Tutorial
// 進首頁第一次觸發，教用戶操作兩顆球
// ═══════════════════════════════════════════════════════════
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> showOrbTutorial(BuildContext context, {
  required bool zh,
  Offset brandCenter = const Offset(200, 100),
  Offset orbCenter = const Offset(330, 700),
}) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'orb_tutorial',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 500),
    transitionBuilder: (ctx, anim, _, child) =>
        FadeTransition(opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut), child: child),
    pageBuilder: (ctx, _, __) => _OrbTutorialPage(
        zh: zh, brandCenter: brandCenter, orbCenter: orbCenter),
  );
}

class _OrbTutorialPage extends StatefulWidget {
  final bool zh;
  final Offset brandCenter;
  final Offset orbCenter;
  const _OrbTutorialPage({required this.zh,
      required this.brandCenter, required this.orbCenter});
  @override
  State<_OrbTutorialPage> createState() => _OrbTutorialPageState();
}

class _OrbTutorialPageState extends State<_OrbTutorialPage>
    with TickerProviderStateMixin {
  int _step = 0;
  bool _tapped = false;
  bool _confirmed = false;

  late AnimationController _ripple1, _ripple2, _confirmAnim, _pulseAnim;

  @override
  void initState() {
    super.initState();
    _ripple1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _ripple2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _confirmAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _pulseAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ripple1.dispose(); _ripple2.dispose();
    _confirmAnim.dispose(); _pulseAnim.dispose();
    super.dispose();
  }

  void _reset() {
    _ripple1.reset(); _ripple2.reset(); _confirmAnim.reset();
    setState(() { _tapped = false; _confirmed = false; });
  }

  Future<void> _onTap() async {
    if (_tapped) return;
    if (_step == 1 || _step == 3) return;
    HapticFeedback.mediumImpact();
    setState(() => _tapped = true);
    _ripple1.forward();
    await Future.delayed(const Duration(milliseconds: 180));
    _ripple2.forward();
    await Future.delayed(const Duration(milliseconds: 650));
    setState(() => _confirmed = true);
    _confirmAnim.forward();
    await Future.delayed(const Duration(milliseconds: 900));
    _nextStep();
  }

  Future<void> _onLongPress() async {
    if (_tapped) return;
    if (_step == 0 || _step == 2) return;
    HapticFeedback.heavyImpact();
    setState(() => _tapped = true);
    _ripple1.forward();
    await Future.delayed(const Duration(milliseconds: 180));
    _ripple2.forward();
    await Future.delayed(const Duration(milliseconds: 650));
    setState(() => _confirmed = true);
    _confirmAnim.forward();
    await Future.delayed(const Duration(milliseconds: 900));
    _nextStep();
  }

  void _nextStep() {
    if (_step >= 3) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _reset();
    setState(() => _step++);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final zh = widget.zh;
    final topCenter = widget.brandCenter;
    final botCenter = widget.orbCenter;
    final isTopStep = _step <= 1;
    final center = isTopStep ? topCenter : botCenter;
    const orbR = 50.0;

    final List<Map<String, String>> steps = zh ? [
      {'icon': '👆', 'action': '短按', 'desc': '觸發當下氛圍的彩蛋效果', 'hint': '試試點一下球'},
      {'icon': '✋', 'action': '長按', 'desc': '打開氛圍選單，切換你喜歡的感覺', 'hint': '長按看看'},
      {'icon': '👆👆', 'action': '連點兩下', 'desc': '進入自由移動模式，把球拖到你想要的地方', 'hint': '快速點兩下'},
      {'icon': '✋', 'action': '長按', 'desc': '打開 Pacer 收藏，看你存的語錄', 'hint': '長按試試'},
    ] : [
      {'icon': '👆', 'action': 'Tap', 'desc': 'Trigger the current mood effect', 'hint': 'Try tapping the orb'},
      {'icon': '✋', 'action': 'Hold', 'desc': 'Open the mood menu to change the vibe', 'hint': 'Press and hold'},
      {'icon': '👆👆', 'action': 'Double tap', 'desc': 'Enter free-move mode, drag it anywhere', 'hint': 'Tap twice quickly'},
      {'icon': '✋', 'action': 'Hold', 'desc': 'Open your Pacer collection', 'hint': 'Press and hold'},
    ];

    final step = steps[_step];
    final bubbleTop = isTopStep ? center.dy + orbR + 20 : center.dy - 195.0;
    final bubbleLeft = (center.dx - 140).clamp(16.0, size.width - 296.0);

    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _SpotlightPainter(center: center, radius: orbR + 16),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => CustomPaint(
                painter: _PulsePainter(center: center, radius: orbR + 16,
                    progress: _pulseAnim.value, visible: !_tapped),
              ),
            ),
          ),
        ),
        if (_tapped)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([_ripple1, _ripple2]),
                builder: (_, __) => CustomPaint(
                  painter: _RipplePainter(center: center,
                      progress1: _ripple1.value, progress2: _ripple2.value),
                ),
              ),
            ),
          ),
        Positioned(
          left: center.dx - orbR - 8,
          top: center.dy - orbR - 8,
          width: (orbR + 8) * 2,
          height: (orbR + 8) * 2,
          child: GestureDetector(
            onTap: _onTap,
            onLongPress: _onLongPress,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        if (!_confirmed)
          Positioned(
            left: bubbleLeft,
            top: bubbleTop,
            width: 280,
            child: _TutorialBubble(
              icon: step['icon']!, action: step['action']!,
              desc: step['desc']!, hint: step['hint']!,
              isTop: isTopStep, targetX: center.dx, bubbleLeft: bubbleLeft,
            ),
          ),
        if (_confirmed)
          Positioned(
            left: center.dx - 60,
            top: center.dy - 24,
            child: FadeTransition(
              opacity: _confirmAnim,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.4), blurRadius: 16)],
                ),
                child: Text(zh ? '✓ 完成！' : '✓ Nice!',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ),
        Positioned(
          top: 52,
          right: 20,
          child: Row(
            children: List.generate(4, (i) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: i == _step ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _step ? Colors.white : Colors.white38,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )),
          ),
        ),
        Positioned(
          top: 48,
          left: 20,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(zh ? '跳過' : 'Skip',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _TutorialBubble extends StatelessWidget {
  final String icon, action, desc, hint;
  final bool isTop;
  final double targetX, bubbleLeft;
  const _TutorialBubble({required this.icon, required this.action,
      required this.desc, required this.hint, required this.isTop,
      required this.targetX, required this.bubbleLeft});

  @override
  Widget build(BuildContext context) {
    final arrowOffset = (targetX - bubbleLeft - 20).clamp(16.0, 240.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isTop) ...[
          Padding(padding: EdgeInsets.only(left: arrowOffset),
              child: const Icon(Icons.arrow_downward_rounded, color: Colors.white70, size: 24)),
          const SizedBox(height: 4),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Text(action, style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
              const SizedBox(height: 8),
              Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(hint, style: const TextStyle(
                    color: Colors.white60, fontSize: 12, fontStyle: FontStyle.italic)),
              ),
            ],
          ),
        ),
        if (isTop) ...[
          const SizedBox(height: 4),
          Padding(padding: EdgeInsets.only(left: arrowOffset),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white70, size: 24)),
        ],
      ],
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Offset center; final double radius;
  _SpotlightPainter({required this.center, required this.radius});
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.72));
    final grd = RadialGradient(colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
        stops: const [0.7, 1.0]);
    canvas.drawCircle(center, radius * 1.6,
        Paint()..shader = grd.createShader(Rect.fromCircle(center: center, radius: radius * 1.6)));
  }
  @override
  bool shouldRepaint(_SpotlightPainter o) => o.center != center || o.radius != radius;
}

class _PulsePainter extends CustomPainter {
  final Offset center; final double radius, progress; final bool visible;
  _PulsePainter({required this.center, required this.radius, required this.progress, required this.visible});
  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final r = radius + 8 + progress * 14;
    final alpha = (0.6 - progress * 0.6).clamp(0.0, 1.0);
    canvas.drawCircle(center, r, Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);
  }
  @override
  bool shouldRepaint(_PulsePainter o) => true;
}

class _RipplePainter extends CustomPainter {
  final Offset center; final double progress1, progress2;
  _RipplePainter({required this.center, required this.progress1, required this.progress2});
  void _draw(Canvas canvas, double p, Color c) {
    if (p <= 0) return;
    canvas.drawCircle(center, 50.0 + p * 90, Paint()
      ..color = c.withValues(alpha: (1.0 - p).clamp(0.0, 1.0) * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * (1 - p * 0.5));
  }
  @override
  void paint(Canvas canvas, Size size) {
    _draw(canvas, progress1, Colors.white);
    _draw(canvas, progress2, const Color(0xFFB3E5FC));
  }
  @override
  bool shouldRepaint(_RipplePainter o) => true;
}
