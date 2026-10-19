import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD1FAE5), Color(0xFFE2E8F0), Color(0xFFF1F5F9)],
          stops: [0.0, 0.25, 1.0],
        ),
      ),
      child: child,
    );
  }
}
