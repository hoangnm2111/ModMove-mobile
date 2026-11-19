import 'package:flutter/material.dart';

/// The approved delivery-truck/M artwork, shared by authentication screens.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 80});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .22),
    child: Image.asset(
      'assets/images/modmove-app-icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'ModMove',
    ),
  );
}
