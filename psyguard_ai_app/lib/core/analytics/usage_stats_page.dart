// 頁面使用統計 — 研究用（顯示每頁打開次數 + 停留時間，本機資料）
import 'package:flutter/material.dart';
import 'usage_tracker.dart';

class UsageStatsPage extends StatefulWidget {
  const UsageStatsPage({super.key});
  @override
  State<UsageStatsPage> createState() => _UsageStatsPageState();
}

class _UsageStatsPageState extends State<UsageStatsPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await UsageTracker.load();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  String _fmtSecs(int s) {
    if (s < 60) return '$s 秒';
    final m = s ~/ 60;
    final r = s % 60;
    return r == 0 ? '$m 分' : '$m 分 $r 秒';
  }

  @override
  Widget build(BuildContext context) {
    final names = UsageTracker.opens.keys.toSet()
      ..addAll(UsageTracker.secs.keys);
    final list = names.toList()
      ..sort((a, b) =>
          (UsageTracker.opens[b] ?? 0).compareTo(UsageTracker.opens[a] ?? 0));
    final totalOpens =
        UsageTracker.opens.values.fold<int>(0, (p, e) => p + e);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('頁面使用統計'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF2C3150),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? const Center(
                  child: Text('還沒有資料，去點幾個頁面再回來',
                      style: TextStyle(color: Color(0xFF8A92A6))))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('總開啟次數：$totalOpens　　（本機統計，未上傳）',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF5F6B85))),
                    ),
                    for (final n in list) _row(n),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFEF5350),
        icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        label: const Text('清除紀錄', style: TextStyle(color: Colors.white)),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('清除所有使用紀錄？'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('清除',
                        style: TextStyle(color: Color(0xFFEF5350)))),
              ],
            ),
          );
          if (ok == true) {
            await UsageTracker.reset();
            _load();
          }
        },
      ),
    );
  }

  Widget _row(String name) {
    final o = UsageTracker.opens[name] ?? 0;
    final s = UsageTracker.secs[name] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECF4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF2C3150))),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('開 $o 次',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9B5DE5))),
              const SizedBox(height: 2),
              Text('共 ${_fmtSecs(s)}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF8A92A6))),
            ],
          ),
        ],
      ),
    );
  }
}
