import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 深淺模式：使用者可以選擇 App 底色是深色或淺色主題
enum BgMode { light, dark }

// 淺色模式下可選的兩種顏色；深色模式下可選的兩種顏色
enum BgColorChoice { blueLight, greenLight, navyDark, forestDark }

class BackgroundThemeState {
  final BgMode mode;
  final BgColorChoice colorChoice;

  const BackgroundThemeState({required this.mode, required this.colorChoice});

  Color get backgroundColor {
    switch (colorChoice) {
      case BgColorChoice.blueLight:
        return const Color(0xFFE3F2FD);
      case BgColorChoice.greenLight:
        return const Color(0xFFE8F5E9);
      case BgColorChoice.navyDark:
        return const Color(0xFF16283C); // 帶藍的深色，像 logo 球球，不那麼黑
      case BgColorChoice.forestDark:
        return const Color(0xFF12261C); // 真正的深墨綠（原本誤植成深藍）
    }
  }

  BackgroundThemeState copyWith({BgMode? mode, BgColorChoice? colorChoice}) {
    return BackgroundThemeState(
      mode: mode ?? this.mode,
      colorChoice: colorChoice ?? this.colorChoice,
    );
  }
}

class BackgroundThemeController extends StateNotifier<BackgroundThemeState> {
  static const _modeKey = 'bg_theme_mode';
  static const _colorKey = 'bg_theme_color';

  BackgroundThemeController()
      : super(const BackgroundThemeState(mode: BgMode.light, colorChoice: BgColorChoice.blueLight)) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_modeKey);
    final colorStr = prefs.getString(_colorKey);

    final mode = modeStr == 'dark' ? BgMode.dark : BgMode.light;
    BgColorChoice colorChoice;
    switch (colorStr) {
      case 'greenLight':
        colorChoice = BgColorChoice.greenLight;
        break;
      case 'navyDark':
        colorChoice = BgColorChoice.navyDark;
        break;
      case 'forestDark':
        colorChoice = BgColorChoice.forestDark;
        break;
      default:
        colorChoice = mode == BgMode.dark ? BgColorChoice.navyDark : BgColorChoice.blueLight;
    }

    state = BackgroundThemeState(mode: mode, colorChoice: colorChoice);
  }

  Future<void> toggleMode() async {
    final newMode = state.mode == BgMode.light ? BgMode.dark : BgMode.light;
    final isGreen = state.colorChoice == BgColorChoice.greenLight ||
        state.colorChoice == BgColorChoice.forestDark;
    final newColor = newMode == BgMode.dark
        ? (isGreen ? BgColorChoice.forestDark : BgColorChoice.navyDark)
        : (isGreen ? BgColorChoice.greenLight : BgColorChoice.blueLight);
    state = state.copyWith(mode: newMode, colorChoice: newColor);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, newMode == BgMode.dark ? 'dark' : 'light');
    await prefs.setString(_colorKey, newColor.name);
  }

  Future<void> setColor(BgColorChoice choice) async {
    state = state.copyWith(colorChoice: choice);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_colorKey, choice.name);
  }
}

final backgroundThemeProvider =
    StateNotifierProvider<BackgroundThemeController, BackgroundThemeState>(
  (ref) => BackgroundThemeController(),
);
