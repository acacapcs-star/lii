import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/background_theme_service.dart';
import '../../../core/widgets/lii_bottom_nav.dart';
import '../../../core/crystals/crystal_collection_page.dart';
import '../../../l10n/app_strings.dart';
import '../../../core/security/local_settings_service.dart';

/// 我的 — 收藏與設定
///
/// 判準：它是我產生的嗎（Pacers、格言）／調一次就不再碰嗎（匯出、設定）
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    final zh = copy.isZhTw;
    final isDark = ref.watch(backgroundThemeProvider).mode == BgMode.dark;
    final bg = ref.watch(backgroundThemeProvider).backgroundColor;

    final items = <_ProfileItem>[
      _ProfileItem(
        title: zh ? '我的 Pacers' : 'My Pacers',
        subtitle: zh ? '你存下來的話' : 'Words you saved',
        icon: Icons.bookmark_rounded,
        color: const Color(0xFF7A41C8),
        route: '/bookmark',
      ),
      _ProfileItem(
        title: zh ? '我的專屬格言' : 'My Quote Cards',
        subtitle: zh ? '自己做一張' : 'Make your own',
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFFB341C8),
        route: '/my-cards',
      ),
      _ProfileItem(
        title: zh ? '我的水晶' : 'My Crystals',
        subtitle: zh ? '呼吸換來的六顆' : 'Six, earned by breathing',
        icon: Icons.diamond_outlined,
        color: const Color(0xFF41B6C8),
        route: '',
        onTap: showCrystalCollection,
      ),
      _ProfileItem(
        title: zh ? '匯出報告' : 'Export',
        subtitle: zh ? '近七天的摘要' : 'A 7-day summary',
        icon: Icons.download_rounded,
        color: const Color(0xFFC841A3),
        route: '/export',
      ),
      _ProfileItem(
        title: zh ? '設定' : 'Settings',
        subtitle: zh ? '語言、隱私、展示模式' : 'Language, privacy, exhibition',
        icon: Icons.settings_rounded,
        color: const Color(0xFFC84169),
        route: '/settings',
      ),
    ];

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: LiiBottomNav(
        isZh: zh,
        current: LiiTab.profile,
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          zh ? '我的' : 'Profile',
          style: GoogleFonts.nunitoSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFD8DEE6) : LumiTheme.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          for (final it in items) ...[
            _ProfileCard(item: it, isDark: isDark),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _ProfileItem {
  const _ProfileItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final void Function(BuildContext)? onTap;
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.item, required this.isDark});

  final _ProfileItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(item.color);
    final onCard = hsl.withSaturation(1.0).withLightness(0.22).toColor();
    final onCardSoft = hsl.withSaturation(0.85).withLightness(0.36).toColor();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        splashColor: item.color.withValues(alpha: 0.3),
        highlightColor: item.color.withValues(alpha: 0.1),
        onTap: () => item.onTap != null ? item.onTap!(context) : context.push(item.route),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color.alphaBlend(
                    item.color.withValues(alpha: 0.14), Colors.white),
                Color.alphaBlend(
                    item.color.withValues(alpha: 0.38), Colors.white),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: item.color.withValues(alpha: 0.40), width: 4),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: GoogleFonts.nunitoSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: onCard)),
                    const SizedBox(height: 2),
                    Text(item.subtitle,
                        style: GoogleFonts.nunitoSans(
                            fontSize: 11, color: onCardSoft)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
