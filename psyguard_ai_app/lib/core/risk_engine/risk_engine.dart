import 'risk_models.dart';

class RiskEngine {
  // 注意：比對前 messages 會先 toLowerCase()，英文一律用小寫。
  static const _highRiskKeywords = [
    // 中文
    '想死',
    '不想活',
    '自殺',
    '割腕',
    '活不下去',
    '結束生命',
    '傷害自己',
    // English
    'want to die',
    'wanna die',
    'kill myself',
    'killing myself',
    'end my life',
    'take my own life',
    'suicide',
    'suicidal',
    'self harm',
    'self-harm',
    'hurt myself',
    'cut myself',
    'cutting myself',
    'better off dead',
    'end it all',
    'no reason to live',
    "don't want to live",
    'do not want to live',
  ];

  static const _distressKeywords = [
    // 中文
    '不想上學',
    '撐不下去',
    '沒希望',
    '很絕望',
    '沒有人懂我',
    '不想面對',
    // English
    "don't want to go to school",
    'do not want to go to school',
    'skip school',
    "can't keep going",
    'cannot keep going',
    "can't take it anymore",
    'hopeless',
    'no hope',
    'so desperate',
    'nobody understands me',
    'no one understands me',
    "don't want to face",
    'giving up on everything',
  ];

  static const _helpSeekingKeywords = [
    // 中文
    '想找老師',
    '想找輔導室',
    '我願意求助',
    '我想找人聊聊',
    '我需要幫助',
    // English
    'talk to a teacher',
    'talk to my teacher',
    'see the counselor',
    'see a counselor',
    'want to talk to someone',
    'need to talk to someone',
    'i need help',
    'i want help',
    'i need support',
    'reach out for help',
  ];

  RiskSnapshotResult evaluateCheckin({
    required int moodScore,
    required int stressScore,
    required int energyScore,
  }) {
    final mood = moodScore.clamp(0, 100);
    final stress = stressScore.clamp(0, 100);
    final energy = energyScore.clamp(0, 100);
    final reasons = <String>[];
    var score = 0;

    if (mood <= 25) {
      score += 35;
      reasons.add('當下心情明顯偏低');
    } else if (mood <= 45) {
      score += 20;
      reasons.add('當下心情偏低');
    } else if (mood <= 60) {
      score += 10;
      reasons.add('當下心情略低');
    }

    if (stress >= 75) {
      score += 35;
      reasons.add('當下壓力明顯偏高');
    } else if (stress >= 60) {
      score += 20;
      reasons.add('當下壓力偏高');
    } else if (stress >= 45) {
      score += 10;
      reasons.add('當下壓力略高');
    }

    if (energy <= 25) {
      score += 20;
      reasons.add('當下活力明顯偏低');
    } else if (energy <= 40) {
      score += 10;
      reasons.add('當下活力偏低');
    }

    if (mood <= 35 && stress >= 75) {
      score += 10;
      reasons.add('心情低落且壓力偏高');
    }

    if (mood <= 35 && energy <= 30) {
      score += 10;
      reasons.add('心情低落且活力偏低');
    }

    score = score.clamp(0, 100);

    final level = score >= 70
        ? RiskLevel.high
        : score >= 40
        ? RiskLevel.medium
        : RiskLevel.low;

    if (reasons.isEmpty) {
      reasons.add('當下狀態穩定');
    }

    return RiskSnapshotResult(
      riskLevel: level,
      riskScore: score,
      reasons: reasons,
    );
  }

  RiskSnapshotResult evaluateDay({
    required List<String> messages,
    required dynamic checkin,
    required List<dynamic> sleepLogs,
    required List<dynamic> toolUsage,
    required RiskEvaluationInput input,
  }) {
    final reasons = <String>[];
    var score = 20;

    final joined = messages.join(' ').toLowerCase();
    final immediateHigh = _highRiskKeywords.any((kw) => joined.contains(kw));
    if (immediateHigh) {
      reasons.add('偵測到高風險語句，啟動高風險保護流程');
      return RiskSnapshotResult(
        riskLevel: RiskLevel.high,
        riskScore: 92,
        reasons: reasons,
      );
    }

    if (input.moodScoresLast14d.isNotEmpty) {
      final avgMood =
          input.moodScoresLast14d.reduce((a, b) => a + b) /
          input.moodScoresLast14d.length;
      if (avgMood <= 25) {
        score += 30;
        reasons.add('近 14 天心情平均偏低');
      }
    }

    final hardSleepDays = input.sleepDifficultyLast7d
        .where((d) => d >= 2)
        .length;
    if (hardSleepDays >= 5) {
      score += 25;
      reasons.add('近 7 天睡眠困難天數偏高');
    }

    // SLEEP_DURATION 睡眠「時數」原本完全沒被算進來 ——
    // 只睡 2 小時但沒勾入睡困難的學生，這個引擎會看不到。
    // sleepLogs 早就傳進來了，這裡才真的讀它。
    try {
      final hours = <double>[];
      for (final s in sleepLogs) {
        final h = (s.sleepHours as num?)?.toDouble();
        if (h != null && h > 0) hours.add(h);
      }
      if (hours.isNotEmpty) {
        final avg = hours.reduce((a, b) => a + b) / hours.length;
        if (avg < 5) {
          score += 25;
          reasons.add('近 7 天睡眠時數明顯不足');
        } else if (avg < 6) {
          score += 12;
          reasons.add('近 7 天睡眠時數偏少');
        }
      }

      // 單一晚的極端狀況：又短又睡不著，兩個條件都要成立。
      // 只有其中一項的話，熬夜趕作業的人天天都會踩到。
      if (sleepLogs.isNotEmpty) {
        final last = sleepLogs.last;
        final lastHours = (last.sleepHours as num?)?.toDouble();
        final lastDifficulty = (last.difficulty as num?)?.toInt();
        if (lastHours != null &&
            lastHours < 4 &&
            lastDifficulty != null &&
            lastDifficulty >= 2) {
          score += 15;
          reasons.add('最近一晚幾乎沒睡');
        }
      }
    } catch (_) {
      // 欄位對不上就跳過這一段，不影響其他判斷。
    }

    final distressHits = _distressKeywords
        .where((kw) => joined.contains(kw))
        .length;
    if (distressHits >= 3) {
      score += 20;
      reasons.add('拒學/無助訊號持續上升');
    }

    if (input.moodScoresLast14d.length >= 7 &&
        input.moodScoresLast3d.length >= 2) {
      final avg14 =
          input.moodScoresLast14d.reduce((a, b) => a + b) /
          input.moodScoresLast14d.length;
      final avg3 =
          input.moodScoresLast3d.reduce((a, b) => a + b) /
          input.moodScoresLast3d.length;
      if (avg3 + 20 <= avg14) {
        score += 10;
        reasons.add('近期 3 天情緒趨勢較 14 天平均惡化');
      }
    }

    final completedTools = input.completedToolsLast7d.where((v) => v).length;
    if (completedTools >= 3) {
      score -= 10;
      reasons.add('近期有持續完成自助工具，提供保護因子');
    }

    final helpSeeking = _helpSeekingKeywords.any((kw) => joined.contains(kw));
    if (helpSeeking) {
      score -= 10;
      reasons.add('訊息中出現求助意願，降低風險評分');
    }

    if (input.sleepDifficultyLast7d.length >= 3) {
      final last3 =
          input.sleepDifficultyLast7d
              .sublist(input.sleepDifficultyLast7d.length - 3)
              .reduce((a, b) => a + b) /
          3;
      if (last3 <= 1) {
        score -= 5;
        reasons.add('睡眠困難近期有回穩跡象');
      }
    }

    score = score.clamp(0, 100);

    final level = score >= 70
        ? RiskLevel.high
        : score >= 40
        ? RiskLevel.medium
        : RiskLevel.low;

    if (reasons.isEmpty) {
      reasons.add('目前指標穩定，建議持續每日檢視');
    }

    return RiskSnapshotResult(
      riskLevel: level,
      riskScore: score,
      reasons: reasons,
    );
  }
}
