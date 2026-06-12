/// One-shot args khi mở tab Giao hàng từ dashboard.
class FulfillmentTabLaunchArgs {
  const FulfillmentTabLaunchArgs({
    this.outcome,
    this.expectedDelivery,
    this.scope,
  });

  /// null | open | completed | cancelled
  final String? outcome;

  /// null | due_soon | overdue
  final String? expectedDelivery;

  /// null | mine | board
  final String? scope;
}
