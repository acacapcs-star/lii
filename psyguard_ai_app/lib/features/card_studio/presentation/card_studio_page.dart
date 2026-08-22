// 暖話卡工坊 — 底色/照片/字體/貼圖(可拖)/文字可拖任意位置，存進「我的專屬格言」
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'my_cards_store.dart';
import '../../../l10n/app_strings.dart';
import '../../../core/security/local_settings_service.dart';

class CardStudioPage extends ConsumerStatefulWidget {
  const CardStudioPage({super.key});
  @override
  ConsumerState<CardStudioPage> createState() => _CardStudioPageState();
}

class _CardStudioPageState extends ConsumerState<CardStudioPage> {
  final _quoteCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController();
  int _fontIndex = 0;
  int _bgIndex = 0;
  double _size = 22;
  Uint8List? _photoBytes;
  double _photoScale = 1.0;
  Offset _textPos = const Offset(0.08, 0.12);
  int _align = 0; // 0靠左 1置中 2靠右
  final List<Map<String, dynamic>> _stickers = [];
  int? _selected;
  bool _zh = true;

  static const List<String> _fontNames = [
    '搞笑粗體', '狂草', '漫畫', '行書', '粗黑', '圓萌', '書法', '手寫', '細體',
  ];
  static const List<String> _fontNamesEn = [
    'Meme', 'Wild', 'Comic', 'Script', 'Bold', 'Round', 'Brush', 'Hand', 'Thin',
  ];
  static const List<String> _stickerPalette = [
    '😀', '😂', '🥹', '😍', '😎', '🥳', '😭', '🤔', '😴', '🥰', '😘', '🤗', '🙃', '😇',
    '👍', '👏', '🙏', '💪', '✌️', '🫶', '👋', '🤝',
    '❤️', '💗', '💜', '💙', '💚', '🧡', '💛', '🤍',
    '⭐', '✨', '🌟', '💫', '🔥', '🌈', '💯', '❗',
    '🎉', '🎈', '🎀', '🎁', '🌸', '🌷', '🌻', '🍀',
    '🐱', '🐶', '🦦', '🐰', '🐻', '🐼', '🦄', '🐧',
    '☕', '🍰', '🍓', '🍑', '🍜', '🍙', '🌙', '☀️',
  ];
  static const List<List<Color>> _bgs = [
    [Color(0xFFFF6EC7), Color(0xFF9B5DE5)],
    [Color(0xFF00E0FF), Color(0xFFFF61D2)],
    [Color(0xFFB4FF39), Color(0xFF00D4B4)],
    [Color(0xFFFFD194), Color(0xFFFF7EB3)],
    [Color(0xFF7E8FE8), Color(0xFF9C8CE0)],
    [Color(0xFFB39DDB), Color(0xFF9575CD)],
    [Color(0xFF5DCAA5), Color(0xFF2EC4B6)],
    [Color(0xFFF5A6C0), Color(0xFFE58AA9)],
    [Color(0xFFFFB74D), Color(0xFFEF9F27)],
    [Color(0xFF1A2540), Color(0xFF0D1426)],
    [Color(0xFFFFFFFF), Color(0xFFF2F2F7)],
  ];

  bool get _darkText => _bgIndex == 10;

  @override
  void dispose() {
    _quoteCtrl.dispose();
    _authorCtrl.dispose();
    _emojiCtrl.dispose();
    super.dispose();
  }

  TextStyle _fontStyle(double size, Color color) {
    switch (_fontIndex) {
      case 0:
        return GoogleFonts.zcoolQingKeHuangYou(fontSize: size + 2, color: color, height: 1.4);
      case 1:
        return GoogleFonts.liuJianMaoCao(fontSize: size + 6, color: color, height: 1.3);
      case 2:
        return GoogleFonts.zcoolKuaiLe(fontSize: size, color: color, height: 1.5);
      case 3:
        return GoogleFonts.zhiMangXing(fontSize: size + 4, color: color, height: 1.4);
      case 4:
        return GoogleFonts.notoSansTc(fontSize: size, color: color, fontWeight: FontWeight.w600, height: 1.4);
      case 5:
        return GoogleFonts.mPlusRounded1c(fontSize: size, color: color, fontWeight: FontWeight.w600, height: 1.5);
      case 6:
        return GoogleFonts.maShanZheng(fontSize: size + 4, color: color, height: 1.4);
      case 7:
        return GoogleFonts.longCang(fontSize: size + 4, color: color, height: 1.4);
      case 8:
        return GoogleFonts.zcoolXiaoWei(fontSize: size, color: color, height: 1.5);
      default:
        return GoogleFonts.notoSansTc(fontSize: size, color: color, height: 1.5);
    }
  }

  String _today() {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year - 1911}/${two(d.month)}/${two(d.day)}';
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
          source: ImageSource.gallery, maxWidth: 1200, imageQuality: 70);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() => _photoBytes = bytes);
    } catch (_) {}
  }

  void _addSticker(String e) {
    setState(() {
      _stickers.add({'e': e, 'x': 0.42, 'y': 0.42, 's': 1.0});
      _selected = _stickers.length - 1;
    });
  }

  Future<void> _save() async {
    final quote = _quoteCtrl.text.trim();
    if (quote.isEmpty) return;
    final author = _authorCtrl.text.trim();
    await MyCardsStore.add(MyCard(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: quote,
      author: author.isEmpty ? (_zh ? '我' : 'me') : author,
      fontIndex: _fontIndex,
      bgIndex: _bgIndex,
      size: _size,
      photoB64: _photoBytes == null ? null : base64Encode(_photoBytes!),
      photoScale: _photoScale,
      textX: _textPos.dx,
      textY: _textPos.dy,
      align: _align,
      stickers: List<Map<String, dynamic>>.from(_stickers),
      createdAt: DateTime.now(),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_zh ? '已存到我的專屬格言 🎴' : 'Saved to My Quotes 🎴')),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    _zh = AppStrings.of(ref.watch(appLanguageControllerProvider)).isZhTw;
    final bool hasPhoto = _photoBytes != null;
    final textColor =
        hasPhoto ? Colors.white : (_darkText ? const Color(0xFF2C3150) : Colors.white);
    final subColor = hasPhoto
        ? Colors.white.withValues(alpha: 0.9)
        : (_darkText ? const Color(0xFF7A8296) : Colors.white.withValues(alpha: 0.85));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF2C3150),
        title: Text(_zh ? '暖話卡工坊' : 'Card Studio'),
        actions: [
          TextButton(
            onPressed: () => _save(),
            child: Text(_zh ? '存檔' : 'Save',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          Text(_zh ? '提示：可以拖曳文字和貼圖到任何位置' : 'Tip: drag text & stickers anywhere',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9AA3B5))),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(builder: (context, cons) {
              final s = cons.maxWidth;
              return ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: GestureDetector(
                  onTap: () => setState(() => _selected = null),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _bgs[_bgIndex],
                            ),
                          ),
                        ),
                      ),
                      if (hasPhoto)
                        Positioned.fill(
                          child: ClipRect(
                            child: Transform.scale(
                              scale: _photoScale,
                              child: ColorFiltered(
                                colorFilter: ColorFilter.mode(
                                    Colors.black.withValues(alpha: 0.28),
                                    BlendMode.darken),
                                child: Image.memory(
                                  _photoBytes!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // 引言 + 署名（一組，靠左/置中/靠右）
                      Positioned(
                        left: _align == 2 ? null : (_align == 1 ? 0 : 22),
                        right: _align == 0 ? null : (_align == 1 ? 0 : 22),
                        bottom: 22,
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: _align == 1 ? s : s * 0.82),
                          child: Column(
                            crossAxisAlignment: _align == 0
                                ? CrossAxisAlignment.start
                                : _align == 2
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _quoteCtrl.text.isEmpty ? (_zh ? '在下面打字…' : 'Type below…') : _quoteCtrl.text,
                                textAlign: _align == 0
                                    ? TextAlign.left
                                    : _align == 2
                                        ? TextAlign.right
                                        : TextAlign.center,
                                style: _fontStyle(_size, textColor),
                              ),
                              const SizedBox(height: 10),
                              Text('${_zh ? '作者：' : 'by '}${_authorCtrl.text.isEmpty ? (_zh ? '我' : 'me') : _authorCtrl.text}',
                                  style: TextStyle(color: subColor, fontSize: 13)),
                              Text(_today(),
                                  style: TextStyle(color: subColor, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      // 貼圖
                      for (int i = 0; i < _stickers.length; i++)
                        _buildSticker(i, s),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          if (_selected != null) _stickerControls(),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_zh ? '文字位置：' : 'Text: ',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF5A6B82))),
            OutlinedButton(
              onPressed: () => setState(() => _align = 0),
              style: OutlinedButton.styleFrom(
                backgroundColor: _align == 0 ? const Color(0xFF0ABFBC) : null,
                foregroundColor: _align == 0 ? Colors.white : const Color(0xFF0ABFBC),
                side: const BorderSide(color: Color(0xFF0ABFBC)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(_zh ? '靠左' : 'Left'),
            ),
            OutlinedButton(
              onPressed: () => setState(() => _align = 1),
              style: OutlinedButton.styleFrom(
                backgroundColor: _align == 1 ? const Color(0xFF0ABFBC) : null,
                foregroundColor: _align == 1 ? Colors.white : const Color(0xFF0ABFBC),
                side: const BorderSide(color: Color(0xFF0ABFBC)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(_zh ? '置中' : 'Center'),
            ),
            OutlinedButton(
              onPressed: () => setState(() => _align = 2),
              style: OutlinedButton.styleFrom(
                backgroundColor: _align == 2 ? const Color(0xFF0ABFBC) : null,
                foregroundColor: _align == 2 ? Colors.white : const Color(0xFF0ABFBC),
                side: const BorderSide(color: Color(0xFF0ABFBC)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(_zh ? '靠右' : 'Right'),
            ),
            ],
          ),
          const SizedBox(height: 12),
          _label(_zh ? '貼圖（點一下貼到卡片上，可拖動）' : 'Stickers (tap to add, drag)'),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _stickerPalette.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => _addSticker(_stickerPalette[i]),
                child: Container(
                  width: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E6EF)),
                  ),
                  child: Text(_stickerPalette[i],
                      style: const TextStyle(fontSize: 22)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emojiCtrl,
                  decoration: _dec(_zh ? '或打上／貼上任何 emoji 😊' : 'Type / paste any emoji 😊'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B5DE5),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final e = _emojiCtrl.text.trim();
                  if (e.isEmpty) return;
                  _addSticker(e);
                  _emojiCtrl.clear();
                },
                child: Text(_zh ? '加入' : 'Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _label(_zh ? '照片' : 'Photo'),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                label: Text(hasPhoto ? (_zh ? '換照片' : 'Change') : (_zh ? '選照片' : 'Pick photo')),
              ),
              const SizedBox(width: 10),
              if (hasPhoto)
                TextButton.icon(
                  onPressed: () => setState(() => _photoBytes = null),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(_zh ? '移除照片' : 'Remove'),
                ),
            ],
          ),
          if (hasPhoto)
            Row(
              children: [
                Text(_zh ? '照片縮放' : 'Photo zoom',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF5F6B85))),
                Expanded(
                  child: Slider(
                    value: _photoScale,
                    min: 0.5,
                    max: 2.5,
                    activeColor: const Color(0xFF9B5DE5),
                    onChanged: (v) => setState(() => _photoScale = v),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),

          _label(_zh ? '你的話' : 'Your words'),
          TextField(
            controller: _quoteCtrl,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: _dec(_zh ? '寫下想說的話…' : 'Write something…'),
          ),
          const SizedBox(height: 14),

          _label(_zh ? '作者 / 貢獻者' : 'Author'),
          TextField(
            controller: _authorCtrl,
            onChanged: (_) => setState(() {}),
            decoration: _dec(_zh ? '你的名字' : 'Your name'),
          ),
          const SizedBox(height: 16),

          _label(_zh ? '字體' : 'Font'),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _fontNames.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final sel = i == _fontIndex;
                return GestureDetector(
                  onTap: () => setState(() => _fontIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF9B5DE5) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel
                              ? const Color(0xFF9B5DE5)
                              : const Color(0xFFE2E6EF)),
                    ),
                    child: Text(_zh ? _fontNames[i] : _fontNamesEn[i],
                        style: TextStyle(
                            color: sel ? Colors.white : const Color(0xFF2C3150),
                            fontWeight: FontWeight.w600)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          _label(_zh ? '底色風格' : 'Background'),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _bgs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final sel = i == _bgIndex;
                return GestureDetector(
                  onTap: () => setState(() => _bgIndex = i),
                  child: Container(
                    width: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _bgs[i],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel
                              ? const Color(0xFF2C3150)
                              : const Color(0xFFE2E6EF),
                          width: sel ? 2.5 : 1),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          _label('${_zh ? '文字大小' : 'Text size'}  ${_size.round()}'),
          Slider(
            value: _size,
            min: 14,
            max: 34,
            activeColor: const Color(0xFF9B5DE5),
            onChanged: (v) => setState(() => _size = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSticker(int i, double s) {
    final st = _stickers[i];
    final sel = _selected == i;
    final scale = (st['s'] as num).toDouble();
    return Positioned(
      left: (st['x'] as num).toDouble() * s,
      top: (st['y'] as num).toDouble() * s,
      child: GestureDetector(
        onTap: () => setState(() => _selected = i),
        onPanUpdate: (d) => setState(() {
          st['x'] = ((st['x'] as num).toDouble() + d.delta.dx / s).clamp(0.0, 0.95);
          st['y'] = ((st['y'] as num).toDouble() + d.delta.dy / s).clamp(0.0, 0.95);
          _selected = i;
        }),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: sel
              ? BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Text(st['e'] as String,
              style: TextStyle(fontSize: 34 * scale)),
        ),
      ),
    );
  }

  Widget _stickerControls() {
    final st = _stickers[_selected!];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECFA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(st['e'] as String, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 6),
          Text(_zh ? '大小' : 'Size', style: const TextStyle(fontSize: 12, color: Color(0xFF5F6B85))),
          Expanded(
            child: Slider(
              value: (st['s'] as num).toDouble(),
              min: 0.5,
              max: 3.0,
              activeColor: const Color(0xFF9B5DE5),
              onChanged: (v) => setState(() => st['s'] = v),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF5350)),
            onPressed: () => setState(() {
              _stickers.removeAt(_selected!);
              _selected = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5F6B85))),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E6EF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E6EF)),
        ),
      );
}
