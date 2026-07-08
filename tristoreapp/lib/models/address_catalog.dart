class AddressCatalogWard {
  const AddressCatalogWard({
    required this.id,
    required this.code,
    required this.name,
    required this.sortOrder,
  });

  final String id;
  final String code;
  final String name;
  final int sortOrder;

  factory AddressCatalogWard.fromJson(Map<String, dynamic> json) {
    return AddressCatalogWard(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class AddressCatalogProvince {
  const AddressCatalogProvince({
    required this.id,
    required this.code,
    required this.name,
    required this.sortOrder,
    required this.wards,
  });

  final String id;
  final String code;
  final String name;
  final int sortOrder;
  final List<AddressCatalogWard> wards;

  factory AddressCatalogProvince.fromJson(Map<String, dynamic> json) {
    final rawWards = json['wards'];
    return AddressCatalogProvince(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      wards: rawWards is List
          ? rawWards
              .map(
                (e) => AddressCatalogWard.fromJson(e as Map<String, dynamic>),
              )
              .toList()
          : const [],
    );
  }
}

class AddressCatalog {
  const AddressCatalog({required this.provinces});

  final List<AddressCatalogProvince> provinces;

  factory AddressCatalog.fromJson(Map<String, dynamic> json) {
    final raw = json['provinces'];
    return AddressCatalog(
      provinces: raw is List
          ? raw
              .map(
                (e) =>
                    AddressCatalogProvince.fromJson(e as Map<String, dynamic>),
              )
              .toList()
          : const [],
    );
  }

  static const emptyProvinceId = '';
  static const emptyWardId = '';

  /** @deprecated Legacy sentinel — migration 027. */
  static const fallbackProvinceId = '11111111-1111-4111-8111-111111111001';
  /** @deprecated Legacy sentinel — migration 027. */
  static const fallbackWardId = '22222222-2222-4222-8222-222222222201';

  static bool isEmptyProvinceWard(String provinceId, String wardId) {
    final p = provinceId.trim();
    final w = wardId.trim();
    if (p.isEmpty && w.isEmpty) return true;
    return p == fallbackProvinceId && w == fallbackWardId;
  }
}
