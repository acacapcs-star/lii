import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/security/local_settings_service.dart';
import '../../l10n/app_strings.dart';

class AppFrame extends ConsumerWidget {
  const AppFrame({
    super.key,
    required this.title,
    required this.child,
    required this.activeRoute,
    this.actions,
  });

  final String title;
  final Widget child;
  final String activeRoute;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Luna',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ..._menuItems(context, copy),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }

  List<Widget> _menuItems(BuildContext context, AppStrings copy) {
    // 分類選單
    final zh = copy.isZhTw;
    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Text(t,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.grey.shade500)),
        );
    Widget tile(String route, String label, IconData icon) => ListTile(
          dense: true,
          leading: Icon(icon, size: 22),
          selected: route == activeRoute,
          title: Text(label),
          onTap: () {
            Navigator.of(context).pop();
            context.go(route);
          },
        );
    return [
      tile('/home', copy.navHome, Icons.home_rounded),
      header(zh ? '每日紀錄' : 'Daily'),
      tile('/checkin', copy.navCheckin, Icons.check_circle_outline),
      tile('/sleep', copy.navSleep, Icons.nightlight_round),
      tile('/trends', copy.navTrends, Icons.show_chart_rounded),
      tile('/calendar-overview', zh ? '月曆總覽' : 'Calendar', Icons.calendar_month_rounded),
      header(zh ? '練習工具' : 'Practice'),
      tile('/chat', copy.navChat, Icons.chat_bubble_outline_rounded),
      tile('/thought-coach', zh ? '思考教練' : 'Thought Coach', Icons.psychology_outlined),
      tile('/distortion-quiz', zh ? '思考陷阱測驗' : 'Thinking Trap Quiz', Icons.quiz_outlined),
      tile('/tools', copy.navTools, Icons.handyman_outlined),
      header(zh ? '陪伴' : 'Companions'),
      tile('/hope-box', zh ? '🌙 希望盒' : '🌙 Hope Box', Icons.auto_awesome_rounded),
      tile('/weekly-persona', zh ? '本週人設' : 'Weekly Persona', Icons.pets_rounded),
      header(zh ? '報告' : 'Reports'),
      tile('/ai_report', zh ? 'AI 報告' : 'AI Report', Icons.description_outlined),
      tile('/ai_history', zh ? 'AI 歷史' : 'AI History', Icons.history_rounded),
      header(zh ? '其他' : 'More'),
      tile('/safety', copy.navSafety, Icons.health_and_safety_outlined),
      tile('/voice', zh ? '語音' : 'Voice', Icons.mic_none_rounded),
      tile('/export', copy.navExport, Icons.download_outlined),
      tile('/settings', zh ? '設定' : 'Settings', Icons.settings_outlined),
    ];
  }
}
