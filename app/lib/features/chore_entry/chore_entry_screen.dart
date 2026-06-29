import 'package:flutter/material.dart';

class ChoreEntryScreen extends StatelessWidget {
  const ChoreEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('できたよモード')),
      body: const Center(child: Text('（準備中）',
          style: TextStyle(fontSize: 24))),
    );
  }
}
