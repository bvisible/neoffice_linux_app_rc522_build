import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AnimatedBackground extends StatelessWidget {
  final Widget child;
  final double speed;

  AnimatedBackground({required this.child, this.speed = 0.5});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: Lottie.asset(
                'assets/lottie/animatebg.json',
                repeat: false,
                animate: true,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
