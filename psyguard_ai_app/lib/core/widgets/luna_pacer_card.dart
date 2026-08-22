// ═══════════════════════════════════════════════════════════
// Luna Pacer · 語錄卡
//
// 上：lii（這顆是控制器，左右滑動轉面）
// 中：照片
// 下：句子 —— 夜空轉開多少，話就浮出來多少
// 右下：作者
//
// 逐字浮現：每個字自己有門檻，所以停在中間、話就停在中間。
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import 'luna_orb.dart';

const double _kOrb = 172;
const double _kR = 80;

class LunaPacerCard extends StatefulWidget {
  final String quote;
  final String author;
  final GlassTone tone;

  /// 顯示三顆換色按鈕（展示用；正式版可以關掉）
  final bool showToneSwitch;

  /// 一開始就拉到哪（0 = 整片夜空）
  final double? initialT;

  /// 一開始就帶的照片
  final Uint8List? initialPhoto;

  /// 拉動或換照片時回報，讓外面決定要不要存
  final void Function(double t, Uint8List? photo)? onChanged;

  const LunaPacerCard({
    super.key,
    this.quote = '光穿過你的時候，你會發現你一直都是透明的。',
    this.author = '— Luna',
    this.tone = GlassTone.ice,
    this.showToneSwitch = true,
    this.initialT,
    this.initialPhoto,
    this.onChanged,
  });

  @override
  State<LunaPacerCard> createState() => _LunaPacerCardState();
}

class _LunaPacerCardState extends State<LunaPacerCard>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late GlassTone _tone = widget.tone;

  double _time = 0;
  double _w = _kR; // 一開始整片夜空，一個字都還沒出現
  bool _hinted = false;

  Uint8List? _photo;

  @override
  void initState() {
    super.initState();
    final t0 = widget.initialT ?? 0;
    _w = _kR - 2 * _kR * t0;
    _hinted = t0 > 0.01;
    _photo = widget.initialPhoto;
    _ticker = createTicker((d) {
      setState(() => _time = d.inMicroseconds / 1e6);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// 0 = 整片夜空，1 = 整片水晶球
  double get _t => (_kR - _w) / (2 * _kR);

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      imageQuality: 88,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    setState(() => _photo = bytes);
    widget.onChanged?.call(_t, bytes);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 360,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A1B2440),
                blurRadius: 46,
                offset: Offset(0, 22),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 上：可以滑的 lii ──
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) {
                    setState(() {
                      _hinted = true;
                      _w = (_w + d.delta.dx * (_u / _kOrb))
                          .clamp(-_kR, _kR)
                          .toDouble();
                    });
                    widget.onChanged?.call(_t, _photo);
                  },
                  child: SizedBox(
                    width: _kOrb,
                    height: _kOrb,
                    child: LunaOrb(
                      time: reduce ? 0 : _time,
                      w: _w,
                      tone: _tone,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedOpacity(
                opacity: _hinted ? 0 : 1,
                duration: const Duration(milliseconds: 500),
                child: Text(
                  '← 往左拉，話會浮出來',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 2.5,
                    color: const Color(0xFF1B2440).withAlpha(60),
                  ),
                ),
              ),

              // ── 中：照片 ──
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 4 / 5,
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDEAE3),
                      borderRadius: BorderRadius.circular(16),
                      border: _photo == null
                          ? Border.all(color: const Color(0xFFD6D1C6), width: 1.5)
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    child: _photo == null
                        ? const Text('點一下放照片',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFFA7A296)))
                        : Image.memory(_photo!, fit: BoxFit.cover),
                  ),
                ),
              ),

              // ── 下：逐字浮現的句子 ──
              const SizedBox(height: 20),
              _RevealText(text: widget.quote, progress: _t),

              // ── 右下：作者 ──
              const SizedBox(height: 12),
              Opacity(
                opacity: ((_t - 0.88) / 0.12).clamp(0.0, 1.0),
                child: Text(
                  widget.author,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF6B7590),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (widget.showToneSwitch) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: GlassTone.values.map((t) {
              final on = t == _tone;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: OutlinedButton(
                  onPressed: () => setState(() => _tone = t),
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    side: BorderSide(
                      color: on
                          ? const Color(0xFF1B2440)
                          : const Color(0xFFE0DCD3),
                    ),
                  ),
                  child: Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: on
                          ? const Color(0xFF1B2440)
                          : const Color(0xFF8C8A82),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

const double _u = 160; // orb 的座標系邊長，換算拖曳距離用

/// 逐字浮現。每個字自己有門檻，所以「拉到哪、話就到哪」，
/// 而不是整段一起淡入。
class _RevealText extends StatelessWidget {
  final String text;
  final double progress;

  const _RevealText({required this.text, required this.progress});

  @override
  Widget build(BuildContext context) {
    final chars = text.characters.toList();
    final head = progress * (chars.length + 4) - 2;

    return SizedBox(
      width: double.infinity,
      child: Wrap(
        runSpacing: 6,
        children: List.generate(chars.length, (i) {
          final o = (head - i).clamp(0.0, 1.0);
          return Opacity(
            opacity: o,
            child: Transform.translate(
              offset: Offset(0, (1 - o) * 8),
              child: Text(
                chars[i],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  letterSpacing: .02,
                  color: Color(0xFF1B2440),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
