import 'ers_models.dart';

class ERSEngine {
  // ── 串流一：語言訊號標準化（權重 40%）──────────────────
  
  // 語速標準化（字/分鐘）
  double normalizeSpeechRate(double rate) {
    if (rate < 150) return 90;      // 嚴重偏慢
    if (rate < 200) return 70;      // 偏慢
    if (rate < 250) return 40;      // 略慢
    if (rate <= 350) return 10;     // 正常
    if (rate <= 400) return 30;     // 略快
    return 60;                       // 焦慮性過快
  }

  // 負面詞彙密度標準化
  double normalizeNegativeWords(double ratio) {
    if (ratio <= 0.2) return 10;    // 正常
    if (ratio <= 0.4) return 35;    // 略高
    if (ratio <= 0.7) return 65;    // 警戒
    return 90;                       // 高風險
  }

  // 停頓頻率標準化（次/分鐘）
  double normalizePauseFrequency(double freq) {
    if (freq <= 2) return 10;       // 正常
    if (freq <= 5) return 35;       // 略多
    if (freq <= 8) return 65;       // 警戒
    return 85;                       // 高風險
  }

  // ── 串流二：生理訊號標準化（權重 35%）──────────────────

  // 情緒穩定度（Check-in的mood，0~100，分數越高越好）
  double normalizeMood(double mood) {
    if (mood >= 70) return 10;      // 良好
    if (mood >= 50) return 30;      // 普通
    if (mood >= 30) return 60;      // 不穩定
    return 85;                       // 高風險
  }

  // 心理負荷感（Check-in的stress，0~100，分數越低越好）
  double normalizeStress(double stress) {
    if (stress <= 30) return 10;    // 無負擔
    if (stress <= 50) return 30;    // 適中
    if (stress <= 70) return 60;    // 警戒
    return 85;                       // 超載風險
  }

  // 心理韌性值（Check-in的energy，0~100，分數越高越好）
  double normalizeEnergy(double energy) {
    if (energy >= 70) return 10;    // 強韌
    if (energy >= 50) return 30;    // 中等
    if (energy >= 30) return 60;    // 不足
    return 85;                       // 極度脆弱
  }

  // ── 串流三：行為訊號標準化（權重 25%）──────────────────

  // 睡眠時數標準化
  double normalizeSleep(double hours) {
    if (hours >= 7 && hours <= 9) return 10;  // 理想
    if (hours >= 6 && hours < 7) return 30;   // 略少
    if (hours >= 5 && hours < 6) return 60;   // 不足
    if (hours > 9) return 25;                  // 過多
    return 95;                                  // 嚴重不足
  }

  // 連續使用天數（越高越好）
  double normalizeStreak(double days) {
    if (days >= 7) return 10;       // 穩定
    if (days >= 4) return 30;       // 尚可
    if (days >= 2) return 55;       // 不穩定
    return 80;                       // 幾乎不用
  }

  // 打卡一致性（0~1）
  double normalizeConsistency(double consistency) {
    if (consistency >= 0.8) return 10;
    if (consistency >= 0.6) return 30;
    if (consistency >= 0.4) return 55;
    return 80;
  }

  // ── 加權融合計算 Raw ERS ──────────────────────────────

  ERSResult calculate(ERSInput input, PersonalBaseline baseline,
      {bool isZh = true, bool hasVoice = true}) {
    // 串流一：語言（40%）
    final stream1 = (
      normalizeSpeechRate(input.speechRate) * 0.4 +
      normalizeNegativeWords(input.negativeWordRatio) * 0.35 +
      normalizePauseFrequency(input.pauseFrequency) * 0.25
    );

    // 串流二：生理（35%）
    final stream2 = (
      normalizeMood(input.moodScore) * 0.4 +
      normalizeStress(input.stressScore) * 0.35 +
      normalizeEnergy(input.energyScore) * 0.25
    );

    // 串流三：行為（25%）
    // ROUTINE_REWEIGHT 睡眠是生理事實，打卡只是使用習慣，兩者不該等重。
    // 一天睡 2 小時的人，不該因為有乖乖打卡就被判定作息健康。
    final stream3 = (
      normalizeSleep(input.sleepDuration) * 0.7 +
      normalizeStreak(input.appUsageStreak) * 0.15 +
      normalizeConsistency(input.checkInConsistency) * 0.15
    );

    // 加權融合（沒有真實語音時，語言串流不列入，權重重新分配給生理+行為）
    final rawERS = hasVoice
        ? stream1 * 0.40 + stream2 * 0.35 + stream3 * 0.25
        : stream2 * (0.35 / 0.60) + stream3 * (0.25 / 0.60);

    // 個人基線校正
    final baselineMoodEffect = (50 - baseline.avgMood) * 0.1;
    final baselineStressEffect = (baseline.avgStress - 50) * 0.1;
    final adjustedERS = (rawERS + baselineMoodEffect + baselineStressEffect)
        .clamp(0.0, 100.0);

    // 判斷風險等級
    // 紅燈閾值：70分（三串流同時異常才會到達）
    final riskLevel = adjustedERS >= 70
        ? 'red'
        : adjustedERS >= 45
            ? 'yellow'
            : 'green';

    final riskLabel = switch (riskLevel) {
      'red' => isZh ? '⚠️ 需要關注' : '⚠️ Needs attention',
      'yellow' => isZh ? '🔔 請多留意' : '🔔 Keep an eye on it',
      _ => isZh ? '✅ 狀態良好' : '✅ Doing okay',
    };

    return ERSResult(
      rawERS: rawERS,
      adjustedERS: adjustedERS,
      riskLevel: riskLevel,
      riskLabel: riskLabel,
      streamScores: {
        'language': hasVoice ? stream1 : -1.0,
        'physical': stream2,
        'behavior': stream3,
      },
    );
  }
}
