
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/security/local_settings_service.dart';
import '../features/chat/presentation/chat_page.dart';
import '../features/checkin/presentation/checkin_history_page.dart';
import '../features/checkin/presentation/checkin_page.dart';
import '../features/export/presentation/export_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/hopebox/presentation/hope_box_page.dart';
import '../features/bookmark/presentation/bookmark_page.dart';
import '../features/card_studio/presentation/card_studio_page.dart';
import '../features/card_studio/presentation/my_cards_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/safety/presentation/safety_page.dart';
import '../features/sleep/presentation/sleep_history_page.dart';
import '../features/sleep/presentation/sleep_page.dart';
import '../features/tools_library/presentation/tools_page.dart';
import '../features/trends/presentation/trends_page.dart';
import '../features/trends/presentation/ai_report_page.dart';
import '../features/trends/presentation/ai_report_history_page.dart';
import '../features/tools_library/presentation/tool_history_page.dart';
import '../features/welcome/presentation/welcome_page.dart';
import '../features/welcome/presentation/consent_page.dart';
import '../features/voice/voice_wake_page.dart';
import '../features/checkin/presentation/month_overview_page.dart';
import '../core/security/secret_swipe_shell.dart';
import '../features/cbt/presentation/cbt_page.dart';
import '../features/quiz/presentation/distortion_quiz_page.dart';
import '../features/persona/presentation/persona_page.dart';
import '../core/analytics/usage_tracker.dart';
import '../core/analytics/usage_stats_page.dart';
import '../features/api_usage/presentation/api_usage_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/about/presentation/about_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/welcome',
    redirect: (context, state) async { return null; },
    observers: [UsageObserver()],
    routes: [
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: '/consent',
        name: 'consent',
        builder: (context, state) => const ConsentPage(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const HomePage()),
      ),
      GoRoute(
        path: '/chat',
        name: 'chat',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const ChatPage()),
      ),
      GoRoute(
        path: '/thought-coach',
        name: 'thought-coach',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const CbtPage()),
      ),
      GoRoute(
        path: '/distortion-quiz',
        name: 'distortion-quiz',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const DistortionQuizPage()),
      ),
      GoRoute(
        path: '/weekly-persona',
        name: 'weekly-persona',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const WeeklyPersonaPage()),
      ),
      GoRoute(
        path: '/hope-box',
        name: 'hope-box',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const HopeBoxPage()),
      ),
      GoRoute(
        path: '/bookmark',
        name: 'bookmark',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const BookmarkPage()),
      ),
      GoRoute(
        path: '/checkin',
        name: 'checkin',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const CheckinPage()),
        routes: [
          GoRoute(
            path: 'history',
            name: 'checkin_history',
            pageBuilder: (context, state) =>
                _buildPageWithSlide(context, state, const CheckinHistoryPage()),
          ),
        ],
      ),
      GoRoute(
        path: '/sleep',
        name: 'sleep',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const SleepPage()),
        routes: [
          GoRoute(
            path: 'history',
            name: 'sleep_history',
            pageBuilder: (context, state) =>
                _buildPageWithSlide(context, state, const SleepHistoryPage()),
          ),
        ],
      ),
      GoRoute(
        path: '/trends',
        name: 'trends',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const TrendsPage()),
      ),
      GoRoute(
        path: '/ai_report',
        name: 'ai_report',
        pageBuilder: (context, state) {
          final report = state.extra as String;
          return _buildPageWithSlide(
            context,
            state,
            AiReportPage(reportContent: report),
          );
        },
      ),
      GoRoute(
        path: '/ai_history',
        name: 'ai_history',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const AiReportHistoryPage()),
      ),
      GoRoute(
        path: '/tools',
        name: 'tools',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const ToolsPage()),
      ),
      GoRoute(
        path: '/tools/history',
        name: 'tool_history',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const ToolHistoryPage()),
      ),
      GoRoute(
        path: '/safety',
        name: 'safety',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const SafetyPage()),
      ),
      GoRoute(
        path: '/export',
        name: 'export',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const ExportPage()),
      ),
      GoRoute(
        path: '/voice',
        name: 'voice',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const VoiceWakePage()),
      ),
      GoRoute(
        path: '/api-usage',
        name: 'api-usage',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const ApiUsagePage()),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const DashboardPage()),
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const AboutPage()),
      ),
      GoRoute(
        path: '/calendar-overview',
        name: 'calendar_overview',
        pageBuilder: (context, state) => _buildPageWithSlide(
          context,
          state,
          const SecretSwipeShell(
            publicPage: MonthOverviewPage(),
            secretPage: MonthOverviewPage(secret: true),
          ),
        ),
      ),
      GoRoute(
        path: '/card-studio',
        name: 'card_studio',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const CardStudioPage()),
      ),
      GoRoute(
        path: '/my-cards',
        name: 'my_cards',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const MyCardsPage()),
      ),
      GoRoute(
        path: '/usage-stats',
        name: 'usage_stats',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const UsageStatsPage()),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) =>
            _buildPageWithSlide(context, state, const SettingsPage()),
      ),
    ],
  );
});

CustomTransitionPage _buildPageWithSlide(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage(
    key: state.pageKey,
    name: state.name ?? state.uri.path,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0); // Enter from Right
      const end = Offset.zero;
      const curve = Curves.easeInOut;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
