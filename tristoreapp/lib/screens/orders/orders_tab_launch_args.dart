/// One-shot args when opening the Orders tab from management hub.
class OrdersTabLaunchArgs {
  const OrdersTabLaunchArgs({
    this.status,
    this.useListAll = true,
  });

  final String? status;
  final bool useListAll;
}
