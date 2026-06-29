import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import 'chore_list_screen.dart';

class ChoreEntryScreen extends ConsumerStatefulWidget {
  const ChoreEntryScreen({super.key});

  @override
  ConsumerState<ChoreEntryScreen> createState() =>
      _ChoreEntryScreenState();
}

class _ChoreEntryScreenState extends ConsumerState<ChoreEntryScreen> {
  ChildrenData? _selectedChild;

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(childrenProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('できたよモード'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('だれが？',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            childrenAsync.when(
              data: (children) => Wrap(
                spacing: 12,
                children: children.map((c) {
                  final selected = _selectedChild?.id == c.id;
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selected ? Colors.blue : null,
                      foregroundColor: selected ? Colors.white : null,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 36, vertical: 16),
                    ),
                    onPressed: () =>
                        setState(() => _selectedChild = c),
                    child: Text(c.name,
                        style: const TextStyle(fontSize: 22)),
                  );
                }).toList(),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('エラー'),
            ),
            if (_selectedChild != null) ...[
              const SizedBox(height: 32),
              const Text('なにした？',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              categoriesAsync.when(
                data: (categories) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: categories.map((cat) {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChoreListScreen(
                            child: _selectedChild!,
                            category: cat,
                          ),
                        ),
                      ),
                      child: Text('${cat.emoji} ${cat.name}',
                          style: const TextStyle(fontSize: 20)),
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
    );
  }
}
