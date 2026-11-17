import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';
import 'app_widgets.dart';

class CustomerBrand extends StatelessWidget {
  const CustomerBrand({super.key, this.trailing, this.compact = false});
  final Widget? trailing;
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      AppLogo(size: compact ? 36 : 44),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'ModMove',
          style: appText(size: compact ? 21 : 25, weight: FontWeight.w800),
        ),
      ),
      ?trailing,
    ],
  );
}

/// Decorative art only. Never used as shipment evidence, a map or a payment QR.
class DeliveryBanner extends StatelessWidget {
  const DeliveryBanner({
    super.key,
    this.title,
    this.action,
    this.onPressed,
    this.height = 156,
  });
  final String? title, action;
  final VoidCallback? onPressed;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Container(
      constraints: BoxConstraints(minHeight: height),
      decoration: const BoxDecoration(
        color: AppColors.peach,
        image: DecorationImage(
          image: AssetImage('assets/images/hero-delivery.png'),
          fit: BoxFit.cover,
          alignment: Alignment.bottomRight,
        ),
      ),
      child: title == null
          ? SizedBox(height: height, width: double.infinity)
          : Padding(
              padding: const EdgeInsets.all(18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: .56,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: appText(
                          size: 27,
                          weight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: onPressed,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            minimumSize: const Size(0, 44),
                            textStyle: appText(
                              size: 13,
                              weight: FontWeight.w700,
                            ),
                          ),
                          child: Text(action!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}

class CustomerIllustration extends StatelessWidget {
  const CustomerIllustration(
    this.name, {
    super.key,
    this.height = 150,
    this.title,
  });
  final String name;
  final double height;
  final String? title;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.peach,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        ExcludeSemantics(
          child: Image.asset(
            'assets/images/customer-$name.png',
            height: height,
            fit: BoxFit.contain,
          ),
        ),
        if (title != null) ...[
          const SizedBox(height: 10),
          Text(
            title!,
            textAlign: TextAlign.center,
            style: appText(size: 18, weight: FontWeight.w600),
          ),
        ],
      ],
    ),
  );
}

class CustomerServiceIcon extends StatelessWidget {
  const CustomerServiceIcon(this.name, {super.key, this.size = 42});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/$name.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}

class CustomerPageHeading extends StatelessWidget {
  const CustomerPageHeading(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: appText(size: 27, weight: FontWeight.w800),
              ),
            ),
            ?trailing,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: appText(color: AppColors.secondary)),
        ],
      ],
    ),
  );
}

class CustomerEmptyState extends StatelessWidget {
  const CustomerEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = 'box',
  });
  final String title, message, icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            color: AppColors.peach,
            shape: BoxShape.circle,
          ),
          child: AppIcon(icon, size: 36, color: AppColors.orange),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: appText(size: 17, weight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: appText(color: AppColors.secondary, size: 13),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class CustomerRouteSummary extends StatelessWidget {
  const CustomerRouteSummary({
    super.key,
    required this.pickup,
    required this.dropoff,
  });
  final String pickup, dropoff;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _point('pickup', pickup, AppColors.green),
      const Padding(
        padding: EdgeInsets.only(left: 9),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: 10,
            child: VerticalDivider(width: 1, color: AppColors.line),
          ),
        ),
      ),
      _point('map-pin', dropoff, AppColors.orange),
    ],
  );
  Widget _point(String icon, String text, Color color) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppIcon(icon, size: 20, color: color),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: appText(size: 14),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

class CustomerActionBar extends StatelessWidget {
  const CustomerActionBar({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: child,
      ),
    ),
  );
}
