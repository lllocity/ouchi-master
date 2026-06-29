import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/animated_point_counter.dart';
import 'activity_log_list.dart';

class ChildPointPanel extends ConsumerStatefulWidget {
  final ChildrenData child;
  const ChildPointPanel({super.key, required this.child});

  @override
  ConsumerState<ChildPointPanel> createState() =>
      _ChildPointPanelState();
}

class _ChildPointPanelState extends ConsumerState<ChildPointPanel> {
  late final ConfettiController _confetti;
  int? _prevPoints;

  Color get _color {
    final h = widget.child.color.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  void initState() {
    super.initState();
    _confetti =
        ConfettiController(duration: const Duration(milliseconds: 1200));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pointsAsync =
        ref.watch(currentMonthPointsProvider(widget.child.id));
    final logsAsync =
        ref.watch(recentActivitiesProvider(widget.child.id));

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _color, width: 2),
          ),
          child: Column(
            children: [
              Text(widget.child.name,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              pointsAsync.when(
                data: (pts) {
                  if (_prevPoints != null &&
                      pts > _prevPoints! &&
                      mounted) {
                    _confetti.play();
                  }
                  _prevPoints = pts;
                  return AnimatedPointCounter(
                    points: pts,
                    style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        color: _color),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('エラー'),
              ),
              const Text('今月のごうけい',
                  style: TextStyle(color: Colors.grey, fontSize: 15)),
              const Divider(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('📋 さいきんのきろく',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 17)),
              ),
              const SizedBox(height: 4),
              logsAsync.when(
                data: (logs) => ActivityLogList(logs: logs),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('エラー'),
              ),
            ],
          ),
        ),
        // 紙吹雪は加点時のみ、上から降らせる
        ConfettiWidget(
          confettiController: _confetti,
          blastDirection: 3.14 / 2,
          emissionFrequency: 0.25,
          numberOfParticles: 18,
          gravity: 0.3,
          colors: const [
            Colors.pink,
            Colors.orange,
            Colors.yellow,
            Colors.green,
            Colors.blue,
            Colors.purple,
          ],
        ),
      ],
    );
  }
}
