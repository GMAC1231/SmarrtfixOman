import 'package:flutter/material.dart';

class FadeInUp extends StatefulWidget {
  final Widget child;

  const FadeInUp({super.key, required this.child});

  @override
  State<FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<FadeInUp>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> opacity;
  late Animation<Offset> offset;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    opacity = Tween(begin: 0.0, end: 1.0).animate(controller);
    offset = Tween(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(controller);

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(
        position: offset,
        child: widget.child,
      ),
    );
  }
}