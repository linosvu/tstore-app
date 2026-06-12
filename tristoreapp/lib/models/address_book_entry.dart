/// Địa chỉ gợi ý cấu hình trên server ([GET /admin/address-book]).
class AddressBookEntry {
  AddressBookEntry({
    required this.id,
    required this.label,
    required this.houseNumber,
    required this.wardId,
    required this.provinceId,
  });

  final String id;
  final String label;
  final String houseNumber;
  final String wardId;
  final String provinceId;

  factory AddressBookEntry.fromJson(Map<String, dynamic> json) {
    return AddressBookEntry(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      houseNumber: json['houseNumber'] as String? ?? '',
      wardId: json['wardId'] as String? ?? 'A',
      provinceId: json['provinceId'] as String? ?? 'X',
    );
  }
}
