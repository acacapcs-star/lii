import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_language.dart';
import '../../core/security/local_settings_service.dart';
import 'ers_models.dart';

class ERSPercentileWidget extends ConsumerWidget {
  final ERSResult ersResult;
  final String ageGroup;

  const ERSPercentileWidget({
    super.key,
    required this.ersResult,
    required this.ageGroup,
  });

  Color get _riskColor => switch (ersResult.riskLevel) {
    'red' => const Color(0xFFD14343),
    'yellow' => const Color(0xFFF5A623),
    _ => const Color(0xFF0ABFBC),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isZh = ref.watch(appLanguageControllerProvider) == AppLanguage.zhTw;
    final score = ersResult.adjustedERS;
    final percentile = _calculatePercentile(score);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _riskColor.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 膠囊要用 Flexible 包住：英文的「Doing Well」比中文長很多，
              // 沒限制的話它會撐開整條 Row，把右邊的 ERS 分數擠出卡片外
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _riskColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                    isZh
                        ? switch (ersResult.riskLevel) {
                            'red' => '⚠️ 需要關注',
                            'yellow' => '🔔 請多留意',
                            _ => '✅ 狀態良好',
                          }
                        : switch (ersResult.riskLevel) {
                            'red' => '⚠️ Attention',
                            'yellow' => '🔔 Take Care',
                            _ => '✅ Good',
                          },
                    maxLines: 1,
                    style: TextStyle(
                      color: _riskColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // FittedBox：空間不夠時整塊等比縮小，不會被切掉
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'ERS ${score.toStringAsFixed(0)}',
                    maxLines: 1,
                    style: TextStyle(
                      color: _riskColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(_riskColor),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isZh
                ? 'lii 正在認識你的日常，還在建立你的基準線'
                : 'lii is learning your normal — building a picture of you over time',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StreamBadge(isZh ? '語言' : 'Language',
                  ersResult.streamScores['language'] ?? 0, isZh: isZh),
              const SizedBox(width: 6),
              _StreamBadge(isZh ? '情緒' : 'Emotion',
                  ersResult.streamScores['physical'] ?? 0, isZh: isZh),
              const SizedBox(width: 6),
              _StreamBadge(isZh ? '生活節奏' : 'Routine',
                  ersResult.streamScores['behavior'] ?? 0, isZh: isZh),
            ],
          ),
        ],
      ),
    );
  }

  int _calculatePercentile(double score) {
    if (score >= 90) return 95;
    if (score >= 70) return 80;
    if (score >= 50) return 60;
    if (score >= 30) return 35;
    return 15;
  }
}

class _StreamBadge extends StatelessWidget {
  final String label;
  final double score;
  final bool isZh;

  const _StreamBadge(this.label, this.score, {this.isZh = true});

  Color get _color {
    if (score < 0) return const Color(0xFF9AA5B1);
    if (score >= 70) return const Color(0xFFD14343);
    if (score >= 45) return const Color(0xFFF5A623);
    return const Color(0xFF0ABFBC);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // 每格只有卡片寬的 1/3（約 100px），英文「Language」放不下會斷成
            // 兩行。用 FittedBox 讓它在放不下時自動縮字，維持一行。
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(color: _color, fontSize: 12),
                ),
              ),
            ),
            score < 0
                ? Text(
                    isZh ? '尚未紀錄' : 'not recorded yet',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                        color: _color,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        height: 1.1),
                  )
                : Text(
                    score.toStringAsFixed(0),
                    maxLines: 1,
                    style: TextStyle(
                        color: _color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
          ],
        ),
      ),
    );
  }
}
