import 'package:flutter/material.dart';

class DegradeFundo extends StatelessWidget {
  const DegradeFundo({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 224, 242, 234),
            Color.fromARGB(255, 178, 223, 206),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}
