import 'package:flutter/material.dart';

void showPointToast(
  BuildContext context, {
  required String childName,
  required String choreName,
  required int points,
}) {
  final pos = points >= 0;
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      top: 32,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(28),
          color: pos
              ? const Color(0xFF43A047)
              : const Color(0xFFE53935),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 14),
            child: Text(
              '$childName  ${pos ? '+' : ''}${points}P  $choreName${pos ? ' 🎉' : ''}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    ),
  );
  Overlay.of(context).insert(entry);
  Future.delayed(const Duration(seconds: 3), entry.remove);
}
