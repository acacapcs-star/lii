import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 深淺模式：使用者可以選擇 App 底色是深色或淺色主題
enum BgMode { light, dark }

// 淺色模式下可選的兩種顏色；深色模式下可選的兩種顏色
// 前四個是淺色模式可選，後三個是深色模式
enum BgColorChoice {
  blueLight, greenLight, pinkLight, rainbowLight,
  navyDark, forestDark, pureBlack,
}

/// 首頁背景圖。none 表示只用底色。
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

  const BackgroundThemeState({
    required this.mode,
    required this.colorChoice,
    this.image = BgImage.none,
  });

  Color get backgroundColor {
    switch (colorChoice) {
      case BgColorChoice.blueLight:
        return const Color(0xFFE3F2FD);
      case BgColorChoice.greenLight:
        return const Color(0xFFE8F5E9);
      case BgColorChoice.pinkLight:
        // 浪漫粉：很淡的玫瑰色，卡片放上去還看得清楚
        return const Color(0xFFFDF2F6);
      case BgColorChoice.rainbowLight:
        // 彩虹：底色取最淡的那一端。
        // 全彩當背景會蓋過所有內容，所以只留一點暈染。
        return const Color(0xFFFBF4FA);
      case BgColorChoice.pureBlack:
        // 純黑簡約：不是全黑，留一點點灰。
        // 全黑在 OLED 上跟關機沒兩樣，卡片的邊界會完全消失。
        return const Color(0xFF070707);
      case BgColorChoice.navyDark:
        return const Color(0xFF16283C); // 帶藍的深色，像 logo 球球，不那麼黑
      case BgColorChoice.forestDark:
        // 夜紫：原本是深墨綠。
        // 名稱 forestDark 刻意不改——使用者存過的設定用的是這個名字，
        // 改名的話已經選了它的人，下次打開會找不到自己的選擇。
        return const Color(0xFF2C2442);
    }
  }

  final BgImage image;

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
      case 'pinkLight':
        colorChoice = BgColorChoice.pinkLight;
        break;
      case 'rainbowLight':
        colorChoice = BgColorChoice.rainbowLight;
        break;
      case 'pureBlack':
        colorChoice = BgColorChoice.pureBlack;
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

    final imgStr = prefs.getString(_imageKey);
    final img = BgImage.values.firstWhere(
      (e) => e.name == imgStr,
      orElse: () => BgImage.none,
    );

    state = BackgroundThemeState(
        mode: mode, colorChoice: colorChoice, image: img);
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
