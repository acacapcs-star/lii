import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:local_auth/local_auth.dart';
import '../../../core/security/secret_diary_lock.dart';
import '../../../core/security/secret_swipe_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_language.dart';
import '../../../core/security/local_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NoteItemType { text, bullet, checkbox }

enum NotePriority {
  // 紅系 (緊急) — 淺到深
  red1, red2, red3, red4, red5,
  // 黃系 (重要) — 淺到深
  yellow1, yellow2, yellow3, yellow4, yellow5,
  // 綠系 (一般) — 淺到深
  green1, green2, green3, green4, green5,
}

Color priorityColor(NotePriority p) {
  switch (p) {
    case NotePriority.red1:    return const Color(0xFFFFCDD2);
    case NotePriority.red2:    return const Color(0xFFEF9A9A);
    case NotePriority.red3:    return const Color(0xFFEF5350);
    case NotePriority.red4:    return const Color(0xFFC62828);
    case NotePriority.red5:    return const Color(0xFF7B2B2B);
    case NotePriority.yellow1: return const Color(0xFFFFF9C4);
    case NotePriority.yellow2: return const Color(0xFFFFEE58);
    case NotePriority.yellow3: return const Color(0xFFFFCA28);
    case NotePriority.yellow4: return const Color(0xFFF57F17);
    case NotePriority.yellow5: return const Color(0xFF7B5800);
    case NotePriority.green1:  return const Color(0xFFC8E6C9);
    case NotePriority.green2:  return const Color(0xFF81C784);
    case NotePriority.green3:  return const Color(0xFF66BB6A);
    case NotePriority.green4:  return const Color(0xFF2E7D32);
    case NotePriority.green5:  return const Color(0xFF1B4B1B);
  }
}

String priorityLabel(NotePriority p, {bool isZh = true}) {
  switch (p) {
    case NotePriority.red1:    return isZh ? '🔴 緊急 1' : '🔴 Urgent 1';
    case NotePriority.red2:    return isZh ? '🔴 緊急 2' : '🔴 Urgent 2';
    case NotePriority.red3:    return isZh ? '🔴 緊急 3' : '🔴 Urgent 3';
    case NotePriority.red4:    return isZh ? '🔴 緊急 4' : '🔴 Urgent 4';
    case NotePriority.red5:    return isZh ? '🔴 緊急 5' : '🔴 Urgent 5';
    case NotePriority.yellow1: return isZh ? '🟡 重要 1' : '🟡 Important 1';
    case NotePriority.yellow2: return isZh ? '🟡 重要 2' : '🟡 Important 2';
    case NotePriority.yellow3: return isZh ? '🟡 重要 3' : '🟡 Important 3';
    case NotePriority.yellow4: return isZh ? '🟡 重要 4' : '🟡 Important 4';
    case NotePriority.yellow5: return isZh ? '🟡 重要 5' : '🟡 Important 5';
    case NotePriority.green1:  return isZh ? '🟢 一般 1' : '🟢 Normal 1';
    case NotePriority.green2:  return isZh ? '🟢 一般 2' : '🟢 Normal 2';
    case NotePriority.green3:  return isZh ? '🟢 一般 3' : '🟢 Normal 3';
    case NotePriority.green4:  return isZh ? '🟢 一般 4' : '🟢 Normal 4';
    case NotePriority.green5:  return isZh ? '🟢 一般 5' : '🟢 Normal 5';
  }
}

class NoteItem {
  String text;
  NoteItemType type;
  bool checked;
  NotePriority priority;

  NoteItem({
    required this.text,
    this.type = NoteItemType.text,
    this.checked = false,
    this.priority = NotePriority.green3,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'type': type.index,
    'checked': checked,
    'priority': priority.index,
  };

  factory NoteItem.fromJson(Map<String, dynamic> j) => NoteItem(
    text: j['text'] ?? '',
    type: NoteItemType.values[j['type'] ?? 0],
    checked: j['checked'] ?? false,
    priority: NotePriority.values[j['priority'] ?? 12],
  );
}

class NotePage extends ConsumerStatefulWidget {
  /// true = 🔒 秘密日記（要解鎖、內容加密）
  /// false = 📖 公開日記（現有行為）
  const NotePage({super.key, this.secret = false, this.initialDate});

  final bool secret;

  /// 從年度總覽點進來時，直接開在指定那天
  final DateTime? initialDate;

  @override
  ConsumerState<NotePage> createState() => _NotePageState();
}

class _NotePageState extends ConsumerState<NotePage> {
  List<NoteItem> _items = [];
  bool _isZh = true;
  late DateTime _selectedDate = widget.initialDate ?? DateTime.now();

  // 💜 秘密日記走淺芋頭紫，公開日記維持原色
  Color get _bg => widget.secret ? kTaroBg : const Color(0xFFF8FFFE);
  Color get _accent =>
      widget.secret ? kTaroDeep : const Color(0xFF2C5282);

  String get _dateKey {
    final prefix = widget.secret ? 'secret_note_' : 'note_';
    return '$prefix${_selectedDate.year}_${_selectedDate.month}_${_selectedDate.day}';
  }

  String get _dateLabel {
    //
    if (_isZh) {
      return '${_selectedDate.year} 年 ${_selectedDate.month} 月 ${_selectedDate.day} 日';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';
  }

  @override
  void initState() {
    super.initState();
    if (widget.secret) {
      // 之前解過而且還沒到上鎖時間，就不用再解一次
      _lock.cancelPendingLock();
      if (_lock.isUnlocked) {
        _unlocked = true;
        _loadNotes();
      }
    } else {
      _loadNotes();
    }
  }

  @override
  void dispose() {
    if (widget.secret) _lock.scheduleLock(); // 🔒 依設定決定何時清掉金鑰
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  // 語言改由 appLanguageControllerProvider 提供（見 build()），
  // 不再自己讀 SharedPreferences。

  // ═══════════════════════════════════════════════════
  // 🔒 秘密日記
  // ═══════════════════════════════════════════════════

  final SecretDiaryLock _lock = SecretDiaryLock.instance;
  bool _unlocked = false;
  bool _busy = false;
  String? _lockError;
  final TextEditingController _pwCtrl = TextEditingController();
  final TextEditingController _pwConfirmCtrl = TextEditingController();

  Future<void> _tryBiometric() async {
    setState(() {
      _busy = true;
      _lockError = null;
    });
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: _isZh ? '解鎖秘密日記' : 'Unlock your secret diary',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (!ok) {
        setState(() => _busy = false);
        return;
      }
      await _lock.unlockWithBiometricResult();
      await _afterUnlock();
    } catch (e) {
      setState(() {
        _busy = false;
        _lockError = _isZh ? '生物辨識無法使用，請改用密碼' : 'Biometrics unavailable, use your password';
      });
    }
  }

  Future<void> _tryPassword() async {
    final pw = _pwCtrl.text;
    if (pw.isEmpty) return;
    setState(() {
      _busy = true;
      _lockError = null;
    });
    try {
      if (await _lock.isSetUp()) {
        await _lock.unlockWithPassword(pw);
      } else {
        if (pw.length < 4) {
          setState(() {
            _busy = false;
            _lockError = _isZh ? '密碼至少 4 個字' : 'Password needs at least 4 characters';
          });
          return;
        }
        if (pw != _pwConfirmCtrl.text) {
          setState(() {
            _busy = false;
            _lockError = _isZh ? '兩次密碼不一樣' : 'Passwords do not match';
          });
          return;
        }
        final code = await _lock.setUp(password: pw);
        if (mounted) await _showRecoveryCode(code);
      }
      await _afterUnlock();
    } on LockException {
      setState(() {
        _busy = false;
        _lockError = _isZh ? '密碼不對' : 'Wrong password';
      });
    }
  }

  Future<void> _tryRecoveryCode() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(_isZh ? '輸入復原碼' : 'Enter recovery code'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'ABCD-EFGH-...',
            hintStyle: TextStyle(color: Colors.grey.shade400),
          ),
        ),
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
      _lockError = null;
    });
    try {
      await _lock.unlockWithRecoveryCode(code);
      await _afterUnlock();
    } on LockException {
      setState(() {
        _busy = false;
        _lockError = _isZh ? '復原碼不對' : 'Wrong recovery code';
      });
    }
  }

  Future<void> _afterUnlock() async {
    await _loadNotes();
    if (mounted) {
      setState(() {
        _unlocked = true;
        _busy = false;
      });
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
                  : 'If you forget your password, this is the only way back into your secret diary. Write it on paper and keep it safe. This screen appears only once.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: Color(0xFF2C5282),
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

  /// 把今天的公開筆記匯進秘密日記
  Future<void> _importFromPublic() async {
    final prefs = await SharedPreferences.getInstance();
    final publicKey =
        'note_${_selectedDate.year}_${_selectedDate.month}_${_selectedDate.day}';
    final raw = prefs.getString(publicKey);
    if (raw == null || raw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isZh ? '這天的公開日記沒有東西' : 'Nothing in the public diary for this day'),
      ));
      return;
    }

    final list = jsonDecode(raw) as List;
    final incoming = list.map((e) => NoteItem.fromJson(e)).toList();

    if (!mounted) return;
    final alsoDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(_isZh ? '匯入 ${incoming.length} 則筆記' : 'Import ${incoming.length} notes'),
        content: Text(
          _isZh ? '要順便從公開日記刪掉嗎？' : 'Also remove them from the public diary?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_isZh ? '取消' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_isZh ? '保留原本的' : 'Keep both'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_isZh ? '搬過來（刪掉原本的）' : 'Move (delete original)'),
          ),
        ],
      ),
    );
    if (alsoDelete == null) return;

    setState(() => _items = [..._items, ...incoming]);
    await _saveNotes();
    if (alsoDelete) await prefs.remove(publicKey);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_isZh ? '匯入完成 🔒' : 'Imported 🔒'),
    ));
  }

  Widget _buildLockScreen() {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF2C5282)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: FutureBuilder<bool>(
            future: _lock.isSetUp(),
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
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF2C5282),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    setUp
                        ? (_isZh ? '解鎖後就能自由讀寫，離開頁面會自動鎖上' : 'Unlock once, then read and write freely. Leaving locks it again.')
                        : (_isZh ? '設一組密碼，只有你打得開' : 'Set a password. Only you can open it.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF7A8FA6)),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _pwCtrl,
                    obscureText: true,
                    autofocus: !setUp,
                    onSubmitted: (_) => _tryPassword(),
                    decoration: InputDecoration(
                      labelText: _isZh ? '密碼' : 'Password',
                      errorText: _lockError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (!setUp) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _pwConfirmCtrl,
                      obscureText: true,
                      onSubmitted: (_) => _tryPassword(),
                      decoration: InputDecoration(
                        labelText: _isZh ? '再次輸入密碼' : 'Confirm password',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFD32F2F), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isZh
                                  ? '請記牢密碼，並抄下建立後出現的復原碼，遺失將無法復原。'
                                  : 'Remember your password and save the recovery code that appears after — lost access cannot be restored.',
                              style: const TextStyle(
                                  color: Color(0xFFD32F2F), fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _tryPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0ABFBC),
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

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dateKey);
    if (raw != null) {
      final decoded = widget.secret ? _lock.decryptContent(raw) : raw;
      final list = jsonDecode(decoded) as List;
      setState(() => _items = list.map((e) => NoteItem.fromJson(e)).toList());
    } else {
      setState(() => _items = []);
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString(
        _dateKey, widget.secret ? _lock.encryptContent(json) : json);
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadNotes();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0ABFBC),
              onPrimary: Colors.white,
              onSurface: Color(0xFF2D3748),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadNotes();
    }
  }

  Future<void> _clearAllNotes() async {
    if (_items.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isZh ? '📝 清除所有筆記？' : '📝 Clear all notes?', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        content: Text(_isZh ? '這會刪除今天所有筆記，無法復原。' : 'This will delete all notes for this day. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_isZh ? '取消' : 'Cancel', style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_isZh ? '全部清除' : 'Clear All', style: const TextStyle(color: Color(0xFFEF5350), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _items = []);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dateKey);
    }
  }

  void _showGuideDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Text('💡 ', style: TextStyle(fontSize: 20)),
            Text(_isZh ? 'PsyGuard 筆記指南' : 'Note Guide', style: GoogleFonts.playfairDisplay(
              fontWeight: FontWeight.w600, color: const Color(0xFF2C5282), fontSize: 18
            )),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GuideRow(icon: '•', text: _isZh ? '[重點] 快速記下想法和關鍵字。' : '[Bullet] Great for quick ideas and key points.'),
            _GuideRow(icon: '☑', text: _isZh ? '[待辦] 點方框標記完成。' : '[Todo] Tap the checkbox to mark done.'),
            _GuideRow(icon: '🟢', text: _isZh ? '[優先級] 點圓點循環 15 級，長按直接選。' : '[Priority] Tap dot to cycle 15 levels. Long press to pick directly.'),
            _GuideRow(icon: '↕', text: _isZh ? '[排序] 長按任一項可拖曳調整順序。' : '[Reorder] Long press any item to drag and reorder.'),
            _GuideRow(icon: '🤖', text: _isZh ? '[AI 同步] 筆記會同步給 Luna，紅色緊急任務牠會主動關心你。' : '[AI Sync] All notes sync to AI chat. Luna will check in on your urgent red tasks!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_isZh ? '我知道了' : 'Got it', style: TextStyle(color: Color(0xFF0ABFBC), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _addItem(NoteItemType type) {
    setState(() => _items.add(NoteItem(text: '', type: type)));
    _saveNotes();
  }

  void _deleteItem(int index) {
    setState(() => _items.removeAt(index));
    _saveNotes();
  }

  void _cyclePriority(int index) {
    setState(() {
      final current = _items[index].priority.index;
      _items[index].priority = NotePriority.values[(current + 1) % 15];
    });
    _saveNotes();
  }

  // 長按直接選等級
  void _showPriorityPicker(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isZh ? '選擇優先等級' : 'Choose Priority Level', style: GoogleFonts.playfairDisplay(
              fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF2C5282),
            )),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: NotePriority.values.map((p) {
                final selected = _items[index].priority == p;
                return GestureDetector(
                  onTap: () {
                    setState(() => _items[index].priority = p);
                    _saveNotes();
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: priorityColor(p).withOpacity(selected ? 1.0 : 0.2),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: priorityColor(p),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      priorityLabel(p, isZh: _isZh),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? Colors.white : priorityColor(p),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🌐 語言跟 App 其他頁面共用同一個來源，切換時這頁會自動重建
    _isZh = ref.watch(appLanguageControllerProvider) == AppLanguage.zhTw;
    if (widget.secret && !_unlocked) return _buildLockScreen();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF2C5282)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                widget.secret
                    ? (_isZh ? '🔒 秘密日記' : '🔒 Secret Diary')
                    : (_isZh ? '今日筆記' : "Today's Diary"),
                style: GoogleFonts.playfairDisplay(
              fontSize: 20, fontStyle: FontStyle.italic,
              color: _accent,
            )),
            Text(_isZh ? '即時同步 AI' : 'Syncs with AI', style: const TextStyle(fontSize: 11, color: Color(0xFF0ABFBC))),
          ],
        ),
        actions: [
          // 🔒 公開日記 -> 進秘密日記；秘密日記 -> 匯入公開筆記
          if (widget.secret)
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Color(0xFF2C5282)),
              tooltip: _isZh ? '匯入今天的公開筆記' : 'Import today from public diary',
              onPressed: _importFromPublic,
            ),
          // 🔒 按鈕入口（手機上 ReorderableListView 會吃掉左滑手勢，
          //    所以保留按鈕當作穩定入口）
          if (widget.secret)
            IconButton(
              icon: const Icon(Icons.lock_open_rounded, color: kTaroDeep),
              tooltip: _isZh ? '回到公開日記' : 'Back to public diary',
              onPressed: () => Navigator.pop(context),
            )
          else
            IconButton(
              icon: const Icon(Icons.lock_outline_rounded,
                  color: Color(0xFF8B6FBF)),
              tooltip: _isZh ? '秘密日記' : 'Secret diary',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotePage(secret: true),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF0ABFBC)),
            onPressed: _showGuideDialog,
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded, color: Color(0xFFEF5350), size: 20),
            onPressed: _clearAllNotes,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0ABFBC)),
                  onPressed: () => _changeDate(-1),
                ),
                GestureDetector(
                  onTap: _pickDate,
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 16, color: _accent),
                      const SizedBox(width: 6),
                      Text(_dateLabel, style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2D3748)
                      )),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0ABFBC)),
                  onPressed: () => _changeDate(1),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _QuickButton(label: _isZh ? '• 列點' : '• Bullet', onTap: () => _addItem(NoteItemType.bullet)),
                const SizedBox(width: 8),
                _QuickButton(label: _isZh ? '☑ 待辦' : '☑ Todo', onTap: () => _addItem(NoteItemType.checkbox)),
                const SizedBox(width: 8),
                _QuickButton(label: _isZh ? '✏ 文字' : '✏ Text', onTap: () => _addItem(NoteItemType.text)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📝', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(_isZh ? '這天還沒有筆記' : 'No notes for this day',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    onReorder: (old, newIndex) {
                      setState(() {
                        if (newIndex > old) newIndex--;
                        final item = _items.removeAt(old);
                        _items.insert(newIndex, item);
                      });
                      _saveNotes();
                    },
                    itemBuilder: (ctx, i) {
                      final item = _items[i];
                      return _NoteItemWidget(
                        key: ValueKey('${_dateKey}_$i'),
                        item: item,
                        priorityColor: priorityColor(item.priority),
                        onTextChange: (v) {
                          item.text = v;
                          _saveNotes();
                        },
                        onCheckToggle: () {
                          setState(() => item.checked = !item.checked);
                          _saveNotes();
                        },
                        onPriorityCycle: () => _cyclePriority(i),
                        onPriorityLongPress: () => _showPriorityPicker(i),
                        onDelete: () => _deleteItem(i),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  final String icon;
  final String text;
  const _GuideRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568), height: 1.4))),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0ABFBC).withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF0ABFBC).withOpacity(0.3)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF0ABFBC))),
      ),
    );
  }
}

class _NoteItemWidget extends StatefulWidget {
  final NoteItem item;
  final Color priorityColor;
  final ValueChanged<String> onTextChange;
  final VoidCallback onCheckToggle;
  final VoidCallback onPriorityCycle;
  final VoidCallback onPriorityLongPress;
  final VoidCallback onDelete;

  const _NoteItemWidget({
    super.key,
    required this.item,
    required this.priorityColor,
    required this.onTextChange,
    required this.onCheckToggle,
    required this.onPriorityCycle,
    required this.onPriorityLongPress,
    required this.onDelete,
  });

  @override
  State<_NoteItemWidget> createState() => _NoteItemWidgetState();
}

class _NoteItemWidgetState extends State<_NoteItemWidget> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.item.text);
  }

  @override
  void didUpdateWidget(_NoteItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.text != widget.item.text) {
      _ctrl.text = widget.item.text;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: widget.priorityColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          if (widget.item.type == NoteItemType.checkbox)
            GestureDetector(
              onTap: widget.onCheckToggle,
              child: Icon(
                widget.item.checked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                color: widget.item.checked ? const Color(0xFF0ABFBC) : Colors.grey.shade400,
                size: 22,
              ),
            )
          else if (widget.item.type == NoteItemType.bullet)
            Text('•', style: TextStyle(fontSize: 20, color: widget.priorityColor))
          else
            Icon(Icons.edit_note_rounded, size: 20, color: Colors.grey.shade300),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Type here...',
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                fontSize: 16,
                decoration: widget.item.checked ? TextDecoration.lineThrough : null,
                color: widget.item.checked ? Colors.grey.shade400 : const Color(0xFF2D3748),
              ),
              maxLines: null,
              onChanged: widget.onTextChange,
            ),
          ),
          GestureDetector(
            onTap: widget.onPriorityCycle,
            onLongPress: widget.onPriorityLongPress,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: widget.priorityColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onDelete,
            child: Icon(Icons.close_rounded, size: 16, color: Colors.grey.shade300),
          ),
        ],
      ),
    );
  }
}
