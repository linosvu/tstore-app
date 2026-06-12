enum ManagementEntity {
  saleOrders('sale_orders'),
  preparations('preparations'),
  deliveries('deliveries'),
  tasks('tasks');

  const ManagementEntity(this.apiValue);
  final String apiValue;

  static ManagementEntity? fromApi(String? v) {
    if (v == null) return null;
    for (final e in ManagementEntity.values) {
      if (e.apiValue == v) return e;
    }
    return null;
  }
}
