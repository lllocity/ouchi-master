import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';

class SetupScreen extends ConsumerWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏠 ouchi-master',
                style: TextStyle(
                    fontSize: 36, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            const Text('はじめに家族を登録します',
                style: TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 16)),
              onPressed: () async {
                final db = ref.read(databaseProvider);
                await db.into(db.children).insert(
                  ChildrenCompanion.insert(
                      name: 'はる', color: '#FF6B6B'),
                );
                await db.into(db.children).insert(
                  ChildrenCompanion.insert(
                      name: 'あきら', color: '#4ECDC4'),
                );
              },
              child: const Text('はると あきらを 登録する',
                  style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
