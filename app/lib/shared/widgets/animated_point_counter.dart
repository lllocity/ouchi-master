import 'package:flutter/material.dart';

class AnimatedPointCounter extends StatefulWidget {
  final int points;
  final TextStyle? style;
  const AnimatedPointCounter(
      {super.key, required this.points, this.style});

  @override
  State<AnimatedPointCounter> createState() =>
      _AnimatedPointCounterState();
}

class _AnimatedPointCounterState extends State<AnimatedPointCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _from = 0;

  @override
  void initState() {
    super.initState();
    _from = widget.points;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(AnimatedPointCounter old) {
    super.didUpdateWidget(old);
    if (old.points != widget.points) {
      _from = old.points;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final cur =
            (_from + _anim.value * (widget.points - _from)).round();
        return Text('★ $cur P ★', style: widget.style);
      },
    );
  }
}
