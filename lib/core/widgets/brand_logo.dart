import 'package:flutter/material.dart';

/// Logo ModMove (assets/images/logo.png). Thay file ảnh này để đổi logo trong app.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .24),
    child: Image.asset('assets/images/logo.png', width: size, height: size, fit: BoxFit.cover, semanticLabel: 'ModMove'),
  );
}
