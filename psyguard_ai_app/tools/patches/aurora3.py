"""極光的下緣改成鋸齒狀。

真實的極光下緣不是平滑的曲線，是一道道垂直的褶皺 --
像布簾被風吹出來的皺褶，長短不一，有的垂得低有的短。

那個鋸齒就是極光最好認的特徵。

做法：下緣每隔一段就往下伸出一個尖角，
尖角的長度用穩定的偽亂數決定（用索引當種子），
所以不會每幀都在變。

在 psyguard_ai_app 目錄下執行。
"""
import sys, os

P = 'lib/core/widgets/comet_sky.dart'
if not os.path.exists(P):
    print('x 找不到', P)
    sys.exit(1)

s = open(P).read()

start = s.find('  /// 畫極光。')
end = s.find('\n  void _paintStars(', start)
assert start > 0, '找不到極光的繪製'

new_paint = '''  /// 畫極光。
  ///
  /// 下緣是鋸齒狀的 -- 那是極光最好認的特徵。
  ///
  /// 真實的極光下緣是一道道垂直的褶皺，像布簾被風吹出來的皺褶，
  /// 長短不一。平滑的曲線看起來像色帶，鋸齒才像極光。
  ///
  /// 鋸齒的長度用索引當種子算出來，所以每一幀都一樣 --
  /// 用 Random() 的話尖角會每幀亂跳。
  void _paintAurora(Canvas canvas, Size size) {
    // 一條光幕上有幾個褶皺。太少看起來像鋸子，太多會糊成一片。
    const spikes = 22;

    for (final b in aurora) {
      final path = Path();
      final baseY = b.y * size.height;
      final th = b.thickness * size.height;

      double waveAt(double t) {
        return math.sin(t * b.waveFreq * math.pi * 2 +
                    time * b.speed + b.phase) *
                b.waveAmp +
            math.sin(t * b.waveFreq * 2.7 * math.pi * 2 +
                    time * b.speed * 0.7) *
                b.waveAmp *
                0.4;
      }

      // 上緣：平滑的曲線，散進夜空
      for (int i = 0; i <= spikes; i++) {
        final t = i / spikes;
        final x = t * size.width;
        final y = baseY + waveAt(t) * size.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      // 下緣：鋸齒，從右往左走回來
      for (int i = spikes; i >= 0; i--) {
        final t = i / spikes;
        final x = t * size.width;
        final topY = baseY + waveAt(t) * size.height;

        // 每個尖角的長度不同。用 i 當種子，
        // 同一個尖角每幀都是一樣的長度。
        final seed = (i * 2654435761) % 1000 / 1000.0;
        final seed2 = (i * 40503 + 17) % 1000 / 1000.0;

        // 長短交錯：偶數的尖角長，奇數的短。
        // 那個交錯讓鋸齒有節奏，不是一排一樣長的牙齒。
        final lenFactor = (i % 2 == 0)
            ? 0.75 + seed * 0.55
            : 0.35 + seed2 * 0.35;

        // 整條光幕的厚度也有起伏
        final envelope = 0.6 + 0.4 * math.sin(t * 2.6 + b.phase);

        path.lineTo(x, topY + th * lenFactor * envelope);
      }
      path.close();

      // 上淡下濃 -- 極光的下緣有明確的輪廓，上緣散開。
      // 那是跟聚光燈最大的差別。
      final rect = Rect.fromLTWH(0, baseY - th * 0.2, size.width, th * 1.9);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            b.color.withValues(alpha: 0.0),
            b.color.withValues(alpha: 0.09),
            b.color.withValues(alpha: 0.18),
            b.color.withValues(alpha: 0.04),
          ],
          stops: const [0.0, 0.30, 0.72, 1.0],
        ).createShader(rect)
        // 疊加讓重疊處更亮，那是真的極光交會的樣子
        ..blendMode = BlendMode.plus
        // 模糊得少一點 -- 糊太多鋸齒就不見了
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, th * 0.16);

      canvas.drawPath(path, paint);
    }
  }
'''

s = s[:start] + new_paint + s[end:]
open(P, 'w').write(s)
print('v 下緣改成鋸齒狀')
print()
print('完成')
