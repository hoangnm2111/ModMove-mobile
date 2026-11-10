class ResultPage<T> {
  const ResultPage(this.items, this.page, this.total, this.hasNext);
  final List<T> items;
  final int page, total;
  final bool hasNext;
}
