import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_brand_icon.dart';
import 'mood_fall_overlay.dart';
import 'snow_cap.dart';
import '../theme/mood_theme_service.dart';
import '../security/local_settings_service.dart';
import '../../l10n/app_language.dart';

// 飄浮版品牌圖示：氣球般懸浮、底部有陰影、上方一條會左右擺動的繩子
// 長按可以跳出氛圍選單（雪花/楓葉/節慶主題...）
class FloatingAppBrandIcon extends ConsumerStatefulWidget {
  const FloatingAppBrandIcon({super.key, this.size = 66});

  final double size;

  @override
  ConsumerState<FloatingAppBrandIcon> createState() => _FloatingAppBrandIconState();
}

class _FloatingAppBrandIconState extends ConsumerState<FloatingAppBrandIcon>
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

  void _showMoodPicker() {
    final isZh = ref.read(appLanguageControllerProvider) == AppLanguage.zhTw;
    final currentMood = ref.read(moodThemeProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isZh ? '選擇氛圍' : 'Choose a Mood',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: MoodTheme.values.map((mood) {
                    final selected = mood == currentMood;
                    return GestureDetector(
                      onTap: () {
                        ref.read(moodThemeProvider.notifier).setMood(mood);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF0ABFBC).withValues(alpha: 0.15) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: selected ? const Color(0xFF0ABFBC) : Colors.grey.shade300,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          isZh ? mood.labelZh() : mood.labelEn(),
                          style: TextStyle(
                            fontSize: 13,
                            color: selected ? const Color(0xFF0ABFBC) : Colors.black87,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 點擊：依目前氛圍觸發一次飄落動畫（長按仍是氛圍選單）
      onTap: () {
        final effect = ref.read(moodThemeProvider).fallEffect;
        if (effect == FallEffectType.none) return; // 該氛圍還沒有效果
        HapticFeedback.lightImpact();
        ref.read(moodFallControllerProvider).play();
        if (effect == FallEffectType.snow) {
          // 下雪的同時，卡片上的積雪也變厚一級
          ref.read(snowAccumulationProvider.notifier).addSnow();
        }
      },
      onLongPress: _showMoodPicker,
      child: AnimatedBuilder(
        animation: Listenable.merge([_floatController, _swayController]),
        builder: (context, _) {
          // 上下飄浮：0~1 之間用 sin 曲線讓移動更自然（不是死板的線性來回）
          final floatT = _floatController.value; // 0→1→0（reverse）
          final floatOffset = -6.0 * floatT; // 最多往上飄 6px

          // 左右擺動：明顯的繩索晃動感（約 ±0.25 弧度，14度）
          final swayT = _swayController.value; // 0→1→0
          final swayAngle = (swayT - 0.5) * 0.5;

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
                // 圖示本體（連同飄浮位移、擺動角度）——幾乎跟著繩子一起擺，更有懸掛感
                Positioned(
                  top: 16 + floatOffset,
                  child: Transform.rotate(
                    angle: swayAngle * 0.85,
                    child: Image.asset('assets/images/lii_ball.png',
                        width: widget.size,
                        height: widget.size,
                        fit: BoxFit.contain),
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
      ),
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
