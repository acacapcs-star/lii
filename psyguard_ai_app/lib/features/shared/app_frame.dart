import 'package:flutter/material.dart';

import '../../core/widgets/comet_sky.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/security/local_settings_service.dart';
import '../../l10n/app_strings.dart';

class AppFrame extends ConsumerStatefulWidget {
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
  ConsumerState<AppFrame> createState() => _AppFrameState();
}

class _AppFrameState extends ConsumerState<AppFrame> {
  String? _userName;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadName() async {
    final name = await ref.read(localSettingsServiceProvider).getUserName();
    if (mounted) {
      setState(() => _userName = name);
      if (name != null) _nameCtrl.text = name;
    }
  }

  Future<void> _saveName(String val) async {
    final name = val.trim();
    if (name.isEmpty) return;
    await ref.read(localSettingsServiceProvider).setUserName(name);
    if (mounted) setState(() => _userName = name);
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: widget.actions),
      drawer: Drawer(
        child: ListView(
          children: [
            SizedBox(
              height: 140,
              child: ClipRect(
                child: CometSky(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset('assets/images/lii_ball.png', width: 40, height: 40),
                          const SizedBox(width: 10),
                          Flexible(
                            child: TextField(
                              controller: _nameCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: copy.isZhTw ? 'lii 要怎麼稱呼你？' : 'your name',
                                hintStyle: const TextStyle(color: Colors.white54, fontSize: 16),
                                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              ),
                              onSubmitted: _saveName,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ..._menuItems(context, copy),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: widget.child),
      ),
    );
  }

  List<Widget> _menuItems(BuildContext context, AppStrings copy) {
    final zh = copy.isZhTw;
    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Text(t,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: Colors.grey.shade500)),
        );
    Widget tile(String route, String label, IconData icon) => ListTile(
          dense: true,
          leading: Icon(icon, size: 22),
          selected: route == widget.activeRoute,
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
      tile('/chat', copy.navChat, Icons.forum_outlined),
      tile('/thought-coach', zh ? '思考教練' : 'Thought Coach', Icons.psychology_outlined),
      tile('/distortion-quiz', zh ? '思考陷阱測驗' : 'Thinking Trap Quiz', Icons.quiz_outlined),
      tile('/tools', copy.navTools, Icons.handyman_outlined),
      header(zh ? '安靜的地方' : 'Quiet'),
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
