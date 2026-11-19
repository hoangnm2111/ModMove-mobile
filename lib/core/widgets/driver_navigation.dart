import 'package:flutter/material.dart';
import 'app_widgets.dart';

class DriverNavigation extends StatelessWidget {
  const DriverNavigation(this.selected, {super.key});
  final int selected;
  @override
  Widget build(BuildContext context) => AppBottomNav(
    driver: true,
    selected: selected,
    onSelect: (i) {
      if (i == selected) return;
      final route = ['/driver-home', '/trips', '/wallet', '/profile'][i];
      if (i == 0) {
        Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
      } else {
        Navigator.pushNamed(context, route);
      }
    },
  );
}
