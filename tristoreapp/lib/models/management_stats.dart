import 'management_entity.dart';

class ManagementStatsResponse {
  const ManagementStatsResponse({
    required this.entity,
    required this.byStatus,
    required this.total,
  });

  final ManagementEntity entity;
  final Map<String, int> byStatus;
  final int total;

  factory ManagementStatsResponse.fromJson(Map<String, dynamic> json) {
    final entity = ManagementEntity.fromApi(json['entity'] as String?) ??
        ManagementEntity.saleOrders;
    final raw = json['byStatus'];
    final byStatus = <String, int>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        byStatus['$k'] = (v as num?)?.toInt() ?? 0;
      });
    }
    return ManagementStatsResponse(
      entity: entity,
      byStatus: byStatus,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
