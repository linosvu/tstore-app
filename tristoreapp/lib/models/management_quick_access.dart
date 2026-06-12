import 'management_entity.dart';
import 'management_filters.dart';

/// Shortcut lưu local: bộ lọc + entity, sắp xếp theo lần dùng gần nhất.
class ManagementQuickAccess {
  const ManagementQuickAccess({
    required this.id,
    required this.name,
    required this.entity,
    required this.filters,
    required this.lastUsedAtMs,
  });

  final String id;
  final String name;
  final ManagementEntity entity;
  final ManagementFilters filters;
  final int lastUsedAtMs;

  static const int maxSaved = 20;
  static const int maxNameLength = 40;

  ManagementQuickAccess copyWith({int? lastUsedAtMs}) {
    return ManagementQuickAccess(
      id: id,
      name: name,
      entity: entity,
      filters: filters,
      lastUsedAtMs: lastUsedAtMs ?? this.lastUsedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'entity': entity.apiValue,
        'filters': filters.toJson(),
        'lastUsedAtMs': lastUsedAtMs,
      };

  factory ManagementQuickAccess.fromJson(Map<String, dynamic> json) {
    final entity = ManagementEntity.fromApi(json['entity'] as String?);
    if (entity == null) {
      throw FormatException('entity không hợp lệ');
    }
    final filtersRaw = json['filters'];
    return ManagementQuickAccess(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      entity: entity,
      filters: filtersRaw is Map<String, dynamic>
          ? ManagementFilters.fromJson(filtersRaw)
          : ManagementFilters.empty,
      lastUsedAtMs: (json['lastUsedAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

}
