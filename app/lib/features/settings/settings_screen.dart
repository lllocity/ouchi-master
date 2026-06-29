import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final childrenAsync = ref.watch(childrenProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          // ── 子ども管理 ──────────────────────────────
          const _SectionHeader(title: '子ども'),
          childrenAsync.when(
            data: (children) => Column(
              children: [
                ...children.map((c) => _ChildTile(child: c)),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('子どもを追加'),
                  onTap: () => _showAddChildDialog(context, ref),
                ),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('エラー'),
          ),
          const Divider(),
          // ── お手伝い項目管理 ────────────────────────
          const _SectionHeader(title: 'お手伝い項目'),
          categoriesAsync.when(
            data: (cats) => Column(
              children: cats.map((cat) => _CategorySection(category: cat)).toList(),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('エラー'),
          ),
        ],
      ),
    );
  }

  void _showAddChildDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('子どもを追加'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '名前を入力'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final db = ref.read(databaseProvider);
              await db.into(db.children).insert(
                ChildrenCompanion.insert(
                  name: name,
                  color: '#9B59B6',
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }
}

// ── 子ども行 ──────────────────────────────────────────────
class _ChildTile extends ConsumerWidget {
  final ChildrenData child;
  const _ChildTile({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _hexToColor(child.color),
        child: Text(child.name[0],
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      title: Text(child.name),
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => _showEditDialog(context, ref),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: child.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('名前を変更'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '名前'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final db = ref.read(databaseProvider);
              await (db.update(db.children)
                    ..where((c) => c.id.equals(child.id)))
                  .write(ChildrenCompanion(name: Value(name)));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

// ── カテゴリセクション ────────────────────────────────────
class _CategorySection extends ConsumerWidget {
  final Category category;
  const _CategorySection({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<ChoreTemplate>>(
      stream: (db.select(db.choreTemplates)
            ..where((t) => t.categoryId.equals(category.id))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch(),
      builder: (context, snap) {
        final templates = snap.data ?? [];
        return ExpansionTile(
          title: Text('${category.emoji} ${category.name}'),
          children: templates
              .map((t) => _ChoreTemplateTile(template: t))
              .toList(),
        );
      },
    );
  }
}

// ── お手伝い行（ON/OFFスイッチ）─────────────────────────
class _ChoreTemplateTile extends ConsumerWidget {
  final ChoreTemplate template;
  const _ChoreTemplateTile({required this.template});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      title: Text(template.name),
      subtitle: Text(
          '${template.points > 0 ? '+' : ''}${template.points}P'),
      value: template.isActive,
      onChanged: (val) async {
        final db = ref.read(databaseProvider);
        await (db.update(db.choreTemplates)
              ..where((r) => r.id.equals(template.id)))
            .write(ChoreTemplatesCompanion(isActive: Value(val)));
      },
    );
  }
}

// ── セクションヘッダー ───────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary)),
    );
  }
}
