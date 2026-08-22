import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_language.dart';
import '../../../core/security/local_settings_service.dart';

/// 關於與聲明頁 — 隨 App 語言切中/英
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zh = ref.watch(appLanguageControllerProvider) == AppLanguage.zhTw;
    const teal = Color(0xFF0ABFBC);

    Widget sectionTitle(String s) => Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Text(s,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600, color: teal)),
        );

    Widget para(String s) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(s,
              style: const TextStyle(
                  fontSize: 15, height: 1.6, color: Color(0xFF3A4A54))),
        );

    Widget bullet(String s) => Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('\u2022  ',
                style: TextStyle(
                    fontSize: 15, height: 1.6, color: teal, fontWeight: FontWeight.w600)),
            Expanded(
                child: Text(s,
                    style: const TextStyle(
                        fontSize: 15, height: 1.6, color: Color(0xFF3A4A54)))),
          ]),
        );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(zh ? '\u95dc\u65bc\u8207\u8072\u660e' : 'About & Statement'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF22343A),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Center(
            child: Column(children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.favorite_rounded, color: teal, size: 36),
              ),
              const SizedBox(height: 12),
              const Text('PsyGuard AI',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(zh ? '\u9752\u5c11\u5e74\u8eab\u5fc3\u9663\u4f34 App' : 'A companion app for teen wellbeing',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF7A8896))),
              const SizedBox(height: 2),
              const Text('v1.0.0',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9AA5B1))),
            ]),
          ),
          sectionTitle(zh ? '\ud83d\udd10 \u96b1\u79c1\u8207\u5b89\u5168' : '\ud83d\udd10 Privacy & Security'),
          para(zh
              ? '\u672c App \u7684\u4f7f\u7528\u8005\u662f\u9752\u5c11\u5e74\uff0c\u8655\u7406\u7684\u662f\u5fc3\u7406\u5065\u5eb7\u8cc7\u6599\u2014\u2014\u6700\u654f\u611f\u7684\u500b\u4eba\u8cc7\u8a0a\u4e4b\u4e00\u3002\u6211\u5011\u4ee5\u300c\u96b1\u79c1\u512a\u5148\u8a2d\u8a08\u300d\u70ba\u6838\u5fc3\u3002'
              : 'Our users are teenagers and the data is mental-health data \u2014 among the most sensitive there is. The app is built around Privacy by Design.'),
          bullet(zh
              ? '\u672c\u6a5f\u512a\u5148\uff1a\u5fc3\u60c5\u3001\u7b46\u8a18\u3001\u7761\u7720\u7d00\u9304\u9810\u8a2d\u7559\u5728\u4f60\u7684\u88dd\u7f6e\uff0c\u4e0d\u81ea\u52d5\u4e0a\u50b3\u96f2\u7aef\u3002'
              : 'Local-first: moods, notes and sleep logs stay on your device and are never auto-uploaded.'),
          bullet(zh
              ? '\u79d8\u5bc6\u65e5\u8a18\u4ee5 AES-256-GCM \u8a8d\u8b49\u52a0\u5bc6\u5132\u5b58\uff1b\u91d1\u9470\u4ee5\u300c\u4fe1\u5c01\u52a0\u5bc6\u300d\u4fdd\u8b77\uff0c\u53ef\u7528\u5bc6\u78bc\u3001Touch ID/Face ID \u6216\u5fa9\u539f\u78bc\u89e3\u958b\u3002'
              : 'The secret diary is stored with AES-256-GCM authenticated encryption; the key is protected by envelope encryption and unlocked via password, Touch ID/Face ID, or a recovery code.'),
          bullet(zh
              ? '\u5bc6\u78bc\u4ee5 PBKDF2 \u91d1\u9470\u63a8\u5c0e\u4fdd\u8b77\uff1b\u91d1\u9470\u53ea\u5728\u9700\u8981\u6642\u8f09\u5165\u8a18\u61b6\u9ad4\uff0c\u4e26\u4f9d\u8a2d\u5b9a\u81ea\u52d5\u6e05\u9664\u3002'
              : 'Passwords are protected with PBKDF2 key derivation; the key is loaded into memory only when needed and auto-wiped by policy.'),
          bullet(zh
              ? 'AI API \u91d1\u9470\u5132\u5b58\u65bc\u7cfb\u7d71\u5b89\u5168\u5340\uff08iOS Keychain / Secure Enclave\u3001Android Keystore\uff09\u3002'
              : 'AI API keys are stored in the system secure enclave (iOS Keychain / Secure Enclave, Android Keystore).'),
          para(zh
              ? '\u8aa0\u5be6\u8072\u660e\uff1a\u7db2\u9801\u7248\u7f3a\u5c11\u786c\u9ad4\u7d1a\u4fdd\u8b77\uff0c\u6700\u5f37\u7684\u4fdd\u8b77\u5728\u539f\u751f iOS / Android \u7248\u672c\uff1b\u7db2\u9801\u7248\u9069\u5408\u5c55\u793a\u8207\u8a66\u7528\u3002'
              : 'Honest note: the web build lacks hardware-backed protection; the strongest guarantees are on native iOS / Android. The web build is for demo and trial.'),
          sectionTitle(zh ? '\u26a0\ufe0f \u4f7f\u7528\u8072\u660e' : '\u26a0\ufe0f Disclaimer'),
          para(zh
              ? '\u672c App \u70ba\u8eab\u5fc3\u9663\u4f34\u8207\u81ea\u6211\u89ba\u5bdf\u5de5\u5177\uff0c\u4e0d\u80fd\u53d6\u4ee3\u5c08\u696d\u91ab\u7642\u3001\u8ae2\u5546\u6216\u5371\u6a5f\u8655\u7406\u3002\u82e5\u4f60\u6216\u8eab\u908a\u7684\u4eba\u6709\u7acb\u5373\u5371\u96aa\uff0c\u8acb\u806f\u7d61\u7576\u5730\u7dca\u6025\u670d\u52d9\u6216\u4fe1\u4efb\u7684\u5927\u4eba\u3002'
              : 'This app is a wellbeing and self-awareness tool. It does not replace professional medical care, counseling, or crisis services. If you or someone is in immediate danger, contact local emergency services or a trusted adult.'),
          para(zh
              ? 'ERS \u60c5\u7dd2\u98a8\u96aa\u5206\u6578\u70ba\u53c3\u8003\u6027\u6307\u6a19\uff0c\u975e\u81e8\u5e8a\u8a3a\u65b7\u3002'
              : 'The ERS emotional-risk score is a reference indicator, not a clinical diagnosis.'),
          sectionTitle(zh ? '\ud83d\udcdc \u6388\u6b0a\u8207\u81f4\u8b1d' : '\ud83d\udcdc License & Credits'),
          para(zh
              ? '\u672c\u4f5c\u54c1\u4f7f\u7528\u591a\u500b\u958b\u6e90\u5957\u4ef6\uff0c\u5305\u542b Flutter\u3001Riverpod\u3001go_router\u3001flutter_secure_storage\u3001encrypt\u3001pointycastle\u3001speech_to_text \u7b49\uff0c\u611f\u8b1d\u5176\u793e\u7fa4\u3002'
              : 'Built with open-source packages including Flutter, Riverpod, go_router, flutter_secure_storage, encrypt, pointycastle, and speech_to_text. Thanks to their communities.'),
          para(zh
              ? '\u5404\u5957\u4ef6\u4f9d\u5176\u539f\u59cb\u6388\u6b0a\u689d\u6b3e\u4f7f\u7528\uff08\u591a\u70ba MIT / BSD / Apache-2.0\uff09\u3002'
              : 'Each package is used under its original license (mostly MIT / BSD / Apache-2.0).'),
          const SizedBox(height: 28),
          Center(
            child: Text(
              zh
                  ? '\u9752\u5c11\u5e74\u7684\u5fc3\u7406\u8cc7\u6599\uff0c\u503c\u5f97\u6700\u9ad8\u898f\u683c\u7684\u4fdd\u8b77 \ud83d\udc99'
                  : "Teens' mental-health data deserves the highest protection \ud83d\udc99",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF7A8896), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
