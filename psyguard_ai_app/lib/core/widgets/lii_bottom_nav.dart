import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum LiiTab { home, records, luna, tools, profile }

class LiiBottomNav extends StatelessWidget {
  const LiiBottomNav({
    super.key,
    required this.isZh,
    required this.current,
    this.isDark = false,
  });

  final bool isZh;
  final LiiTab current;
  final bool isDark;

  static const _deep = Color(0xFF2A2E45);
  static const _gold = Color(0xFFF6D98A);
  static const _lightBg = Color(0xFFFAF7F5);
  static const _lightLine = Color(0xFFEEE8E2);
  static const _lightActive = Color(0xFF4A4238);
  static const _lightIdle = Color(0xFFA79E94);
  static const _darkBg = Color(0xFF1A1816);
  static const _darkLine = Color(0xFF2E2B28);
  static const _darkActive = Color(0xFFE3DCD4);
  static const _darkIdle = Color(0xFF7A736B);
  static const _darkCenter = Color(0xFFEFE9E3);

  static const _routes = <LiiTab, String>{
    LiiTab.home: '/home',
    LiiTab.records: '/trends',
    LiiTab.luna: '/voice',
    LiiTab.tools: '/tools',
    LiiTab.profile: '/profile',
  };

  String _label(LiiTab tab) {
    switch (tab) {
      case LiiTab.home:
        return isZh ? '首頁' : 'Home';
      case LiiTab.records:
        return isZh ? '記錄' : 'Records';
      case LiiTab.luna:
        return 'Luna';
      case LiiTab.tools:
        return isZh ? '工具' : 'Tools';
      case LiiTab.profile:
        return isZh ? '我的' : 'Profile';
    }
  }

  void _go(BuildContext context, LiiTab tab) {
    if (tab == current) return;
    final route = _routes[tab];
    if (route != null) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? _darkBg : _lightBg;
    final line = isDark ? _darkLine : _lightLine;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: line, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _item(context, LiiTab.home, Icons.home_rounded),
              _item(context, LiiTab.records, Icons.event_note_rounded),
              _item(context, LiiTab.tools, Icons.grid_view_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, LiiTab tab, IconData icon) {
    final selected = tab == current;
    final color = selected
        ? (isDark ? _darkActive : _lightActive)
        : (isDark ? _darkIdle : _lightIdle);

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: _label(tab),
        child: InkWell(
          onTap: () => _go(context, tab),
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text(
                _label(tab),
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  color: color,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _centerItem(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: isZh ? 'Luna 語音，長按直接錄音' : 'Luna voice, long press to record',
        child: Center(
          child: InkWell(
            onTap: () => _go(context, LiiTab.luna),
            onLongPress: () => context.go('/voice', extra: {'autoStart': true}),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? _darkCenter : _deep,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic_rounded,
                size: 21,
                color: isDark ? _deep : _gold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
