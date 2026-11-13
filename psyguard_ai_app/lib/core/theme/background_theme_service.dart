import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BgMode { light, dark }

enum BgColorChoice {
  blueLight, greenLight, pinkLight, rainbowLight,
  navyDark, forestDark, pureBlack,
  christmas, lunarNewYear, spring, summer, autumn, winter, winterBreak, summerBreak,
}

enum BgImage { none, night, sea, dawn }

extension BgImageAsset on BgImage {
  String? get asset => switch (this) {
        BgImage.none => null,
        BgImage.night => 'assets/images/bg/bg_night.png',
        BgImage.sea => 'assets/images/bg/bg_sea.png',
        BgImage.dawn => 'assets/images/bg/bg_dawn.png',
      };

  String label(bool zh) => switch (this) {
        BgImage.none => zh ? '不用圖片' : 'No image',
        BgImage.night => zh ? '夜空' : 'Night',
        BgImage.sea => zh ? '海面' : 'Sea',
        BgImage.dawn => zh ? '日出' : 'Dawn',
      };
}

class BackgroundThemeState {
  final BgMode mode;
  final BgColorChoice colorChoice;
  final BgImage image;

  const BackgroundThemeState({
    required this.mode,
    required this.colorChoice,
    this.image = BgImage.none,
  });

  /// 彩虹背景用漸層，其他回傳 null
  LinearGradient? get backgroundGradient => colorChoice == BgColorChoice.rainbowLight
      ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFB3B3), // 紅
            Color(0xFFE8B3FF), // 紫
            Color(0xFFB3CFFF), // 藍
          ],
        )
      : null;

  Color get backgroundColor => switch (colorChoice) {
    BgColorChoice.blueLight      => const Color(0xFFE3F2FD),
    BgColorChoice.greenLight     => const Color(0xFFE8F5E9),
    BgColorChoice.pinkLight      => const Color(0xFFFDF2F6),
    BgColorChoice.rainbowLight   => const Color(0xFFFBF4FA),
    BgColorChoice.pureBlack      => const Color(0xFF070707),
    BgColorChoice.navyDark       => const Color(0xFF16283C),
    BgColorChoice.forestDark     => const Color(0xFF2C2442),
    BgColorChoice.christmas      => const Color(0xFFFFFBF5),
    BgColorChoice.lunarNewYear   => const Color(0xFFFFF3F3),
    BgColorChoice.spring         => const Color(0xFFFCE4EC),
    BgColorChoice.summer         => const Color(0xFFE0F7FA),
    BgColorChoice.autumn         => const Color(0xFFFBE9E0),
    BgColorChoice.winter         => const Color(0xFFE8F0F7),
    BgColorChoice.winterBreak    => const Color(0xFFF3E9E0),
    BgColorChoice.summerBreak    => const Color(0xFFFFF3D6),
  };

  BackgroundThemeState copyWith({
    BgMode? mode,
    BgColorChoice? colorChoice,
    BgImage? image,
  }) {
    return BackgroundThemeState(
      mode: mode ?? this.mode,
      colorChoice: colorChoice ?? this.colorChoice,
      image: image ?? this.image,
    );
  }
}

class BackgroundThemeController extends StateNotifier<BackgroundThemeState> {
  static const _modeKey = 'bg_theme_mode';
  static const _imageKey = 'bg_image';
  static const _colorKey = 'bg_theme_color';

  BackgroundThemeController()
      : super(const BackgroundThemeState(
            mode: BgMode.light, colorChoice: BgColorChoice.blueLight)) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_modeKey);
    final colorStr = prefs.getString(_colorKey);

    final mode = modeStr == 'dark' ? BgMode.dark : BgMode.light;
    final colorChoice = BgColorChoice.values.firstWhere(
      (e) => e.name == colorStr,
      orElse: () => mode == BgMode.dark ? BgColorChoice.navyDark : BgColorChoice.blueLight,
    );

    final imgStr = prefs.getString(_imageKey);
    final img = BgImage.values.firstWhere(
      (e) => e.name == imgStr,
      orElse: () => BgImage.none,
    );

    state = BackgroundThemeState(mode: mode, colorChoice: colorChoice, image: img);
  }

  Future<void> toggleMode() async {
    final newMode = state.mode == BgMode.light ? BgMode.dark : BgMode.light;
    const toDark = {
      BgColorChoice.blueLight:    BgColorChoice.navyDark,
      BgColorChoice.greenLight:   BgColorChoice.navyDark,
      BgColorChoice.pinkLight:    BgColorChoice.forestDark,
      BgColorChoice.rainbowLight: BgColorChoice.pureBlack,
      BgColorChoice.spring:       BgColorChoice.forestDark,
      BgColorChoice.summer:       BgColorChoice.navyDark,
      BgColorChoice.autumn:       BgColorChoice.forestDark,
      BgColorChoice.winter:       BgColorChoice.navyDark,
      BgColorChoice.christmas:    BgColorChoice.navyDark,
      BgColorChoice.lunarNewYear: BgColorChoice.forestDark,
      BgColorChoice.winterBreak:  BgColorChoice.navyDark,
      BgColorChoice.summerBreak:  BgColorChoice.pureBlack,
    };
    const toLight = {
      BgColorChoice.navyDark:   BgColorChoice.blueLight,
      BgColorChoice.forestDark: BgColorChoice.pinkLight,
      BgColorChoice.pureBlack:  BgColorChoice.rainbowLight,
    };
    final newColor = newMode == BgMode.dark
        ? (toDark[state.colorChoice] ?? BgColorChoice.navyDark)
        : (toLight[state.colorChoice] ?? BgColorChoice.blueLight);
    state = state.copyWith(mode: newMode, colorChoice: newColor);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, newMode == BgMode.dark ? 'dark' : 'light');
    await prefs.setString(_colorKey, newColor.name);
  }

  Future<void> setImage(BgImage img) async {
    state = state.copyWith(image: img);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_imageKey, img.name);
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