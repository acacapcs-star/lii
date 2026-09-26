import 'package:flutter_test/flutter_test.dart';
import 'package:psyguard_ai_app/core/pacer/breath_plan.dart';
import 'package:psyguard_ai_app/core/widgets/lii_breath_entry.dart';
import 'package:psyguard_ai_app/core/widgets/lii_breath_page.dart';

void main() {
  test('breathing mode uses the ERS bands 0-44 / 45-69 / 70+', () {
    expect(liiModeFromErs(44), LiiBreathMode.daily);
    expect(liiModeFromErs(45), LiiBreathMode.checkIn);
    expect(liiModeFromErs(69), LiiBreathMode.checkIn);
    expect(liiModeFromErs(70), LiiBreathMode.safety);
  });

  test('breathing rhythm uses the same bands', () {
    expect(liiMoodFromErs(44), BreathMood.calm);
    expect(liiMoodFromErs(45), BreathMood.low);
    expect(liiMoodFromErs(69), BreathMood.low);
    expect(liiMoodFromErs(70), BreathMood.anxious);
  });
}
