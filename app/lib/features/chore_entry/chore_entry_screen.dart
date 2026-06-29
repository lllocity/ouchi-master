import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import 'chore_list_screen.dart';

// カテゴリごとの背景色
const _categoryColors = {
  'ごはん':   Color(0xFFFF8C69),
  'せんたく': Color(0xFF64B5F6),
  'そうじ':   Color(0xFF81C784),
  'その他':   Color(0xFFBA68C8),
  'げんてん': Color(0xFFEF9A9A),
};

class ChoreEntryScreen extends ConsumerStatefulWidget {
  const ChoreEntryScreen({super.key});

  @override
  ConsumerState<ChoreEntryScreen> createState() =>
      _ChoreEntryScreenState();
}

class _ChoreEntryScreenState extends ConsumerState<ChoreEntryScreen> {
  ChildrenData? _selectedChild;

  Color _childColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(childrenProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('できたよモード',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── だれが？ ──────────────────────────────
              const Text('だれが？',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              childrenAsync.when(
                data: (children) => Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: children.map((c) {
                    final selected = _selectedChild?.id == c.id;
                    final color = _childColor(c.color);
                    return GestureDetector(
                      onTap: () => setState(() => _selectedChild = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 160,
                        height: 80,
                        decoration: BoxDecoration(
                          color: selected ? color : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color, width: 3),
                          boxShadow: selected
                              ? [BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))]
                              : [],
                        ),
                        child: Center(
                          child: Text(c.name,
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: selected ? Colors.white : color)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('エラー'),
              ),

              // ── なにした？ ────────────────────────────
              if (_selectedChild != null) ...[
                const SizedBox(height: 40),
                const Text('なにした？',
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                categoriesAsync.when(
                  data: (categories) => Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: categories.map((cat) {
                      final color = _categoryColors[cat.name]
                          ?? const Color(0xFF90CAF9);
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChoreListScreen(
                              child: _selectedChild!,
                              category: cat,
                            ),
                          ),
                        ),
                        child: Container(
                          width: 160,
                          height: 100,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(cat.emoji,
                                  style: const TextStyle(fontSize: 32)),
                              const SizedBox(height: 6),
                              Text(cat.name,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('エラー'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
