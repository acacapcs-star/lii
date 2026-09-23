/// lii 的卡片色彩規則。
///
/// 這個檔案存在的理由：同一套推導原本在四個檔案裡重複了十二次
/// （tools_page、profile_page、trends_page、home_page）。
/// 十二份拷貝表示調整質感時要改十二個地方，而且遲早會有一處漏改，
/// 然後那張卡就跟其他十三張不是同一家人了。
///
/// ── 規則 ────────────────────────────────────────────────
///
/// **色相自由，飽和度與明度鎖死。**
///
/// 十四張卡的色相平均分布 360 度，每張間隔約 26 度。
/// 但每一張的飽和度都是 55%、明度都是 52%——
/// 所以顏色可以很多，看起來仍然是同一套。
///
/// 每張卡只手動指定一個主色，其餘六個部位全部從它推導：
///
///   主色      唯一手動指定的
///   卡片底    主色混白 6%（左上）→ 14%（右下）
///   邊框      主色 alpha 34%
///   圖示底板  主色 alpha 22%
///   標題字    同色相，S 100% · L 22%
///   副標字    同色相，S 85%  · L 36%
///   按壓漣漪  主色 alpha 30%
///
/// 標題和副標的明度是固定的，所以不論主色是哪個色相，
/// 深字配淡底的對比度都成立——不必為每張卡另外檢查可讀性。
library;

import 'package:flutter/material.dart';

/// 卡片的一整組顏色，全部從單一主色推導出來。
class CardPalette {
  const CardPalette._({
    required this.main,
    required this.gradient,
    required this.border,
    required this.iconPlate,
    required this.onCard,
    required this.onCardSoft,
    required this.splash,
  });

  /// 手動指定的那一個
  final Color main;

  /// 卡片底：白 → 微染 → 稍深，左上到右下
  final List<Color> gradient;

  final Color border;
  final Color iconPlate;

  /// 標題字：同色相但很暗
  final Color onCard;

  /// 副標字：介於標題與主色之間
  final Color onCardSoft;

  /// InkWell 的水波紋
  final Color splash;

  /// 從主色推導出整組。
  ///
  /// [depth] 控制右下角染色的強度。預設 0.14 是比較安靜的版本；
  /// 想要更飽和的卡片可以調到 0.30 左右，但那會讓十四張卡
  /// 在同一個畫面上顯得吵。
  factory CardPalette.from(Color main, {double depth = 0.14}) {
    final hsl = HSLColor.fromColor(main);
    return CardPalette._(
      main: main,
      gradient: [
        Colors.white,
        Color.alphaBlend(main.withValues(alpha: depth * 0.45), Colors.white),
        Color.alphaBlend(main.withValues(alpha: depth), Colors.white),
      ],
      border: main.withValues(alpha: 0.34),
      iconPlate: main.withValues(alpha: 0.22),
      onCard: hsl.withSaturation(1.0).withLightness(0.22).toColor(),
      onCardSoft: hsl.withSaturation(0.85).withLightness(0.36).toColor(),
      splash: main.withValues(alpha: 0.30),
    );
  }

  /// 直接給色相編號，飽和度與明度用規則的固定值。
  ///
  /// 十四張卡的色相是 [hueOf] 算出來的，所以新增一張卡時
  /// 不需要自己挑顏色——給編號就好。
  factory CardPalette.ofIndex(int index, {int total = 14, double depth = 0.14}) {
    return CardPalette.from(
      HSLColor.fromAHSL(1.0, hueOf(index, total), kCardSaturation, kCardLightness)
          .toColor(),
      depth: depth,
    );
  }

  /// 卡片的裝飾，直接丟給 Container 用。
  BoxDecoration decoration({double radius = 24, double borderWidth = 3}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradient,
        stops: const [0.0, 0.5, 1.0],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border, width: borderWidth),
    );
  }

  /// 圖示底板的裝飾
  BoxDecoration plateDecoration({double radius = 12}) {
    return BoxDecoration(
      color: iconPlate,
      borderRadius: BorderRadius.circular(radius),
    );
  }
}

/// 規則裡鎖死的兩個值
const double kCardSaturation = 0.55;
const double kCardLightness = 0.52;

/// 第 index 張卡的色相。
///
/// 平均分布 360 度：十四張的話每張間隔約 25.7 度。
double hueOf(int index, [int total = 14]) => (index * 360 / total) % 360;

/// 依規則產生一個色相的顏色。
///
/// 手動挑顏色時很容易挑到飽和度或明度不一致的，
/// 用這個就不會——只要決定「是哪個顏色」。
Color cardColorOfHue(double hue) =>
    HSLColor.fromAHSL(1.0, hue % 360, kCardSaturation, kCardLightness).toColor();

/// 把任何一個顏色拉回規則上。
///
/// 用在既有的顏色：色相保留，飽和度與明度改成規則的值。
/// 這就是當初 unify_colors.py 在做的事，只是搬進程式碼裡。
Color normalizeToRule(Color c) {
  final h = HSLColor.fromColor(c).hue;
  return cardColorOfHue(h);
}
