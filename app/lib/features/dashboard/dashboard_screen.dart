import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../chore_entry/chore_entry_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/child_point_panel.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _pressing = false;

  void _onLongPressStart(LongPressStartDetails _) {
    setState(() => _pressing = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (!_pressing || !mounted) return;
      setState(() => _pressing = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const ChoreEntryScreen(),
        ),
      );
    });
  }

  void _cancelPress() => setState(() => _pressing = false);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final childrenAsync = ref.watch(childrenProvider);

    return Scaffold(
      body: GestureDetector(
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: (_) => _cancelPress(),
        onLongPressCancel: _cancelPress,
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(now),
                Expanded(
                  child: childrenAsync.when(
                    data: (children) => Row(
                      children: children
                          .map((c) =>
                              Expanded(child: ChildPointPanel(child: c)))
                          .toList(),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) =>
                        Center(child: Text('エラー: $e')),
                  ),
                ),
              ],
            ),
            if (_pressing)
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Color(0x44000000),
                    child: Center(
                      child: Text('そのまま持ちつづけて…',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(DateTime now) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPadding + 8, 12, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFFB347)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33FF6B6B),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('🏠 おうちマスター',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                        color: Color(0x44000000),
                        offset: Offset(1, 1),
                        blurRadius: 3),
                  ])),
          const Spacer(),
          Text('${now.month}月',
              style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.history, size: 30, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                size: 30, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
