import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mood_fall_overlay.dart';
import 'snow_cap.dart';
import '../theme/mood_theme_service.dart';
import '../theme/background_theme_service.dart';
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
    final currentBg = ref.read(backgroundThemeProvider).colorChoice;

    // 完整 15 種氛圍，與 welcome page 保持同步
    // (emoji, labelZh, labelEn, moodTheme?, bgColor?)
    const items = [
      ('🎄', '聖誕節', 'Christmas',   MoodTheme.christmas,  null),
      ('🧧', '過年',   'Lunar NY',    MoodTheme.newYear,    null),
      ('🌸', '春',     'Spring',      MoodTheme.spring,     null),
      ('☀️', '夏',     'Summer',      MoodTheme.summer,     null),
      ('🍂', '秋',     'Autumn',      MoodTheme.autumn,     null),
      ('❄️', '冬',     'Winter',      MoodTheme.winter,     null),
      ('⛷️', '寒假',   'Winter Hols', MoodTheme.winterBreak, null),
      ('🏖️', '暑假',   'Summer Hols', MoodTheme.summerBreak, null),
      ('💙', '藍光',   'Blue',        null, BgColorChoice.blueLight),
      ('💚', '綠光',   'Green',       null, BgColorChoice.greenLight),
      ('🌸', '粉光',   'Pink',        null, BgColorChoice.pinkLight),
      ('🌈', '彩虹',   'Rainbow',     null, BgColorChoice.rainbowLight),
      ('🌙', '深藍',   'Navy',        null, BgColorChoice.navyDark),
      ('🌲', '森林',   'Forest',      null, BgColorChoice.forestDark),
      ('⬛', '純黑',   'Black',       null, BgColorChoice.pureBlack),
    ];

    // tile 背景色（深色系，與 welcome page 同）
    const tileBgs = [
      Color(0xFF1A4A2A), // 聖誕節
      Color(0xFF5A1A1A), // 過年
      Color(0xFF6A3A5A), // 春
      Color(0xFF1A4A5A), // 夏
      Color(0xFF5A3A1A), // 秋
      Color(0xFF1A3A5A), // 冬
      Color(0xFF2A3A4A), // 寒假
      Color(0xFF4A3A1A), // 暑假
      Color(0xFF2A4A7A), // 藍光
      Color(0xFF2A5A3A), // 綠光
      Color(0xFF6A3A5A), // 粉光
      Color(0xFF4A3A6A), // 彩虹
      Color(0xFF0D1A3A), // 深藍
      Color(0xFF0D2A1A), // 森林
      Color(0xFF0D0D0D), // 純黑
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A2A4A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 拖曳把手
                  Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    isZh ? '選擇氛圍' : 'Choose a Mood',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: List.generate(items.length, (i) {
                        final (emoji, zh, en, mood, bgColor) = items[i];
                        final selected = mood != null
                            ? mood == currentMood
                            : bgColor != null && bgColor == currentBg && currentMood == MoodTheme.none;
                        return GestureDetector(
                          onTap: () {
                            if (mood != null) {
                              ref.read(moodThemeProvider.notifier).setMood(mood);
                            } else if (bgColor != null) {
                              ref.read(moodThemeProvider.notifier).setMood(MoodTheme.none);
                              ref.read(backgroundThemeProvider.notifier).setColor(bgColor);
                            }
                            Navigator.pop(ctx);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: tileBgs[i].withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.2),
                                width: selected ? 2.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(emoji, style: const TextStyle(fontSize: 22)),
                                const SizedBox(height: 3),
                                Text(
                                  isZh ? zh : en,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
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
