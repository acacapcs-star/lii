import 'package:flutter_test/flutter_test.dart';
import 'package:psyguard_ai_app/features/ers/ers_engine.dart';
import 'package:psyguard_ai_app/features/ers/ers_models.dart';

// 原本放在 lib/features/ers/ers_test.dart，用 print 印出三個情境。
// 放在 lib/ 會被打包進 App，而且印出來的東西沒人會檢查。
// 搬到這裡改成真的測試：三個情境各自該落在哪一燈，由 expect 把關。
void main() {
  final engine = ERSEngine();
  const baseline = PersonalBaseline(
    avgMood: 60,
    avgStress: 40,
    avgEnergy: 65,
    avgSleepDuration: 7.5,
    sampleCount: 14,
  );

  test('a steady day is green', () {
    final r = engine.calculate(
      const ERSInput(
        speechRate: 300,
        negativeWordRatio: 0.1,
        pauseFrequency: 1,
        moodScore: 80,
        stressScore: 20,
        energyScore: 75,
        sleepDuration: 8,
        appUsageStreak: 10,
        checkInConsistency: 0.9,
      ),
      baseline,
    );
    expect(r.riskLevel, 'green');
    expect(r.adjustedERS, lessThan(45));
  });

  test('a strained day is yellow', () {
    final r = engine.calculate(
      const ERSInput(
        speechRate: 200,
        negativeWordRatio: 0.45,
        pauseFrequency: 5,
        moodScore: 45,
        stressScore: 60,
        energyScore: 40,
        sleepDuration: 5.5,
        appUsageStreak: 3,
        checkInConsistency: 0.5,
      ),
      baseline,
    );
    expect(r.riskLevel, 'yellow');
    expect(r.adjustedERS, inInclusiveRange(45, 69.99));
  });

  test('all three streams in distress is red', () {
    final r = engine.calculate(
      const ERSInput(
        speechRate: 130,
        negativeWordRatio: 0.8,
        pauseFrequency: 10,
        moodScore: 15,
        stressScore: 85,
        energyScore: 10,
        sleepDuration: 3,
        appUsageStreak: 0,
        checkInConsistency: 0.1,
      ),
      baseline,
    );
    expect(r.riskLevel, 'red');
    expect(r.adjustedERS, greaterThanOrEqualTo(70));
  });
}
