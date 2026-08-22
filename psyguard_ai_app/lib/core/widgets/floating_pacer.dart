// ═══════════════════════════════════════════════════════════
// 浮動 Pacer v3（依 author 分組）：
//  • 右下角浮出，同一位 author（Luna／媽媽／老師…）的暖話歸成一組
//  • 點作者名 → 展開該組，組內 tag 照時間「舊 → 新」排
//  • 點 tag → 展開看完整暖話；「×」刪除
// 用法：FloatingPacer.show(context, text: '你今天很棒', author: 'Luna');
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

class FloatingPacer {
  static final _PacerController _controller = _PacerController();
  static OverlayEntry? _entry;

  static void show(BuildContext context,
      {required String text, String? author, bool save = true}) {
    _ensureOverlay(context);
    final who = (author == null || author.isEmpty) ? 'lii' : author;
    final now = DateTime.now();
    _controller.add(_PacerItem(
      text: text,
      author: who,
      createdAt: now,
    ));
  }

  static void _ensureOverlay(BuildContext context) {
    if (_entry != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(builder: (_) => _PacerHost(controller: _controller));
    overlay.insert(_entry!);
  }

  static void _maybeRemoveOverlay() {
    if (_controller.items.isEmpty) {
      _entry?.remove();
      _entry = null;
    }
  }
}

class _PacerItem {
  final String text;
  final String author;
  final DateTime createdAt;
  final int id;
  static int _seq = 0;
  _PacerItem({
    required this.text,
    required this.author,
    required this.createdAt,
  }) : id = _seq++;
}

class _PacerController extends ChangeNotifier {
  final List<_PacerItem> items = [];
  void add(_PacerItem item) {
    items.add(item);
    notifyListeners();
  }

  void remove(int id) {
    items.removeWhere((it) => it.id == id);
    notifyListeners();
  }
}

class _PacerHost extends StatefulWidget {
  final _PacerController controller;
  const _PacerHost({required this.controller});
  @override
  State<_PacerHost> createState() => _PacerHostState();
}

class _PacerHostState extends State<_PacerHost> {
  String? _openAuthor;
  int? _openCard;

  static const List<Color> _palette = [
    Color(0xFF7E8FE8),
    Color(0xFFE58AA9),
    Color(0xFF5DCAA5),
    Color(0xFF9C8CE0),
    Color(0xFFEF9F27),
    Color(0xFF378ADD),
  ];

  Color _authorColor(String a) => _palette[a.hashCode.abs() % _palette.length];

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.controller.items;
    if (items.isEmpty) return const SizedBox.shrink();

    final byAuthor = <String, List<_PacerItem>>{};
    for (final it in items) {
      (byAuthor[it.author] ??= []).add(it);
    }
    final authors = byAuthor.keys.toList();
    for (final a in authors) {
      byAuthor[a]!.sort((x, y) => x.createdAt.compareTo(y.createdAt));
    }

    final media = MediaQuery.of(context);
    final maxH = media.size.height * 0.6;

    return Stack(
      children: [
        Positioned(
          right: 14,
          bottom: 20 + media.padding.bottom,
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH, maxWidth: 210),
              child: SingleChildScrollView(
                reverse: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final a in authors) _group(a, byAuthor[a]!),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _group(String author, List<_PacerItem> list) {
    final color = _authorColor(author);
    final open = _openAuthor == author;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => setState(() {
              _openAuthor = open ? null : author;
              _openCard = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(author,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text('${list.length}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12)),
                  const SizedBox(width: 4),
                  Icon(
                      open
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 18),
                ],
              ),
            ),
          ),
          if (open)
            for (final it in list) _tagCard(it, color),
        ],
      ),
    );
  }

  Widget _tagCard(_PacerItem it, Color color) {
    final open = _openCard == it.id;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: GestureDetector(
        onTap: () => setState(() => _openCard = open ? null : it.id),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: open ? 10 : 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(8),
          ),
          child: open
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_fmt(it.createdAt),
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            widget.controller.remove(it.id);
                            FloatingPacer._maybeRemoveOverlay();
                            if (mounted) setState(() {});
                          },
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white70, size: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(it.text,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.5,
                            fontWeight: FontWeight.w600)),
                  ],
                )
              : Row(
                  children: [
                    Text(_fmt(it.createdAt),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(it.text,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
