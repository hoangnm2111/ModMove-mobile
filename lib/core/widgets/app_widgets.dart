import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color = AppColors.ink,
  });
  final String name;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/$name.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.color = Colors.white,
    this.borderColor = AppColors.line,
    this.onTap,
    this.radius = 9,
    this.shadow = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color, borderColor;
  final VoidCallback? onTap;
  final double radius;
  final bool shadow;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: shadow
          ? [
              const BoxShadow(
                color: Color(0x09000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ]
          : null,
    ),
    child: Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.trailing = false,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final bool trailing, busy;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null && !busy,
    child: Material(
      color: onPressed == null ? AppColors.muted : AppColors.orange,
      borderRadius: BorderRadius.circular(9),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? null
              : const LinearGradient(
                  colors: [Color(0xFFEA4A09), Color(0xFFD94B18)],
                ),
        ),
        child: InkWell(
          onTap: busy ? null : onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    AppIcon(icon!, color: Colors.white),
                    const SizedBox(width: 14),
                  ],
                  if (busy)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: appText(
                          size: 16,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (trailing) ...[
                    const SizedBox(width: 16),
                    const AppIcon(
                      'chevron-right',
                      color: Colors.white,
                      size: 19,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader(
    this.title, {
    super.key,
    this.onBack,
    this.onHelp,
    this.actions = const [],
  });
  final List<Widget> actions;
  final String title;
  final VoidCallback? onBack, onHelp;
  @override
  Size get preferredSize => const Size.fromHeight(60);
  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 60,
    leading: IconButton(
      tooltip: 'Quay lại',
      onPressed: onBack ?? () => Navigator.maybePop(context),
      icon: const AppIcon('arrow-left'),
    ),
    title: Text(title),
    actions: [
      ...actions,
      IconButton(
        tooltip: 'Hướng dẫn',
        onPressed:
            onHelp ??
            () => showInfoSheet(
              context,
              'Hỗ trợ ModMove',
              'Xem thông tin dịch vụ, bảng giá và hướng dẫn chuẩn bị hồ sơ tài xế.',
            ),
        icon: const AppIcon('help', color: AppColors.secondary),
      ),
      const SizedBox(width: 4),
    ],
  );
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    this.driver = false,
    required this.selected,
    required this.onSelect,
  });
  final bool driver;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    final icons = driver
        ? ['home', 'orders', 'wallet', 'user']
        : ['home', 'truck', 'headphones', 'user'];
    final labels = driver
        ? ['Trang chủ', 'Đơn hàng', 'Ví', 'Tài khoản']
        : ['Trang chủ', 'Dịch vụ', 'Hỗ trợ', 'Tài khoản'];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Semantics(
                  selected: i == selected,
                  button: true,
                  label: labels[i],
                  child: InkWell(
                    onTap: () => onSelect(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(
                            i == selected && (i == 0 || i == 3)
                                ? '${icons[i]}-filled'
                                : icons[i],
                            size: 24,
                            color: i == selected
                                ? AppColors.orange
                                : AppColors.secondary,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            labels[i],
                            style: appText(
                              size: 10.5,
                              weight: i == selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: i == selected
                                  ? AppColors.orange
                                  : AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.size = 18});
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: appText(size: size, weight: FontWeight.w700, spacing: -0.6),
  );
}

class Notice extends StatelessWidget {
  const Notice(
    this.text, {
    super.key,
    this.icon = 'shield',
    this.peach = false,
    this.detail,
  });
  final String text, icon;
  final bool peach;
  final String? detail;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: peach ? AppColors.peach : AppColors.pale,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(
          icon,
          size: 20,
          color: peach ? AppColors.orange : AppColors.secondary,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: appText(
                  size: 11.5,
                  color: peach ? const Color(0xFF984018) : AppColors.secondary,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(detail!, style: appText(size: 10, color: AppColors.muted)),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class DocumentThumbnail extends StatelessWidget {
  const DocumentThumbnail(
    this.name, {
    super.key,
    this.width = 64,
    this.height = 44,
  });
  final String name;
  final double width, height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(5),
    child: SvgPicture.asset(
      'assets/documents/$name.svg',
      width: width,
      height: height,
      fit: BoxFit.cover,
    ),
  );
}

class VehicleImage extends StatelessWidget {
  const VehicleImage(this.name, {super.key, this.width, this.height = 70});
  final String name;
  final double? width;
  final double height;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/vehicle-$name.png',
    width: width,
    height: height,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

Future<void> showInfoSheet(
  BuildContext context,
  String title,
  String message,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  backgroundColor: Colors.white,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          const SizedBox(height: 12),
          Text(message, style: appText(size: 15)),
          const SizedBox(height: 24),
          PrimaryButton('Đã hiểu', onPressed: () => Navigator.pop(context)),
        ],
      ),
    ),
  ),
);
