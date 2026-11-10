import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/vietnam_time.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/driver_navigation.dart';
import '../domain/driver_earnings_repository.dart';
import 'revenue_cubit.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});
  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  @override
  void initState() {
    super.initState();
    context.read<RevenueCubit>().load();
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  @override
  Widget build(BuildContext context) => BlocBuilder<RevenueCubit, RevenueState>(
    builder: (context, state) {
      final cubit = context.read<RevenueCubit>();
      final range = state.range;
      final report = state.report;
      final now = vietnamTime(DateTime.now());
      final today = DateTime.utc(now.year, now.month, now.day);
      return Scaffold(
        appBar: const AppHeader('Báo cáo doanh thu'),
        bottomNavigationBar: const DriverNavigation(2),
        body: RefreshIndicator(
          onRefresh: cubit.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<RevenuePeriod>(
                segments: const [
                  ButtonSegment(value: RevenuePeriod.day, label: Text('Ngày')),
                  ButtonSegment(value: RevenuePeriod.week, label: Text('Tuần')),
                  ButtonSegment(
                    value: RevenuePeriod.month,
                    label: Text('Tháng'),
                  ),
                ],
                selected: {range.period},
                showSelectedIcon: false,
                onSelectionChanged: (p) =>
                    cubit.load(RevenueRange(p.single, range.anchor)),
              ),
              const SizedBox(height: 10),
              AppCard(
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => cubit.load(range.move(-1)),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        icon: const AppIcon('calendar', size: 18),
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: DateTime(
                              range.anchor.year,
                              range.anchor.month,
                              range.anchor.day,
                            ),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(
                              today.year,
                              today.month,
                              today.day,
                            ),
                          );
                          if (selected != null) {
                            cubit.load(RevenueRange(range.period, selected));
                          }
                        },
                        label: Text(
                          range.period == RevenuePeriod.month
                              ? 'Tháng ${range.start.month}/${range.start.year}'
                              : range.period == RevenuePeriod.day
                              ? _date(range.start)
                              : '${_date(range.start)} – ${_date(range.end)}',
                          style: appText(size: 12),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: range.move(1).start.isAfter(today)
                          ? null
                          : () => cubit.load(range.move(1)),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (state.busy) const LinearProgressIndicator(),
              if (state.error != null) ...[
                Notice(state.error!, peach: true),
                TextButton(
                  onPressed: () => cubit.load(),
                  child: const Text('Thử lại'),
                ),
              ],
              if (report != null) ...[
                AppCard(
                  color: AppColors.peach,
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Thực nhận',
                          style: appText(weight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        child: Text(
                          formatVnd(report.net),
                          style: appText(
                            size: 38,
                            weight: FontWeight.w800,
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                      if (report.previousNet > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${report.net >= report.previousNet ? '+' : ''}${((report.net - report.previousNet) / report.previousNet * 100).toStringAsFixed(1)}% so với ${switch (range.period) {
                            RevenuePeriod.day => 'ngày trước',
                            RevenuePeriod.week => 'tuần trước',
                            RevenuePeriod.month => 'tháng trước',
                          }}',
                          style: appText(
                            size: 12,
                            color: report.net >= report.previousNet
                                ? AppColors.green
                                : AppColors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _stat(
                        '${report.completed} chuyến',
                        'Đã hoàn thành',
                        'truck',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _stat(
                        formatVnd(report.commission),
                        'Phí nền tảng',
                        'coins',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (report.completed == 0)
                  AppCard(
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          'assets/illustrations/empty-revenue.svg',
                          height: 150,
                        ),
                        const Text('Chưa có chuyến hoàn thành trong kỳ này.'),
                      ],
                    ),
                  ),
                if (report.completed > 0) _RevenueChart(range, report.orders),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Tổng quan doanh thu', size: 15),
                      const SizedBox(height: 10),
                      _row('Tổng cước', report.gross),
                      const Divider(),
                      _row('Phí nền tảng', -report.commission),
                      const Divider(),
                      _row('Thực nhận', report.net, accent: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionTitle('Chuyến đã hoàn thành', size: 15),
                const SizedBox(height: 8),
                for (final order in report.orders.take(state.visibleOrders))
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/trip-earnings',
                      arguments: order.id,
                    ),
                    child: Row(
                      children: [
                        const AppIcon(
                          'truck',
                          size: 22,
                          color: AppColors.orange,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('#${order.code}', style: appText(size: 12)),
                              Text(
                                vietnamStamp(order.completedAt),
                                style: appText(
                                  size: 10,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatVnd(order.net),
                          style: appText(size: 13, weight: FontWeight.w700),
                        ),
                        const AppIcon('chevron-right', size: 18),
                      ],
                    ),
                  ),
                if (report.orders.length > state.visibleOrders)
                  TextButton(
                    onPressed: cubit.more,
                    child: const Text('Xem thêm chuyến'),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
  Widget _stat(String value, String label, String icon) => AppCard(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        AppIcon(icon, color: AppColors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                child: Text(
                  value,
                  style: appText(size: 15, weight: FontWeight.w700),
                ),
              ),
              Text(label, style: appText(size: 10, color: AppColors.secondary)),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _row(String label, int value, {bool accent = false}) => Row(
    children: [
      Expanded(child: Text(label, style: appText(size: 13))),
      Text(
        formatVnd(value),
        style: appText(
          weight: FontWeight.w700,
          color: accent ? AppColors.orange : AppColors.ink,
        ),
      ),
    ],
  );
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart(this.range, this.orders);
  final RevenueRange range;
  final List<OrderEarning> orders;
  @override
  Widget build(BuildContext context) {
    final count = range.period == RevenuePeriod.day
        ? 24
        : range.period == RevenuePeriod.week
        ? 7
        : (range.end.day / 7).ceil();
    final totals = List<int>.filled(count, 0);
    for (final order in orders) {
      final vn = vietnamTime(order.completedAt);
      final bucket = range.period == RevenuePeriod.day
          ? vn.hour
          : range.period == RevenuePeriod.week
          ? vn.weekday - 1
          : (vn.day - 1) ~/ 7;
      if (bucket >= 0 && bucket < count) totals[bucket] += order.net;
    }
    final maximum = math.max(1, totals.reduce(math.max));
    final buckets = [
      for (var i = 0; i < count; i++)
        if (range.period != RevenuePeriod.day || totals[i] > 0) i,
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            range.period == RevenuePeriod.day
                ? 'Doanh thu theo giờ'
                : range.period == RevenuePeriod.week
                ? 'Doanh thu theo ngày'
                : 'Doanh thu theo tuần',
            size: 14,
          ),
          const SizedBox(height: 4),
          Text(
            'Cao nhất ${formatVnd(maximum)} · giờ Việt Nam',
            style: appText(size: 10, color: AppColors.secondary),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                height: 155,
                width: math.max(constraints.maxWidth, buckets.length * 40.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final i in buckets)
                      Expanded(
                        child: Tooltip(
                          message: formatVnd(totals[i]),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                constraints: const BoxConstraints(maxWidth: 48),
                                height: totals[i] == 0
                                    ? 2
                                    : 115 * totals[i] / maximum,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                  gradient: const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      AppColors.orange,
                                      Color(0xFFFF9D68),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                range.period == RevenuePeriod.day
                                    ? '${i}h'
                                    : range.period == RevenuePeriod.week
                                    ? [
                                        'T2',
                                        'T3',
                                        'T4',
                                        'T5',
                                        'T6',
                                        'T7',
                                        'CN',
                                      ][i]
                                    : 'T${i + 1}',
                                style: appText(
                                  size: 9,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
