import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/security/local_settings_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_icon.dart';
import '../../../l10n/app_strings.dart';

class ConsentPage extends ConsumerStatefulWidget {
  const ConsentPage({super.key});

  static const consentVersion = 1;

  @override
  ConsumerState<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends ConsumerState<ConsentPage> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(ref.watch(appLanguageControllerProvider));

    return Scaffold(
      backgroundColor: LumiTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          strings.consentTitle,
          style: GoogleFonts.nunitoSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: LumiTheme.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 36,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppBrandIcon(
                        size: 84,
                        radius: 26,
                        padding: 7,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: LumiTheme.softCard,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: LumiTheme.textPrimary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  strings.disclaimerTitle,
                                  style: GoogleFonts.nunitoSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: LumiTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              strings.disclaimerBody,
                              style: GoogleFonts.nunitoSans(
                                fontSize: 14,
                                height: 1.6,
                                color: LumiTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              strings.consentPrivacyBody,
                              style: GoogleFonts.nunitoSans(
                                fontSize: 14,
                                height: 1.6,
                                color: LumiTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF0F0F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _accepted,
                              activeColor: LumiTheme.primary,
                              onChanged: (value) {
                                setState(() => _accepted = value ?? false);
                              },
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  strings.consentCheckbox,
                                  style: GoogleFonts.nunitoSans(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: LumiTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: !_accepted
                              ? null
                              : () async {
                                  final service = ref.read(
                                    localSettingsServiceProvider,
                                  );
                                  await service.setConsentAccepted(
                                    version: ConsentPage.consentVersion,
                                  );
                                  ref.invalidate(consentAcceptedProvider);
                                  if (context.mounted) {
                                    context.go('/home');
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LumiTheme.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: LumiTheme.primary
                                .withValues(alpha: 0.35),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: GoogleFonts.nunitoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: Text(strings.consentAgree),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => context.go('/safety'),
                        child: Text(
                          strings.needImmediateHelp,
                          style: GoogleFonts.nunitoSans(
                            color: LumiTheme.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
