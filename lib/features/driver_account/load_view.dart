import 'package:flutter/material.dart';
import '../../core/network/api_exception.dart';
import '../driver_trip/presentation/widgets/trip_components.dart';

String errorText(Object error) =>
    error is ApiException ? error.message : 'Chưa tải được dữ liệu. Vui lòng thử lại.';

/// Tải một lần, kéo để làm mới, lỗi có nút "Thử lại". [builder] nhận dữ liệu và hàm [reload].
class LoadView<T> extends StatefulWidget {
  const LoadView({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  @override
  State<LoadView<T>> createState() => _LoadViewState<T>();
}

class _LoadViewState<T> extends State<LoadView<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.load();
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data != null) {
      return RefreshIndicator(onRefresh: _reload, child: widget.builder(context, _data as T, _reload));
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [TripError(errorText(_error ?? ''), retry: _reload)],
    );
  }
}

/// Danh sách phân trang: tải trang 1, nút "Tải thêm" khi BE báo còn trang, kéo để làm mới.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    required this.emptyText,
    this.header,
  });
  final Future<PageResult<T>> Function(int page) fetch;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyText;
  final Widget? header;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

/// Kết quả một trang (tách khỏi model để widget không phụ thuộc DTO cụ thể).
class PageResult<T> {
  const PageResult(this.items, this.hasNext);
  final List<T> items;
  final bool hasNext;
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  final _items = <T>[];
  int _page = 0;
  bool _hasNext = false, _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _more(reset: true);
  }

  Future<void> _more({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final next = reset ? 1 : _page + 1;
      final result = await widget.fetch(next);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(result.items);
        _page = next;
        _hasNext = result.hasNext;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _more(reset: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.header != null) widget.header!,
          if (_error != null) TripError(errorText(_error!), retry: () => _more(reset: _items.isEmpty)),
          if (_items.isEmpty && !_loading && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(widget.emptyText, textAlign: TextAlign.center)),
            ),
          for (final item in _items)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: widget.itemBuilder(context, item)),
          if (_loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          if (_hasNext && !_loading)
            TextButton(onPressed: _more, child: const Text('Tải thêm')),
        ],
      ),
    );
  }
}
