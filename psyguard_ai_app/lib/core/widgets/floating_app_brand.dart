import 'package:flutter/material.dart';
import 'app_brand_icon.dart';

// 飄浮版品牌圖示：氣球般懸浮、底部有陰影、上方一條會左右擺動的繩子
class FloatingAppBrandIcon extends StatefulWidget {
  const FloatingAppBrandIcon({super.key, this.size = 66});

  final double size;

  @override
  State<FloatingAppBrandIcon> createState() => _FloatingAppBrandIconState();
}

class _FloatingAppBrandIconState extends State<FloatingAppBrandIcon>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _swayController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    _swayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatController, _swayController]),
      builder: (context, _) {
        // 上下飄浮：0~1 之間用 sin 曲線讓移動更自然（不是死板的線性來回）
        final floatT = _floatController.value; // 0→1→0（reverse）
        final floatOffset = -6.0 * floatT; // 最多往上飄 6px

        // 左右擺動：繩子跟著圖示一起輕微搖擺，角度小幅度變化
        final swayT = _swayController.value; // 0→1→0
        final swayAngle = (swayT - 0.5) * 0.12; // 約 ±0.06 弧度，很輕微

        // 陰影：飄得越高，陰影越小越淡（模擬遠近感）
        final shadowScale = 1.0 - floatT * 0.35;
        final shadowOpacity = 0.18 - floatT * 0.08;

        return SizedBox(
          width: widget.size + 20,
          height: widget.size + 34,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              // 繩子：從上方固定點，畫一條微彎、會擺動的線到圖示頂端
              Positioned(
                top: 0,
                child: Transform.rotate(
                  angle: swayAngle,
                  alignment: Alignment.topCenter,
                  child: CustomPaint(
                    size: Size(4, 16 + floatOffset.abs()),
                    painter: _RopePainter(),
                  ),
                ),
              ),
              // 圖示本體（連同飄浮位移、擺動角度）
              Positioned(
                top: 16 + floatOffset,
                child: Transform.rotate(
                  angle: swayAngle * 0.5, // 圖示本身擺動幅度比繩子小一點，更有重量感
                  child: AppBrandIcon(size: widget.size, padding: 0),
                ),
              ),
              // 底部陰影，飄浮時跟著縮小變淡
              Positioned(
                bottom: 0,
                child: Transform.scale(
                  scale: shadowScale,
                  child: Container(
                    width: widget.size * 0.7,
                    height: widget.size * 0.16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: shadowOpacity),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RopePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBFAF9A)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..quadraticBezierTo(
        size.width / 2 + 2, size.height / 2,
        size.width / 2, size.height,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
