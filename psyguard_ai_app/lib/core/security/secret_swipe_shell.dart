// ═══════════════════════════════════════════════════════════
// PsyGuard AI - 秘密頁滑動外殼 🎚️
//
// 向左滑 → 顏色跟著手指褪到 75% 飽和度 → 露出秘密那一頁
// 滑回來 → 顏色回滿
//
// 滑到底看到的是鎖畫面，解鎖之後才長出內容。
// 解鎖狀態在同一個工作階段內共用，來回滑不用重解。
//
// 用法：
//   SecretSwipeShell(
//     publicPage: const NotePage(),
//     secretPage: const NotePage(secret: true),
//   )
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'secret_diary_lock.dart';

// 💜 秘密區域的配色：淺芋頭紫
const Color kTaroSoft = Color(0xFFC8B6E2);   // 主色，奶芋
const Color kTaroDeep = Color(0xFF8B6FBF);   // 深一階，按鈕與文字
const Color kTaroBg = Color(0xFFF7F3FC);     // 背景，很淡的紫
const Color kTaroHint = Color(0xFF9E8FB8);   // 次要說明文字

class SecretSwipeShell extends StatefulWidget {
  const SecretSwipeShell({
    super.key,
    required this.publicPage,
    required this.secretPage,
    this.minSaturation = 0.75,
  });

  final Widget publicPage;
  final Widget secretPage;

  /// 滑到底時的飽和度，1.0 = 原色，0 = 全灰
  final double minSaturation;

  @override
  State<SecretSwipeShell> createState() => _SecretSwipeShellState();
}

class _SecretSwipeShellState extends State<SecretSwipeShell> {
  final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 目前滑動進度 0.0（公開）～ 1.0（秘密）
  double get _progress {
    if (!_controller.hasClients) return 0;
    if (!_controller.position.haveDimensions) return 0;
    return (_controller.page ?? 0).clamp(0.0, 1.0);
  }

  /// 飽和度矩陣。s=1 原色，s=0 全灰。
  /// 亮度權重用 Rec.709，跟人眼感受比較接近。
  static List<double> _saturationMatrix(double s) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final ir = (1 - s) * lr;
    final ig = (1 - s) * lg;
    final ib = (1 - s) * lb;
    return <double>[
      ir + s, ig, ib, 0, 0,
      ir, ig + s, ib, 0, 0,
      ir, ig, ib + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _progress;
        final saturation = 1.0 - (1.0 - widget.minSaturation) * t;

        return ColorFiltered(
          colorFilter: ColorFilter.matrix(_saturationMatrix(saturation)),
          child: Stack(
            children: [
              PageView(
                controller: _controller,
                physics: const ClampingScrollPhysics(),
                children: [widget.publicPage, widget.secretPage],
              ),
              // 右邊緣的小提示，滑過去就淡出
              if (t < 0.9)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (1 - t) * 0.35,
                      child: Center(
                        child: Container(
                          width: 4,
                          height: 54,
                          decoration: BoxDecoration(
                            color: kTaroSoft,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 共用的解鎖畫面
// ═══════════════════════════════════════════════════════════

class SecretUnlockScreen extends StatefulWidget {
  const SecretUnlockScreen({
    super.key,
    required this.lock,
    required this.onUnlocked,
    required this.isZh,
    this.showBackButton = true,
  });

  final SecretDiaryLock lock;
  final VoidCallback onUnlocked;
  final bool isZh;

  /// 用在滑動外殼裡時不需要返回鍵（滑回去就好）
  final bool showBackButton;

  @override
  State<SecretUnlockScreen> createState() => _SecretUnlockScreenState();
}

class _SecretUnlockScreenState extends State<SecretUnlockScreen> {
  final TextEditingController _pwCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _isZh => widget.isZh;

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: _isZh ? '解鎖秘密日記' : 'Unlock your secret diary',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (!ok) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      await widget.lock.unlockWithBiometricResult();
      widget.onUnlocked();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _isZh ? '生物辨識無法使用，請改用密碼' : 'Biometrics unavailable, use your password';
        });
      }
    }
  }

  Future<void> _tryPassword() async {
    final pw = _pwCtrl.text;
    if (pw.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (await widget.lock.isSetUp()) {
        await widget.lock.unlockWithPassword(pw);
      } else {
        if (pw.length < 4) {
          setState(() {
            _busy = false;
            _error = _isZh ? '密碼至少 4 個字' : 'Password needs at least 4 characters';
          });
          return;
        }
        final code = await widget.lock.setUp(password: pw);
        if (mounted) await _showRecoveryCode(code);
      }
      widget.onUnlocked();
    } on LockException {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _isZh ? '密碼不對' : 'Wrong password';
        });
      }
    }
  }

  Future<void> _tryRecoveryCode() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(_isZh ? '輸入復原碼' : 'Enter recovery code'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_isZh ? '取消' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(_isZh ? '確定' : 'OK'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.lock.unlockWithRecoveryCode(code);
      widget.onUnlocked();
    } on LockException {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _isZh ? '復原碼不對' : 'Wrong recovery code';
        });
      }
    }
  }

  Future<void> _showRecoveryCode(String code) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(_isZh ? '請抄下復原碼' : 'Write down your recovery code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isZh
                  ? '密碼忘記時，這是唯一能救回秘密日記的方法。請抄在紙上收好，這個畫面只會出現一次。'
                  : 'If you forget your password, this is the only way back in. Write it on paper and keep it safe. This screen appears only once.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: kTaroDeep,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_isZh ? '我抄好了' : 'I wrote it down'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTaroBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: kTaroDeep),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: FutureBuilder<bool>(
            future: widget.lock.isSetUp(),
            builder: (context, snap) {
              final setUp = snap.data ?? true;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔒', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  Text(
                    setUp
                        ? (_isZh ? '秘密日記' : 'Secret Diary')
                        : (_isZh ? '建立秘密日記' : 'Create your secret diary'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                      color: kTaroDeep,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    setUp
                        ? (_isZh
                            ? '解鎖後就能自由讀寫，離開會自動鎖上'
                            : 'Unlock once, then read and write freely.')
                        : (_isZh
                            ? '設一組密碼，只有你打得開'
                            : 'Set a password. Only you can open it.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: kTaroHint),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _pwCtrl,
                    obscureText: true,
                    onSubmitted: (_) => _tryPassword(),
                    decoration: InputDecoration(
                      labelText: _isZh ? '密碼' : 'Password',
                      errorText: _error,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _tryPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTaroDeep,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(setUp
                              ? (_isZh ? '解鎖' : 'Unlock')
                              : (_isZh ? '建立' : 'Create')),
                    ),
                  ),
                  if (setUp) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _tryBiometric,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kTaroDeep,
                        side: const BorderSide(color: kTaroSoft),
                      ),
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: Text(_isZh ? '用 Touch ID' : 'Use Touch ID'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _tryRecoveryCode,
                      child: Text(
                        _isZh ? '忘記密碼？用復原碼' : 'Forgot password? Use recovery code',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
