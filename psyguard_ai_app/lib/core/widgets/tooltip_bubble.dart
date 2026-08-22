import 'dart:ui';

import 'package:flutter/material.dart';

/// 長按氣泡元件 – 半透明氣泡 + 背景模糊
///
/// 用法：呼叫 [showFeatureTooltip] 即可在背景模糊的
/// overlay 上顯示功能說明氣泡。
Future<void> showFeatureTooltip(
  BuildContext context, {
  required String title,
  required String description,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'tooltip_dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _TooltipOverlay(
        title: title,
        description: description,
        animation: animation,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return child;
    },
  );
}

class _TooltipOverlay extends StatelessWidget {
  const _TooltipOverlay({
    required this.title,
    required this.description,
    required this.animation,
  });

  final String title;
  final String description;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 6.0 * animation.value,
              sigmaY: 6.0 * animation.value,
            ),
            child: Container(
              color: Colors.black.withValues(alpha: 0.15 * animation.value),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                  child: _bubbleContent(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _bubbleContent(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Color(0xFF718096),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              (RegExp(r'[\u4e00-\u9fff]').hasMatch(description) ? '點擊任意處關閉' : 'Tap anywhere to close'),
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFFA0AEC0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AnimatedBuilder 是 AnimatedWidget 的替代方案
class AnimatedBuilder extends AnimatedWidget {
  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
  }) : super(listenable: animation);

  final Widget Function(BuildContext context, Widget? child) builder;

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}
